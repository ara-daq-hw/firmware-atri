; ATRI I2C interface.
;
; This is the PicoBlaze code for the I2C controllers.
;
; They accept commands from a packet interface (ATRI control packets)
; and from the irs_top module.
;
; ##############################################################################
; # BEGIN                                                                      #
; # I2C ROUTINE SECTION                                                        #
; # I2C controller, version 5. Handles most of the I2C functions in the ISR    #
; # based on a register which maintains the current state.                     #
; # The OpenCores I2C controller works like this:                              #
; # 1: Write address to transmit register                                      #
; # 2: Set STA and WR bit in control register                                  #
; # 3: Wait for interrupt                                                      #
; # 4: --- for a write, write data, then set WR bit. if Last transfer, set STO #
; #    --- for a read, set RD bit, if last transfer, set NACK bit and STO bit  #
; # 5: wait for interrupt                                                      #
; # 6: if last, we're done. else go to step 4 for next                         #
; ##############################################################################

i2c_idle            EQU    $00
i2c_write_address   EQU    $01
i2c_write           EQU    $02
i2c_read            EQU    $03
i2c_write_last      EQU    $04
i2c_read_last       EQU    $05

; # There is a FIFO between the I2C thread and main thread (using 256 bytes in the
; # program block RAM).
; # When a packet or request comes in, the main thread begins writing into the
; # FIFO - the command structure is:
; # byte 1: command type (0x00 = direct I2C command, 0xFF = IRS command)
; # byte 2: identifier (packet number if needed) - 0 for IRS commands
; # byte 3: number of bytes to transfer
; # byte 4: I2C address
; # remaining: bytes to transfer (if a write)
; # It then also calls i2c_isr_begin, which reads the ISR state, sees if it's
; # idle, and if it's idle, begins the I2C write. If it's not idle, it just
; # returns, because the ISR will continue emptying the FIFO.
; # If the FIFO fills, the main thread will just wait for space to become
; # available.
; # The main thread should call i2c_isr_begin after the first 4 bytes are
; # written, since after that it takes a while for any more bytes to be read
; # out.

isr_state          EQU   sF
isr_type           EQU   $38
isr_ident          EQU   $39
isr_length         EQU   $3A
isr_i2c            EQU   $3B
isr_count          EQU   $3C

i2c_sta            EQU   $80
i2c_sto            EQU   $40
i2c_rd             EQU   $20
i2c_wr             EQU   $10
i2c_ack            EQU   $08
i2c_iack           EQU   $01

i2c_ctr_en         EQU   $80
i2c_ctr_ien        EQU   $40

i2c_rxack          EQU   $80
i2c_busy           EQU   $40
i2c_tip            EQU   $02
i2c_if             EQU   $01

; ISR registers
in0                EQU   sE
in1                EQU   sD
in2                EQU   sC
in3                EQU   sB
;
; I2C constants
;
i2c_prerlo_value       EQU       24
i2c_prerhi_value       EQU       0
;
; I2C Ports
;
i2c_base               EQU       $00
i2c_prerlo             DSIO      i2c_base+$00
i2c_prerhi             DSIO      i2c_base+$01
i2c_ctr                DSIO      i2c_base+$02
i2c_txrx               DSIO      i2c_base+$03
i2c_crsr               DSIO      i2c_base+$04
;
; FIFO
;
; Ports
fifo_in                DSIO      $80
fifo_in_status         DSIO      $81
; Bits
fifo_in_empty          EQU       $01
fifo_in_full           EQU       $02

fifo_pc                DSIO      $C0
fifo_pc_status         DSIO      $C1
fifo_pc_full           EQU       $01
fifo_pc_packet         EQU       $02

i2c_init:          load      in0, i2c_prerhi_value
                   out       in0, i2c_prerhi
                   load      in0, i2c_prerlo_value
                   out       in0, i2c_prerlo
                   load      in0, i2c_ctr_en | i2c_ctr_ien
                   out       in0, i2c_ctr
                   ret
i2c_isr_begin:
                   comp  isr_state, i2c_idle                                    ; Check to see if the ISR is in idle
                   ret   NZ                                                     ; Return if it isn't
                   dint                                                         ; Just to be safe.
                   call  isr_read_header                                        ; Fill the header
                   call  isr_write_address                                      ; ... and write the address
                   eint                                                         ; enable interrupts...
                   ret                                                          ; and now we're done
isr_write_address:
                   fetch in0, isr_i2c                                           ; Fetch the I2C address
                   out   in0, i2c_txrx                                          ; output it
                   load  in0, i2c_sta | i2c_wr                                  ; set STA and WR bits
                   out   in0, i2c_crsr
                   load  isr_state, i2c_write_address                           ; update the current state
                   fetch in0, isr_i2c                                           ; fetch the current ISR...
                   ret
isr_read_header:
                   in    in0, fifo_in                                            ; Read first byte
                   store in0, isr_type
                   in    in0, fifo_in
                   store in0, isr_ident
                   in    in0, fifo_in
                   store in0, isr_length
                   in    in0, fifo_in
                   store in0, isr_i2c
                   ret
isr_complete:                                                                   ; The transaction is complete.
                   fetch in0, isr_type
                   comp  in0, i2c_type_IRS                                      ; is it an IRS type request?
                   jump  Z, isr_check_next                                      ; then we're done
                   comp  in0, i2c_type_DIRECT                                   ; is it a direct I2C request?
                   jump  Z, isr_finish_direct_i2c
                   reti enable
isr_check_next:    in   in0, fifo_in_status                                     ; input FIFO status
                   test in0, fifo_in_empty                                      ; is it empty?
                   jump NZ, isr_check_next_cp0                                  ; if it's not, continue...
                   load isr_state, i2c_idle                                     ; else return to idle state...
                   reti enable                                                  ; and return, enabling interrupts
isr_check_next_cp0:
                   call isr_read_header                                         ; read the next header...
                   call isr_write_address                                       ; write the next I2C address...
                   reti enable                                                  ; and return, enabling interrupts
isr_finish_direct_i2c:
                   comp isr_state, i2c_write_last
                   jump Z, isr_finish_direct_i2c_write
isr_finish_direct_i2c_read:
                   in   in0, i2c_txrx
                   call output_fifo_pc
                   in   in0, i2c_crsr
                   test in0, i2c_rxack
                   call NZ, isr_count_incr
                   fetch in0, isr_count
                   call output_fifo_pc
                   call output_pc_packet
                   jump isr_check_next
isr_finish_direct_i2c_write:
                   call isr_count_incr
                   fetch in0, isr_count
                   call output_fifo_pc
                   call output_pc_packet
                   jump isr_check_next
isr_switch:
                   comp  isr_state, i2c_write_address
                   jump  Z, i2c_write_address_ack
                   comp  isr_state, i2c_read_last
                   jump  Z, isr_complete
                   comp  isr_state, i2c_write_last
                   jump  Z, isr_complete
                   comp  isr_state, i2c_write
                   jump  Z, i2c_write_ack
                   comp  isr_state, i2c_read
                   jump  Z, i2c_read_ack
                   reti  enable                                                 ; only other thing is a spurious interrupt
i2c_write_address_ack:
                   in    in0, i2c_crsr
                   test  in0, i2c_rxack                                         ; was there an ack?

output_fifo_pc:
                   in    in1, pc_fifo_status
                   test  in1, pc_fifo_full
                   jump  NZ, output_fifo_pc
                   out   in0, pc_fifo
                   ret
output_pc_packet:
                   load  in0, pc_packet
                   out   in0, pc_fifo_status
                   ret
isr:               jump  isr_switch
