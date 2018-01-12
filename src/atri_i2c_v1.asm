
; ATRI I2C interface
;
; Assembly for the I2C picoblaze interface for ATRI. First attempt.
;
; "Present Devices" byte bitmask values
tmp102_present         EQU              $80
adm1178_present        EQU              $40
eeprom_present         EQU              $20
ad5667_present         EQU              $10
gpio_present           EQU              $08
tmp102_mask            EQU              $7F
adm1178_mask           EQU              $BF
eeprom_mask            EQU              $DF
ad5667_mask            EQU              $EF
gpio_mask              EQU              $F7
;


timer                  DSIO      $08                                            ; timer port: bit 0 = ADM1178, bit 1 = EEPROM
lram_page              DSIO      $10
fifo_status            DSIO      $11
db_status              DSIN      $20
irs_status             DSIN      $21
debug                  DSOUT     $23                                            ; none of the sel outputs are triggered by 0x23: it's used to output data to ChipScope
; LRAM is based at 0x40 (plus the page offset)
lram                   DSRAM     $40
fifo                   DSRAM     $80
;
;
; ##############################################################################
; # LRAM MEMORY MAP
; ##############################################################################
; Scratchpad RAM
tmp_devices            EQU              $00                                     ; Current devices present, most recent
tmp_temperature        EQU              $01                                     ; TMP102 temperature low byte, most recent reading
tmp_temperature_h      EQU              $02                                     ; TMP102 temperature high byte, most recent reading
tmp_voltage            EQU              $03                                     ; ADM1178 voltage low byte, most recent reading
tmp_voltage_h          EQU              $04                                     ; ADM1178 voltage high byte, most recent reading
tmp_current            EQU              $05                                     ; ADM1178 current low byte, most recent reading
tmp_current_h          EQU              $06                                     ; ADM1178 current high byte, most recent reading
tmp_status             EQU              $07                                     ; ADM1178 status, most recent read
cur_packet             EQU              $08                                     ; packet number
cur_length             EQU              $09                                     ; length
cur_type               EQU              $0A                                     ; type
cur_address            EQU              $0B                                     ; destination address

dda_type	       EQU		$0C ; DDA type, if 0, it's revB or revC, if 1, it's revD.
;
;
; Stack pointer
stack_pointer  	   	   EQU		 sF		   	   	   	   	   	; sF is the stack pointer
tmp_register           EQU       sE                         ; sE is the temporary register. It is always available, and should
                                                            ; be assumed to always be changed after every function call
cnt_register           EQU       sC                         ; counter
;
;
start:				   LOAD		 stack_pointer, $38                         	; 8-entry stack
                       call      i2c_init
                       EINT                                                     ; start interrupts
                       call      vccaux_init                                    ; initialize VCCAUX on DDA_EVAL
start_wait:            
; ##############################################################################
; # MAIN LOOP                                                                  #
; ##############################################################################
; # Do                                                                         #
; # 1: check FIFO                                                              #
; # 2: check IRS                                                               #
; #11: begin again                                                             #
; ##############################################################################
loop:                  call      poll_fifo
                       call      poll_irs
                       jump      loop
poll_irs:              in        s0, irs_status
                       call      push_operand
                       test      s0, $04
                       call      NZ, irs_init
                       call      pop_operand
                       call      push_operand
                       test      s0, $02
                       call      NZ, gpio_tstclr
                       call      pop_operand
                       test      s0, $01
                       call      NZ, gpio_tstst
                       ret
poll_fifo:             in        s0, fifo_status
                       test      s0, $01
                       ret       NZ                                             ; we have a packet
                       in        s0, fifo                                       ; read packet number
                       store     s0, cur_packet                                 ; store packet number
                       in        s0, fifo                                       ; read packet length
                       store     s0, cur_length                                 ; store length
                       in        s0, fifo                                       ; read type
                       store     s0, cur_type                                   ; store type
                       call      handle_packet                                  ; handle the packet
                       ret
handle_packet:         comp      s0, 0                                          ; is this a direct I2C packet?
                       jump      Z, handle_direct_i2c
                       jump      dump_unknown_packet                            ; otherwise we dump it
dump_unknown_packet:   fetch     s0, cur_length
dump_unknown_lp0:      sub       s0, 1                                          ; we already read 1 byte - the type
                       ret       Z                                              ; if there's nothing left, we finish
                       in        tmp_register, fifo                             ; otherwise we dump it
                       jump      dump_unknown_lp0
handle_direct_i2c:     in        s0, fifo                                       ; ok, read address
                       store     s0, cur_address                                ; store it
                       test      s0, $01                                        ; check the R/W bit
                       jump      Z, handle_direct_i2c_write                     ; handle a direct I2C write
                       jump      handle_direct_i2c_read                         ; handle direct read
handle_direct_i2c_write: fetch   i2c_reg0, cur_address
                         fetch   i2c_reg1, cur_length
                         sub     i2c_reg1, 2
                         load    s0, i2c_reg1
                         store   s0, cur_length                                 ; save it
                         call    i2c_write
                         load    s1, i2c_buffer
di2c_write_lp0:          in      s2, fifo
                         store   s2, s1
                         add     s1, 1
                         sub     s0, 1
                         jump    NZ, di2c_write_lp0
                         call    i2c_idle
                         jump    NZ, handle_di2c_fail
                         fetch   s0, cur_packet
                         out     s0, fifo
                         load    s0, 3
                         out     s0, fifo
                         load    s0, 0
                         out     s0, fifo
                         fetch   s0, cur_address
                         out     s0, fifo
                         fetch   s0, cur_length
                         out     s0, fifo
                         jump    fifo_packet
fifo_packet:             load    s0, $10                                        ; issue packet
                         out     s0, fifo_status
                         ret
handle_di2c_fail:        fetch   s0, cur_packet
                         out     s0, fifo
                         load    s0, 1
                         out     s0, fifo
                         load    s0, $FF
                         out     s0, fifo
                         load    s0, $10
                         jump    fifo_packet
handle_direct_i2c_read:  in      s0, fifo
                         store   s0, cur_length
                         fetch   i2c_reg0,cur_address
                         load    i2c_reg1, s0
                         call    i2c_read
                         call    i2c_idle
                         jump    NZ, handle_di2c_fail
                         fetch   s0, cur_packet
                         out     s0, fifo
                         fetch   s0, cur_length
                         add     s0, 2                                          ; type and address
                         out     s0, fifo
                         load    s0, 0
                         out     s0, fifo
                         fetch   s0, cur_address
                         out     s0, fifo
                         fetch   s0, cur_length
                         sub     s0, 0
                         jump    Z, fifo_packet
                         load    s1, i2c_buffer
di2c_read_lp0:           fetch   s2, s1
                         out     s2, fifo
                         add     s1, 1
                         sub     s0, 1
                         jump    NZ, di2c_read_lp0
                         jump    fifo_packet

; ##############################################################################
; # BEGIN                                                                      #
; # UTILITY ROUTINES                                                           #
; ##############################################################################
push_operands_4:       store     s3, stack_pointer			                    ; store s3 first
					   add	   	 stack_pointer, 1			                    ; increment stack pointer
push_operands_3:	   store     s2, stack_pointer			                    ; now store s2
					   add       stack_pointer, 1				                ; increment stack pointer
push_operands_2:       store     s1, stack_pointer				                ; now store s1
					   add       stack_pointer, 1				                ; increment stack_pointer
push_operand:		   store     s0, stack_pointer				                ; now store s0
			 		   add       stack_pointer, 1				                ; increment stack pointer
					   ret                                                      ; done
pop_operands_4:        call      pop_operands_3
                       sub       stack_pointer, 1
                       fetch     s3, stack_pointer
                       ret
pop_operands_3:        call pop_operands_2
                       sub stack_pointer, 1
                       fetch s2, stack_pointer
                       ret
pop_operands_2:        call pop_operand
                       sub stack_pointer, 1
                       fetch s1, stack_pointer
                       ret
pop_operand:           SUB     stack_pointer, 1             ; decrement stack pointer
                       FETCH s0, stack_pointer              ; restore s0
                       ret
sdiv8:                  load             s2, 0
sdiv8_loop:             sub              s0, s1
                        jump             C, sdiv8_done
                        add              s2, 1
                        jump             sdiv8_loop
sdiv8_done:             add              s0, s1
                        ret
sdiv16:                 load              s4, 0
sdiv16_loop:            sub               s1, s3
                        subc              s0, s2
                        jump              C, sdiv16_done
                        add               s4, 1
                        jump              sdiv16_loop
sdiv16_done:            add               s1, s3
                        addc              s0, s2
                        ret
sl4:                    sl0               s0
                        sl0               s0
                        sl0               s0
                        sl0               s0
                        ret
sr4:                    sr0               s0
                        sr0               s0
                        sr0               s0
                        sr0               s0
                        ret
;
; I2C housekeeping loop
;
;
tmp_mem                EQU              $2F
; SUB clear_device
; Input parameter: register s0
; Clears the bit for the device in present_devices
; s0 should contain the mask (i.e. ~ the bit for the device)
clear_device:          fetch            tmp_register, tmp_devices               ; load present devices
                       and              tmp_register, s0                        ; and present devices with parameter
                       store            tmp_register, tmp_devices               ; done
                       ret
;
; SUB add_device
; Input parameter: register s0
; Sets the bit for the device in present_devices
; s0 should contain the bit for the device
add_device:            fetch            tmp_register, tmp_devices               ; load present devices
                       or               tmp_register, s0                        ; set parameter bit
                       store            tmp_register, tmp_devices               ; done
                       ret
; ##############################################################################
; # BEGIN                                                                      #
; # GPIO ROUTINES                                                              #
; # Routines for accessing the PCA9536 I/O expander via I2C routines (v4)      #
; ##############################################################################

i2c_gpio_rd            EQU       $83
i2c_gpio_wr            EQU       $82
i2c_dac_vped_wr	       EQU       $1C
gpio_outputs:          load      i2c_reg0, i2c_gpio_wr
                       load      i2c_reg1, 2
                       call      i2c_write
                       store     s0, i2c_buffer+1
                       load      s0, $01
                       store     s0, i2c_buffer
                       call      i2c_idle
                       ret
; Initialize IRS. With DDA revD first attempt to power down the Vped DAC.

irs_init:	       load	 i2c_reg0, i2c_dac_vped_wr
		       load	 i2c_reg1, 2
		       call	 i2c_write
		       load	 s0, $30
		       store	 s0, i2c_buffer
		       load	 s0, $00
		       store	 s0, i2c_buffer+1
		       call	 i2c_idle
                       jump	 Z, set_dda_revD
		       load      s0, $04
		       load      s1, $00
	               jump      irs_init_jp0
set_dda_revD:          load      s0, $05
	               load      s1, $01
irs_init_jp0:	       store	 s1, dda_type
                       call      gpio_outputs
                       load      i2c_reg0, i2c_gpio_wr
                       load      i2c_reg1, 2
                       call      i2c_write
                       load      s0, $03
                       store     s0, i2c_buffer
                       load      s0, $00                                        ; drive all outputs
                       store     s0, i2c_buffer+1
                       call      i2c_idle
                       jump      NZ, gpio_not_present
gpio_is_present:       load      s0, gpio_present
                       jump      add_device
gpio_not_present:      load      s0, gpio_mask
                       jump      clear_device
gpio_tstst:            fetch     s0, dda_type
                       comp	     s0, $01
                       ret	     Z
                       load      s0, $05
                       call      gpio_outputs
                       load      s0, $04
                       call      gpio_outputs
                       jump      NZ, gpio_not_present
                       jump      gpio_is_present
gpio_tstclr:           fetch     s0, dda_type
                       or        s0, $06
                       call      gpio_outputs
                       fetch     s0, dda_type
                       or        s0, $04
                       call      gpio_outputs
                       jump      NZ, gpio_not_present
                       jump      gpio_is_present

; ##############################################################################
; # VCCAUX initialization. Sets up VCCAUX to 2.5V, which switches the I2C      #
; # interface over to the DDA.                                                 #
; # Sequence is pretty simple: write 0x0F to register 0x39 on LP3906           #
; # (110000=C0)                                                                #
; ##############################################################################
vccaux_init:
                       load      i2c_reg0, $C0
                       load      i2c_reg1, 2
                       call      i2c_write
                       load      s0, $39
                       store     s0, i2c_buffer
                       load      s0, $0F
                       store     s0, i2c_buffer+1
vccaux_init_lp0:       comp      i2c_regS, 1
                       jump      C, vccaux_init_lp0
                       load      s0, $04
                       out       s0, db_status
                       ret

; ##############################################################################
; # I2C idle routine. On return, Z is set on success, NZ if fail.              #
; ##############################################################################
i2c_idle:              comp  i2c_regS, 1
                       jump  C, i2c_idle
                       ret

; ##############################################################################
; # BEGIN                                                                      #
; # I2C ROUTINE SECTION                                                        #
; # I2C controller, version 4. Handles most of the I2C functions in the ISR,   #
; # by self-modifying a jump instruction. i2c_regS is 1 when the operation is  #
; # complete and successful, and 2 if the operation is complete and failed.    #
; # This allows a loop of:                                                     #
; # do_i2c:       call i2c_write                                               #
; # do_i2c_lp:    comp i2c_regS, 1                                             #
; #               jump C, do_i2c_lp                                            #
; #               jump NZ, do_i2c_failed                                       #
; # 83 total instructions.                                                     #
; # Should be included LAST!                                                   #
; ##############################################################################
; #                                                                            #
; # i2c routines:                                                              #
; #                                                                            #
; # i2c_read: read "i2c_reg1" bytes from "i2c_reg0" address into i2c_buffer    #
; #           returns immediately: i2c_regS is 1 when operation was a success, #
; #           2 when operation failed.
; # i2c_write: write "i2c_reg1" bytes to "i2c_reg0" address from i2c_buffer    #
; #           returns immediately: i2c_regS is 1 when operation was a success, #
; #           2 when operation failed.
; #                                                                            #
; # i2c registers:                                                             #
; #                                                                            #
; # i2c_regS: Status return register (s8)                                      #
; # i2c_reg0: General-purpose register (s9)                                    #
; # i2c_reg1: General-purpose register (sA)                                    #
; #                                                                            #
; # i2c memory usage:                                                          #
; #                                                                            #
; # i2c_buffer: base of 0x30 - size is maximum length of transmitted/received  #
; #             message (8 bytes is a good value)                              #
; #                                                                            #
; # i2c ports:                                                                 #
; #                                                                            #
; # i2c_base: Base address of WISHBONE I2C controller. Size = 5 addresses.     #
; #                                                                            #
; ##############################################################################
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
i2c_jumptable          DSOUT     $38
;
; I2C registers
;
i2c_regS               EQU       s8
i2c_reg0               EQU       s9
i2c_reg1               EQU       sA
;
; I2C memory locations. Buffer is from 0x10-0x37, or 0x28 (40 bytes) deep
;
i2c_buffer             EQU       $10
;
; I2C jumptable values. These need to be fixed if code is modified!
; See ORG definitions below!
;
i2c_jump_rd_1          EQU       $4B                                            ; i2c_read_wa_done
i2c_jump_rd_2          EQU       $54                                            ; i2c_read_done
i2c_jump_wr_1          EQU       $61                                            ; i2c_write_wa_done
i2c_jump_wr_2          EQU       $6B                                            ; i2c_write_done
i2c_jump_fail          EQU       $72                                            ; i2c_fail
i2c_jump_default       EQU       $7D                                            ; i2c_isr_default
;
; I2C private utility routines
;
; i2cprv_write_address: output I2C address and transmit
                   ORG       $32C
i2cprv_write_address: out       i2c_reg0, i2c_txrx                              ; load address into transmit register
                      load      i2c_regS, $90                                   ; set STA bit and WR bit..
                      out       i2c_regS, i2c_crsr                              ; .. in control register
                      ret
; i2cprv_read: begin I2C read process (and stop if last transfer)
                   ORG       $330
i2cprv_read:          load      i2c_regS, $20                                   ; set RD bit..
                      jump      NZ, i2c_read_crsr                               ; before i2cprv_read, compare i2c_reg1 to 1: if C, done, if Z, this is last
                      or        i2c_regS, $48                                   ; set STO bit and NAK bit
i2c_read_crsr:        out       i2c_regS, i2c_crsr                              ; .. in control register
                      ret
; i2cprv_write: output I2C data, begin write process (and stop if last transfer)
                   ORG       $335
i2cprv_write:         out       i2c_regS, i2c_txrx                              ; write data to be written into transmit register
                      load      i2c_regS, $10                                   ; set WR bit..
                      jump      NZ, i2cprv_write_crsr                           ; before i2cprv_write, compare i2c_reg1 to 1: if C, done, if Z, this is last
                      or        i2c_regS, $40                                   ; set STO bit
                   ORG       $339
i2cprv_write_crsr:    out       i2c_regS, i2c_crsr                              ; in control register
                      ret
; i2cprv_stop: issue I2C stop
                   ORG       $33B
i2cprv_stop:          load      i2c_regS, $40                                   ; set STO bit
                      out       i2c_regS, i2c_crsr                              ; .. in control register
                      ret
;
; I2C main routines
;
                   ORG       $33E
i2c_init:          load      i2c_regS, i2c_prerhi_value
                   out       i2c_regS, i2c_prerhi
                   load      i2c_regS, i2c_prerlo_value
                   out       i2c_regS, i2c_prerlo
                   load      i2c_regS, $C0
                   out       i2c_regS, i2c_ctr
                   ret
                   ORG       $345
i2c_read:          call      i2cprv_write_address                               ; output I2C address, issue "STA+WR" bit in control register
                   load      i2c_regS, i2c_jump_rd_1                            ; ... jumptable: on next interrupt, do i2c_read_wa_done
                   out       i2c_regS, i2c_jumptable                            ;
                   load      i2c_reg0, i2c_buffer                               ; we don't need s0 anymore: so we use it to hold the address to write output data in
                   load      i2c_regS, 0                                        ; clear i2c_regS: operation isn't complete yet.
                   ret
                   ORG       $34B                                               ; i2c_jump_rd_1 = $4B
i2c_read_wa_done:  test      i2c_regS, $A0                                      ; arb lost or nack seen?
                   jump      NZ, i2c_do_fail                                    ; if so, do fail (set stop, then set i2c_regS = 2, reti enable)
i2c_read_wa_next:  comp      i2c_reg1, 1                                        ; where are we in the write process?
                   jump      C, i2c_succeed                                     ; if so, return with succeed (set i2c_regS = 0, reti enable)
                   call      i2cprv_read
                   load      i2c_regS, i2c_jump_rd_2                             ; ... jumptable: on next interrupt, do i2c_read_done
                   out       i2c_regS, i2c_jumptable                            ;
                   load      i2c_regS, 0                                        ; clear i2c_regS: operation isn't complete yet
                   reti      enable                                             ; and return, enabling interrupt
                   ORG       $354                                               ; i2c_jump_rd_2 = $54
i2c_read_done:     test      i2c_regS, $20                                      ; Test to see if arbitration lost, ONLY. This was a read.
                   jump      NZ, i2c_do_fail
                   in        i2c_regS, i2c_txrx                                 ; read input data...
                   store     i2c_regS, i2c_reg0                                 ; .. and store it into buffer
                   add       i2c_reg0, 1
                   sub       i2c_reg1, 1                                        ;
                   jump      i2c_read_wa_next                                   ; .. and loop
                   ORG       $35B
i2c_write:         call      i2cprv_write_address
                   load      i2c_regS, i2c_jump_wr_1                            ; jumptable: on next interrupt, do i2c_write_wa_done
                   out       i2c_regS, i2c_jumptable                            ;
                   load      i2c_reg0, i2c_buffer                               ; initialize pointer to buffer
                   load      i2c_regS, 0                                        ; clear i2c_regS: operation isn't complete yet
                   ret
                   ORG       $361                                               ; i2c_jump_wr_1 = $61
i2c_write_wa_done: test      i2c_regS, $A0                                      ; arb lost or nack seen?
                   jump      NZ, i2c_do_fail                                    ; if so, do fail (set stop, then set
                   comp      i2c_reg1, 1                                        ; where are we in the write process?
                   jump      C, i2c_succeed                                     ; if less than 1 (==0), jump with succeed
                   fetch     i2c_regS, i2c_reg0                                 ; fetch data to write
                   call      i2cprv_write                                       ; do write command
                   load      i2c_regS, i2c_jump_wr_2                            ; jumptable: on next interrupt, do i2c_write_done
                   out       i2c_regS, i2c_jumptable                            ;
                   load      i2c_regS, 0                                        ; clear i2c_regS: operation isn't complete yet
                   reti      enable                                             ; return from interrupt, enable
                   ORG       $36B                                               ; i2c_jump_wr_2 = $6B
i2c_write_done:    test      i2c_regS, $A0
                   jump      NZ, i2c_do_fail
                   sub       i2c_reg1, 1                                        ; subtract length pointer,
                   add       i2c_reg0, 1                                        ; and increment buffer
                   jump      i2c_write_wa_done                                  ; and loop
                   ORG       $370
i2c_do_fail:       comp      i2c_reg1, 1                                        ; was this the last one?
                   jump      NZ, i2c_do_fail_stop                               ; if not, output stop and wait, otherwise...
                   ORG       $372                                               ; i2c_jump_fail = $72
i2c_fail:          load      i2c_regS, $02                                      ; indicate operation failure...
                   reti      enable                                             ; and return, enabling interrupt
i2c_do_fail_stop:  call      i2cprv_stop                                        ; we need to stop the I2C transaction, so output stop command...
                   load      i2c_regS, i2c_jump_fail                            ; ... jumptable: on next interrupt, do i2c_fail
                   out       i2c_regS, i2c_jumptable
                   load      i2c_regS, $00                                      ; clear status register: operation isn't complete yet
                   reti      enable                                             ; and return, enabling interrupt
                   ORG       $379
i2c_succeed:       load      i2c_regS, i2c_jump_fail                            ; operation done: so if another interrupt comes, fail and reti
                   out       i2c_regS, i2c_jumptable                            ;
                   load      i2c_regS, $01                                      ; indicate operation success...
                   reti      enable                                             ; and return, enabling interrupt
                   ORG       $37D                                               ; i2c_jump_default = $7D
i2c_isr_default:   reti      enable
                   ORG       $37E
i2c_isr:           in        i2c_regS, i2c_crsr
                   jump      i2c_isr_default
; ##############################################################################
; # END                                                                        #
; # I2C ROUTINE SECTION                                                        #
; ##############################################################################

