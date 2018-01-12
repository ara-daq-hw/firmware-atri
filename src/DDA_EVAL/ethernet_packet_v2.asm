;
; Ethernet control processor, v2.
;
; This version essentially has a completely separate interrupt service routine
; and regular running thread. The ISR processes incoming data and buffers it
; externally so the regular running thread can process it at will. This should
; make the system significantly more stable, especially by imposing a timer
; on sending event data to make sure that commands can be processed in the
; meantime.
;
ethernet_data      DSIO    $01                                                  ; port for incoming ethernet data: reading from here reads from the FIFO
                                                                                ; writing to here pushes data and does not update the CRC
ethernet_crc       DSOUT   $03                                                  ; port for outgoing ethernet data: writing to here pushed data and updates the CRC
ethernet_ctl       DSIO    $00                                                  ; control port for ethernet data
ethernet_done      DSIO    $02                                                  ; done port for ethernet data
packet_data        DSIN    $04                                                  ; port for data that has been processed by the ISR
packet_status      DSIN    $05                                                  ; port for status of the packet buffer (data from ISR)


pc_fifo_status     DSIN    $10                                                  ; port for status of the PC outbound fifo (data from packet controller)
pc_dma_ctl         DSOUT   $11                                                  ; port for beginning the DMA of data from packet buffer to PC
pc_dma_count       DSIO    $12                                                  ; port for setting the number of bytes to DMA from packet buffer to PC
pc_reset           DSOUT   $13                                                  ; port for resetting packet controller

evfifo_timer       DSIO    $14                                                  ; port for controlling event FIFO timer
evfifo_status      DSIN    $15                                                  ; port for event FIFO status
ev_dma_count       DSOUT   $16                                                  ; port for setting number of bytes for DMA from event FIFO to PC
ev_dma_ctl         DSIO    $17                                                  ; port for beginning DMA of data from event FIFO to PC
lram_page          DSIO    $18                                                  ; port for controlling LRAM page


ethernet_crc_ctl   DSOUT   $20                                                  ; port for controlling CRC
ethernet_crc_data  DSIN    $21                                                  ; port for reading calculated CRC
eframe_etype       DSIN    $24                                                  ; ethertype (low 8 bits) out of ethernet frame processor
eframe_bcast       DSIN    $25                                                  ; this packet was a broadcast send, from ethernet frame processor
eframe_sender_mac  DSIN    $28                                                  ; port for reading sender mac out of ethernet frame processor (8 ports, only 6 real)

mac                DSIN    $30                                                  ; port for reading our IP address
ip                 DSIN    $36                                                  ; port for reading our MAC address
ip_checksum_base_l DSIN    $3A
ip_checksum_base_h DSIN    $3B
lram               DSRAM   $40                                                  ; local RAM, from $40-$5F. These are the top 256 bytes, split into 8 pages of 32 (Except $3FF)
fifo               DSIN    $80                                                  ; PC outbound FIFO in
evfifo             DSIN    $81                                                  ; event FIFO outbound in
fifo_high          DSIN    $82                                                  ; unused
evfifo_high        DSIN    $83                                                  ; event FIFO high byte in (maybe unused? don't remember)

spram              DSRAM   $C0                                                  ; this is actually the internal SPRAM, mapped to port space (64 bytes)
; Registers
; ISR needs 7 registers
in0                    EQU      s9                                              ; ISR register 0
in1                    EQU      sA                                              ; ISR register 1
in2                    EQU      sB                                              ; ISR register 2
in3                    EQU      sC                                              ; ISR register 3
in4                    EQU      sD                                              ; ISR register 4
in5                    EQU      sE                                              ; ISR register 5
in6                    EQU      sF                                              ; ISR register 6

; Scratchpad RAM (64 bytes)
connected_mac_0        EQU      $00
connected_mac_1        EQU      $01
connected_mac_2        EQU      $02
connected_mac_3        EQU      $03
connected_mac_4        EQU      $04
connected_mac_5        EQU      $05
connected_ip_0         EQU      $06
connected_ip_1         EQU      $07
connected_ip_2         EQU      $08
connected_ip_3         EQU      $09
connected_ip_4         EQU      $0A
sender_mac_0           EQU      $0B                                             ; sender MAC byte 0
sender_mac_1           EQU      $0C
sender_mac_2           EQU      $0D
sender_mac_3           EQU      $0E
sender_mac_4           EQU      $0F
sender_mac_5           EQU      $10
sender_ip_0            EQU      $11
sender_ip_1            EQU      $12
sender_ip_2            EQU      $13
sender_ip_3            EQU      $14
packet_length          EQU      $15
pc_packet_buf_0        EQU      $16                                             ; PC packet buffer, byte 0 (SOF)
pc_packet_buf_1        EQU      $17                                             ; PC packet buffer, byte 1 (source)
pc_packet_buf_2        EQU      $18                                             ; PC packet buffer, byte 2 (pktno)
ev_frame_remain_l      EQU      $19                                             ; event remaining, low
ev_frame_remain_h      EQU      $1A                                             ; event remaining, high
ev_frame_number        EQU      $1B                                             ; event frame number
tmp_store              EQU      $1C                                             ; temporary - any function can use (non-ISR)
tmp_store_0            EQU      $1D
tmp_store_1            EQU      $1E
connected              EQU      $1F                                             ; are we connected?
ev_frame_header        EQU      $20
ev_frame_cur_number    EQU      $21
ev_frame_cur_remain_l  EQU      $22
ev_frame_cur_remain_h  EQU      $23
isr_sender_mac_0       EQU      $30                                             ; sender MAC byte 0 in ISR
isr_sender_mac_1       EQU      $31                                             ; sender MAC byte 1 in ISR
isr_sender_mac_2       EQU      $32                                             ; sender MAC byte 2 in ISR
isr_sender_mac_3       EQU      $33                                             ; sender MAC byte 3 in ISR
isr_sender_mac_4       EQU      $34                                             ; sender MAC byte 4 in ISR
isr_sender_mac_5       EQU      $35                                             ; sender MAC byte 5 in ISR
isr_sender_ip_0        EQU      $36                                             ; sender IP byte 0 in ISR
isr_sender_ip_1        EQU      $37                                             ; sender IP byte 1 in ISR
isr_sender_ip_2        EQU      $38                                             ; sender IP byte 2 in ISR
isr_sender_ip_3        EQU      $39                                             ; sender IP byte 3 in ISR
isr_ip_length          EQU      $3A                                             ; IP packet length (low only)

spram_connected_mac_0  EQU      $C0                                             ; connected MAC byte 0
spram_connected_ip_0   EQU      $C6                                             ; connected IP byte 0
spram_sender_mac_0     EQU      $CB                                             ; sender MAC byte 0
spram_sender_ip_0      EQU      $D1                                             ; sender IP byte 0

spram_isr_sender_mac_0       EQU      $F0                                       ; sender MAC byte 0 in ISR
spram_isr_sender_ip_0        EQU      $F6                                       ; sender IP byte 0 in ISR
spram_isr_ip_length          EQU      $FA                                       ; IP packet length (low only)

; Ethernet definitions
ETHERTYPE_HIGH_ARP_IP  EQU      $08                                             ; ARP/IP high byte ethertype
ETHERTYPE_LOW_ARP      EQU      $06                                             ; ARP ethertype (0x0806)
ETHERTYPE_LOW_IP       EQU      $00                                             ; IP ethertype (0x0800)
ARP_HTYPE_HIGH_ETH     EQU      $00
ARP_HTYPE_LOW_ETH      EQU      $01
ARP_PTYPE_HIGH_IPV4    EQU      $08
ARP_PTYPE_LOW_IPV4     EQU      $00
ARP_REQUEST            EQU      $01
IPV4_AND_5_INTS        EQU      $45
IPPROTO_UDP            EQU      $11
IPPROTO_ICMP           EQU      $01
ETHERNET_PREAMBLE      EQU      $55
ETHERNET_PREAMBLE_BYTES EQU     $07
ETHERNET_SFD           EQU      $D5
ETHERNET_MIN_PAYLOAD_SIZE EQU   $2E                                             ; Ethernet min payload size (46 bytes)
IP_MIN_PAYLOAD_SIZE    EQU      $1A                                             ; IP min payload size (26 bytes)
UDP_MIN_PAYLOAD_SIZE   EQU      $12                                             ; UDP min payload size (18 bytes)
ICMP_ECHO_REQUEST      EQU      $08
ICMP_ECHO_REPLY        EQU      $00
IP_TTL                 EQU      $80
UDP_MIN_PACKET_SIZE    EQU      $08                                             ; 2 bytes for src port, 2 bytes for dest port, 2 bytes for length, 2 bytes for cksum
IP_MIN_PACKET_SIZE     EQU      $14                                             ; IP min size is 20 bytes
; Ethernet control definitions
ETHERNET_CTL_DUMP      EQU      $03                                             ; ethernet_dump_frame && ethernet_enable
ETHERNET_CTL_TRANSMIT  EQU      $41                                             ; ethernet_transmit_frame && ethernet_enable
ETHERNET_CTL_TXRDY_BIT EQU      $10                                             ; ethernet can transmit now
ETHERNET_CTL_DONE_BIT  EQU      $08
; LRAM pages
LRAM_PAGE_ARP          EQU      $00                                             ; Constant portion of an ARP header
LRAM_PAGE_IDENT_STR    EQU      $20                                             ; Version string that we output on version request


;
; MAIN PROGRAM GOES HERE
; We have from address 0x000 to 0x308, registers s0-s8, and SPRAM address 00-0x2F.
; Should be enough, I hope.
;
; Definitions
PACKET_EMPTY_BIT               EQU      $01
PC_NOT_EMPTY_BIT               EQU      $01
EVFIFO_TIMER_EXPIRED_BIT       EQU      $01
EVFIFO_NOT_EMPTY_BIT           EQU      $10                                     ; bottom nybble is type
PACKET_TYPE_ARP                EQU      $06
PACKET_TYPE_UDP                EQU      $11
PACKET_TYPE_ICMP               EQU      $01
PC_MIN_PACKET_SIZE             EQU      $05                                     ; SOF SRC PKTNO PKTLEN EOF
EV_MIN_PACKET_SIZE             EQU      $04                                     ; ftype fno rem_l rem_h
UDP_CTRL_PORT_HIGH             EQU      $1B
UDP_CTRL_PORT_LOW              EQU      $59
UDP_CONN_PORT_HIGH             EQU      $1B
UDP_CONN_PORT_LOW              EQU      $58
UDP_EVENT_PORT_HIGH            EQU      $1B
UDP_EVENT_PORT_LOW             EQU      $5A

IDENT_PACKET_SIZE              EQU      $20
EV_MIN_PAYLOAD_SIZE            EQU      $0E                                     ; Minimum event payload (14 bytes)
EV_MIN_FRAME_SIZE              EQU      $04                                     ; Minimum event frame size (4 bytes)
EV_FRAME_MAX                   EQU      $DE                                     ; Maximum event frame size (222 bytes)

ETHERNET_DONE_ARP              EQU      $01
ETHERNET_DONE_IP               EQU      $02
ETHERNET_DONE_UDP_ICMP         EQU      $04

init:                                                                           ; Do any initialization
                       in       s0, ethernet_ctl
                       test     s0, $20
                       jump     Z, init
                       load     s0, $01
                       out      s0, ethernet_ctl                                ; enable
                       eint
main_loop:                                                                      ; Begin main loop
                       in       s0, packet_status                               ; check inbound packet status
                       test     s0, PACKET_EMPTY_BIT                            ; is the PACKET_EMPTY_BIT set?
                       jump     Z, handle_ethernet_packet                       ; no: so handle ethernet packet
                       fetch    s0, connected
                       comp     s0, 1
                       jump     NZ, main_loop                                   ; if we're not connected, skip everything else
                       in       s0, pc_fifo_status                              ; check PC inbound FIFO
                       test     s0, PC_NOT_EMPTY_BIT                            ; is the PC_EMPTY_BIT set?
                       jump     Z, handle_pc_packet                             ; no: so handle packet controller packet
                       in       s0, evfifo_timer                                ; check the event fifo timer
                       test     s0, EVFIFO_TIMER_EXPIRED_BIT                    ; is the EVFIFO_TIMER_EXPIRED_BIT set?
                       jump     Z, main_loop                                    ; yes: so jump back to the main loop (event pacing)
                       in       s0, evfifo_status                               ; check the event FIFO status
                       test     s0, EVFIFO_NOT_EMPTY_BIT                        ; is the EVFIFO_NOT_EMPTY_BIT set?
                       jump     NZ, handle_event_frame                          ; no: so handle event frame
                       jump     main_loop                                       ; and repeat!
handle_ethernet_packet:                                                         ; We have an inbound Ethernet packet to handle
                       in       s6, packet_data                                 ; First byte is packet type
                       in       s0, packet_data                                 ; Length: if ARP, this is 10. If IP, this is PAYLOAD LENGTH: MINUS IP header length
                       store    s0, packet_length                               ; store it into SPRAM
                       load     s1, packet_data                                 ; copy MAC+IP to SPRAM
                       load     s2, spram_sender_mac_0                          ;
                       load     s3, $00
                       load     s4, $01
                       load     s0, 10
                       call     portcopy                                        ; copy MAC+IP to SPRAM
                       comp     s6, PACKET_TYPE_ARP                             ; is it an ARP packet?
                       jump     Z, handle_arp_packet                           ; yes, handle it
                       comp     s6, PACKET_TYPE_ICMP                            ; is it an ICMP ping packet?
                       jump     Z, handle_icmp_packet                          ; yes, handle it
                       comp     s6, PACKET_TYPE_UDP                             ; is it a UDP packet?
                       jump     Z, handle_udp_packet                           ; yes, handle it
                       jump     main_loop                                       ; huh?
handle_arp_packet:                                                              ; We have an inbound ARP packet to handle
                       load     s0, ETHERTYPE_LOW_ARP
                       call     do_ethernet_header                              ; Output the Ethernet header (also waits for transmit available)
                       load     s0, LRAM_PAGE_ARP                               ; Switch the LRAM to ARP page
                       out      s0, lram_page                                   ; (cont.)
                       load     s1, lram                                        ; Prepare to portcopy (src)
                       load     s2, ethernet_crc                                ; Prepare to portcopy (dst)
                       load     s3, $01                                         ; Prepare to portcopy (src incr)
                       load     s4, $00                                         ; Prepare to portcopy (dst incr)
                       load     s0, 8                                           ; Prepare to portcopy (nbytes)
                       call     portcopy                                        ; Copy ARP header to Ethernet
                       load     s1, mac                                         ; Prepare to portcopy (src)
                       load     s0, 10                                          ; Prepare to portcopy (nbytes)
                       call     portcopy                                        ; Copy MAC and IP to Ethernet (dst, dst incr, src incr stay the same)
                       load     s1, spram_sender_mac_0                          ; Prepare to portcopy (src)
                       load     s0, 10                                          ; Prepare to portcopy (nbytes)
                       call     portcopy                                        ; Copy sender MAC and sender IP to Ethernet (dst, dst incr, src incr stay the same)
                       load     s0, $00                                         ; prepare to fill (fill byte)
                       load     s1, 18                                          ; prepare to fill (nbytes)
                       load     s2, ethernet_crc                                ; prepare to fill (dst)
                       call     do_fill_out                                     ; Fill 18 zeroes
                       call     do_crc_out                                      ; output Ethernet CRC, and we're done
                       jump     main_loop                                       ; and begin main loop again
handle_icmp_packet:                                                             ; We have an ICMP packet to handle (length, MAC, IP autofilled)
                       fetch    s0, packet_length                               ; packet length here is number of payload bytes in IP packet (after IP header)
                       sub      s0, 1                                           ; sub off the type
                       load     s1, packet_data                                 ; get ready if we need to dump
                       in       s6, packet_data                                 ; Read type
                       comp     s6, ICMP_ECHO_REQUEST                           ; is it a ping request?
                       jump     Z, handle_icmp_packet_cp0
                       call     do_dump
                       jump     main_loop
handle_icmp_packet_cp0:
                       load     s0, ETHERTYPE_LOW_IP
                       call     do_ethernet_header                              ; output the Ethernet header
                       load     s0, IPPROTO_ICMP
                       fetch    s1, packet_length                               ; fetch payload length
                       call     do_ip_header                                    ; output the IP header
                       load     s0, ICMP_ECHO_REPLY                             ; output type is echo reply
                       out      s0, ethernet_crc                                ; output type
                       out      s0, ethernet_crc                                ; output code is also 0
                       in       s0, packet_data                                 ; get type and ignore it
                       in       s0, packet_data                                 ; first byte of checksum
                       in       s1, packet_data                                 ; second byte of checksum
                       add      s0, $08                                         ; add 0x08 to high byte and if we overflow...
                       addc     s1, $00                                         ; add 1 to low byte
                       out      s0, ethernet_crc                                ; output new checksum
                       out      s1, ethernet_crc                                ; output new checksum
                       load     s1, packet_data
                       load     s2, ethernet_crc
                       load     s3, 0
                       load     s4, 0
                       fetch    s0, packet_length                               ; get IP packet length
                       sub      s0, 4                                           ; subtract code/type/checksum/checksum
                       call     portcopy                                        ; copy remaining bytes to ethernet CRC
                       load     s0, $00                                         ; fill byte
                       load     s2, ethernet_crc                                ; fill dest
                       fetch    s1, packet_length
                       sub      s1, IP_MIN_PAYLOAD_SIZE                         ; packet length is payload length - must be 26 bytes or more to fill min frame
                       call     C, do_calculated_fill
                       call     do_crc_out
                       jump     main_loop
handle_udp_packet:
                       fetch    s0, packet_length                               ; this is the payload length
                       sub      s0, 4                                           ; subtract off source/dest port bytes in case we need to dump
                       store    s0, packet_length                               ; re-store the packet length
                       load     s1, packet_data                                 ; get ready in case we need to dump
                       in       s2, packet_data                                 ; ignore source port high
                       in       s2, packet_data                                 ; ignore source port low
                       in       s2, packet_data                                 ; get dest port high
                       in       s3, packet_data                                 ; get dest port low
                       comp     s2, UDP_CTRL_PORT_HIGH                          ; compare to 0x1B
                       jump     Z, handle_udp_packet_cp0                        ; if yes, continue
                       call     do_dump
                       jump     main_loop
handle_udp_packet_cp0:
                       comp     s3, UDP_CONN_PORT_LOW                           ; is it a connection port request?
                       jump     Z, handle_connection_request                    ; if so, handle it
                       comp     s3, UDP_CTRL_PORT_LOW                           ; is it data on the control port?
                       jump     Z, handle_control_packet                        ; if so, handle it
                       comp     s3, UDP_EVENT_PORT_LOW                          ; is it data on the event port?
                       jump     Z, handle_event_packet                          ; if so, handle it
                       call     do_dump                                         ; I don't know what you are, go away
                       jump     main_loop
handle_connection_request:                                                      ; someone sent a packet on our connection port
                       load     s0, 10
                       load     s1, spram_sender_mac_0
                       load     s2, spram_connected_mac_0
                       load     s3, 1
                       load     s4, 1
                       call     portcopy
                       load     s1, packet_data                                 ; prep to dump if we need to
                       fetch    s0, packet_length                               ; packet length is now UDP payload length
                       comp     s0, 0                                           ; are there non-zero bytes remaining?
                       call     NZ, do_dump                                      ; get rid of the remaining bytes
                       load     s0, ETHERTYPE_LOW_IP                            ; this is an IP packet
                       call     do_ethernet_header                              ; Check to see if we can transmit.
                       load     s0, IPPROTO_UDP                                 ; this is a UDP packet
                       load     s1, UDP_MIN_PACKET_SIZE + IDENT_PACKET_SIZE     ; IP payload length
                       call     do_ip_header
                       load     s0, UDP_CONN_PORT_LOW
                       load     s1, IDENT_PACKET_SIZE                           ; UDP payload length
                       call     do_udp_header
                       load     s0, LRAM_PAGE_IDENT_STR                         ; Switch to LRAM page
                       out      s0, lram_page
                       load     s0, IDENT_PACKET_SIZE
                       load     s1, lram
                       load     s2, ethernet_crc
                       load     s3, 1
                       load     s4, 0
                       call     portcopy                                        ; and portcopy ident packet over
                       call     do_crc_out                                      ; IDENT_PACKET_SIZE is 32, so we're already over (20+8+32 > 46)
                       load     s0, 1
                       store    s0, connected                                   ; set connected = 1
                       jump     main_loop
handle_control_packet:
                       fetch    s0, packet_length                               ; packet_length is the number of bytes after source/dest ports.
                       load     s1, packet_data
                       fetch    s2, connected
                       comp     s2, 0
                       call     Z, do_dump                                      ; if we haven't gotten a connection packet yet, we ignore it
                       jump     Z, main_loop                                    ; do_dump returns with Z set
                       ; Need to dump first 4 bytes
                       load     s0, 4                                           ; we need to dump the first 4 bytes anyway (length, checksum)
                       call     do_dump                                         ; s1 is unaffected prior to this
                       ; Now fetch the length
                       fetch    s0, packet_length
                       sub      s0, 4                                           ; subtract off the 4 we just dumped (header length, checksum)
                       out      s0, pc_dma_count                          ; prep to DMA to packet fifo
                       out      s0, pc_dma_ctl                                ; .. and DMA over the data
check_dma_complete:    in       s0, pc_dma_ctl
                       test     s0, $01                                         ; check to see if the DMA is done
                       jump     Z, check_dma_complete                           ; if not, check again
                       jump     main_loop
handle_event_packet:
                       fetch    s0, packet_length
                       call     do_dump
                       jump     main_loop
handle_pc_packet:                                                               ; We have a packet to handle from the packet controller FIFO
                       call     store_connected_mac_ip                          ; Copy our current connection's mac/ip to sender mac/ip.
                       load     s0, ETHERTYPE_LOW_IP                            ; this is an IP packet
                       call     do_ethernet_header                              ; We can do an ethernet header now. This also checks to see if we can transmit.
                       in       s0, fifo                                        ; get SOF
                       store    s0, pc_packet_buf_0                             ; store
                       in       s0, fifo                                        ; get src
                       store    s0, pc_packet_buf_0 + 1                         ; store
                       in       s0, fifo                                        ; get pktno
                       store    s0, pc_packet_buf_0 + 2                         ; store
                       in       s1, fifo                                        ; get packet length. This is what we need
                       add      s1, PC_MIN_PACKET_SIZE
                       store    s1, packet_length                               ; packet_length is now the UDP payload size
                       add      s1, UDP_MIN_PACKET_SIZE                         ; add minimum packet sizes (IP payload size)
                       load     s0, IPPROTO_UDP                                 ; this is a UDP packet
                       call     do_ip_header                                    ; add the IP header
                       load     s0, UDP_CTRL_PORT_LOW                           ; prep for UDP header
                       fetch    s1, packet_length                               ; this is UDP payload size
                       call     do_udp_header                                   ; add the UDP header
                       fetch    s0, pc_packet_buf_0                             ; get SOF, src, len, and output them
                       out      s0, ethernet_crc                                ; output SOF
                       fetch    s0, pc_packet_buf_0 + 1
                       out      s0, ethernet_crc                                ; output SRC
                       fetch    s0, pc_packet_buf_0 + 2
                       out      s0, ethernet_crc                                ; output PKTNO
                       fetch    s0, packet_length                               ;
                       sub      s0, PC_MIN_PACKET_SIZE                          ;
                       out      s0, ethernet_crc                                ; output PKTLEN
                       load     s1, fifo                                        ; prepare to portcopy (src)
                       load     s2, ethernet_crc                                ; prepare to portcopy (dst)
                       load     s3, 0                                           ; prepare to portcopy (src incr)
                       load     s4, 0                                           ; prepare to portcopy (dst incr)
                       call     portcopy                                        ; copy remaining bytes to Ethernet
                       in       s0, fifo                                        ; get EOF
                       out      s0, ethernet_crc                                ; and output it
                       fetch    s1, packet_length
                       sub      s1, UDP_MIN_PAYLOAD_SIZE                        ; are we under the min UDP payload size (probably)?
                       call     C, do_calculated_fill
                       call     do_crc_out
                       jump     main_loop
handle_event_frame:                                                             ; We have an event frame to handle
                       out      s0, evfifo_timer                                ; Reset the timer.
                       call     store_connected_mac_ip                          ; Copy our current connection's mac/ip to sender mac/ip.
                       load     s0, ETHERTYPE_LOW_IP                            ; this is an IP packet
                       call     do_ethernet_header                              ; We can do an ethernet header now. This also checks to see if we can transmit.
                       in       s0, evfifo_status                               ; fetch the base type (gets uppercased in handle_new_event)
                       and      s0, $0F
                       or       s0, $40
                       store    s0, ev_frame_header                             ; and store it
                       fetch    s0, ev_frame_number                             ; is an event in progress? If not, frame counter is zero.
                       store    s0, ev_frame_cur_number                         ; store the current number (gets restored in handle_new_event)
                       comp     s0, 0
                       call     Z, handle_new_event                             ; Do housekeeping for first frame.
                       add      s0, 1                                           ; s0 is still ev_frame_number, so increment it
                       store    s0, ev_frame_number                             ; and store it again
                       fetch    s1, ev_frame_remain_l
                       fetch    s2, ev_frame_remain_h
                       store    s1, ev_frame_cur_remain_l
                       store    s2, ev_frame_cur_remain_h
                       load     s0, EV_FRAME_MAX
                       sub      s1, s0
                       subc     s2, 0
                       jump     NC, handle_event_frame_cp0                      ; If we didn't overflow (last frame) continue on
                       add      s1, s0                                          ; otherwise add it back
                       addc     s2, 0                                           ; .. ditto
                       load     s0, s1                                          ; and copy s1 to s0 (number of bytes to write)
                       store    s2, ev_frame_number                             ; s2 must be 0 at this point (since we fixed the carry above)
                       sub      s1, s0
                       subc     s2, 0                                           ; zero out s1, s2 (total bytes remaining)
handle_event_frame_cp0:
                       store    s1, ev_frame_remain_l
                       store    s2, ev_frame_remain_h
                       store    s0, packet_length                               ; store the number of event bytes we're going to DMA
                       add      s0, EV_MIN_FRAME_SIZE + UDP_MIN_PACKET_SIZE     ; add the minimum event frame size and minimum UDP packet size
                       load     s1, s0                                          ; sigh, register remap
                       load     s0, IPPROTO_UDP
                       call     do_ip_header                                    ; and do the IP header
                       load     s0, UDP_EVENT_PORT_LOW
                       fetch    s1, packet_length
                       add      s1, EV_MIN_FRAME_SIZE
                       call     do_udp_header
                       fetch    s0, ev_frame_header
                       out      s0, ethernet_crc
                       fetch    s0, ev_frame_cur_number
                       out      s0, ethernet_crc
                       fetch    s0, ev_frame_cur_remain_l
                       out      s0, ethernet_crc
                       fetch    s0, ev_frame_cur_remain_h
                       out      s0, ethernet_crc
                       fetch    s0, packet_length
                       load     s1, evfifo
;                       out      s0, ev_dma_count
;                       out      s0, ev_dma_ctl
handle_event_frame_lp0:
                       in        s2, s1
                       out       s2, ethernet_crc
                       xor       s1, $02
                       sub       s0, 1
                       jump      NZ, handle_event_frame_lp0
;                       in       s0, ev_dma_ctl
;                       test     s0, $01
;                      jump     Z, handle_event_frame_lp0
                       fetch    s1, packet_length
                       sub      s1, EV_MIN_PAYLOAD_SIZE
                       call     C, do_calculated_fill
                       call     do_crc_out
                       jump     main_loop
handle_new_event:
                       in       s1, evfifo                                      ; Fetch number of words, low
                       in       s2, evfifo_high                                 ; Fetch number of words, high
                       sl0      s1
                       sla      s2                                              ; shift up by 1 to get bytes
                       store    s1, ev_frame_remain_l
                       store    s2, ev_frame_remain_h
                       fetch    s1, ev_frame_header
                       or       s1, $20
                       store    s1, ev_frame_header
                       ret                                                      ; don't touch s0, as it's zero before and needs to be after
portcopy:                                                                       ; Copy from one port to another.
                       in       s5, s1
                       out      s5, s2
                       add      s1, s3                                          ; source increment
                       add      s2, s4                                          ; dest increment
                       sub      s0, 1
                       ret      Z
                       jump     portcopy
do_calculated_fill:    load     s2, ethernet_crc                                ; pad
                       load     s0, $00
                       xor      s1, $FF                                         ; 2's complement s1 (number of bytes)
                       add      s1, 1                                           ; ... and move on to do_fill_out
do_fill_out:                                                                    ; Fill port output with a fixed byte
                       out      s0, s2
                       sub      s1, 1
                       jump     NZ, do_fill_out
                       ret
do_dump:                                                                        ; Read and ignore N bytes from a port
                       in       s2, s1
                       sub      s0, 1
                       jump     NZ, do_dump
                       ret
do_ethernet_header:                                                             ; Fill the Ethernet header
                       store    s0, tmp_store                                   ; Store s0 (we know the functions later don't use this)
                       call     wait_ethernet_tx_ready                          ; Wait for TX ready
                       load     s0, ETHERNET_PREAMBLE                           ; Prepare to do_fill_out (constant) load ETHERNET_PREAMBLE ($55)
                       load     s1, ETHERNET_PREAMBLE_BYTES                     ; Prepare to do_fill_out (nbytes)
                       load     s2, ethernet_data                               ; Prepare to do_fill_out (dst)
                       call     do_fill_out
                       load     s0, ETHERNET_SFD                                ; load start of frame delimiter (SFD)
                       out      s0, ethernet_data                               ; output it to Ethernet
                       load     s1, spram_sender_mac_0                          ; prepare to portcopy (src)
                       load     s2, ethernet_crc                                ; prepare to portcopy (dst)
                       load     s3, $01                                         ; prepare to portcopy (src incr)
                       load     s4, $00                                         ; prepare to portcopy (dst incr)
                       load     s0, 6                                           ; prepare to portcopy (nbytes)
                       call     portcopy                                        ; copy sender MAC to Ethernet
                       load     s1, mac                                         ; prepare to portcopy (src)
                       load     s0, 6                                           ; prepare to portcopy (nbytes)
                       call     portcopy                                        ; copy my MAC to Ethernet (dst, dst incr, src incr stay the same)
                       load     s0, ETHERTYPE_HIGH_ARP_IP                       ; Ethertype high byte
                       out      s0, ethernet_crc
                       fetch    s0, tmp_store
                       out      s0, ethernet_crc                                ; Ethertype low byte
                       ret
do_ip_header:                                                                   ; Output the IP header (s0 is ipproto)
                       store    s0, tmp_store
                       add      s1, IP_MIN_PACKET_SIZE                          ; add length of IP header
                       store    s1, tmp_store+1
; Get the checksum base (stored externally since it's parameterized)
; IP header calculation:
; Start with the base (since most of the IP header bytes are unchanged:
; sender IP, etc.), and then for each two byte short pair (s2,s3) (s2 = [7:0], s3 = [15:8])
; modify the checksum stored in (s0, s1) (s0 = [7:0], s1 = [15:8]) as
; subc s1, s3
; subc s0, s2
                       in       s0, ip_checksum_base_l
                       in       s1, ip_checksum_base_h
; The checksum base includes IPPROTO_HIGH already, so fetch the low byte...
                       fetch    s2, tmp_store                                   ; fetch IPPROTO_LOW
; and just subtract
                       sub      s0, s2                                          ; begin sub
; Now fetch the length. High byte is always zero.
                       fetch    s2, tmp_store+1                                 ; fetch length
                       subc     s0, s2                                          ; sub
                       subc     s1, $00                                         ; length high is always $00
; Now fetch the sender IP, [15:0]
                       fetch     s2, sender_ip_3                                 ;
                       fetch     s3, sender_ip_2                                 ;
; and subtract
                       subc     s0, s2
                       subc     s1, s3
; Now fetch the sender IP second word [31:16]
                       fetch     s2, sender_ip_1
                       fetch     s3, sender_ip_0
; and subtract
                       subc     s0, s2
                       subc     s1, s3
; and pull the carry over
                       subc     s0, $00
; Now we're done: (s0,s1) contains our checksum.
                       load     s2, IPV4_AND_5_INTS                             ; version/IHL
                       out      s2, ethernet_crc
                       load     s2, $00
                       out      s2, ethernet_crc                                ; type of service
                       out      s2, ethernet_crc                                ; always less than 256 bytes (length high)
                       fetch    s2, tmp_store+1
                       out      s2, ethernet_crc                                ; length (low)
                       load     s2, $00
                       out      s2, ethernet_crc                                ; ident high
                       out      s2, ethernet_crc                                ; ident low
                       out      s2, ethernet_crc                                ; fragment high
                       out      s2, ethernet_crc                                ; fragment low
                       load     s2, IP_TTL                                      ; time to live
                       out      s2, ethernet_crc
                       fetch    s2, tmp_store                                   ; get back IPPROTO
                       out      s2, ethernet_crc
                       out      s1, ethernet_crc                                ; checksum high
                       out      s0, ethernet_crc                                ; checksum low
                       load     s1, ip                                          ; prepare to portcopy (src)
                       load     s2, ethernet_crc                                ; prepare to portcopy (dst)
                       load     s3, $01                                         ; src incr
                       load     s4, $00                                         ; dst incr
                       load     s0, 4                                           ; nbytes
                       call     portcopy                                        ; copy my IP
                       load     s1, spram_sender_ip_0
                       load     s0, 4
                       call     portcopy                                        ; copy dest IP
                       ret
do_udp_header:                                                                  ; Fill a UDP header: s0 is low port byte, s1 is length
                       add      s1, UDP_MIN_PACKET_SIZE                         ; add UDP minimum packet size
                       load     s2, UDP_CONN_PORT_HIGH                          ; they're all the same, so just use one
                       out      s2, ethernet_crc                                ; dest port high (same as src)
                       out      s0, ethernet_crc                                ; dest port low (same as src)
                       out      s2, ethernet_crc                                ; source port high (same as dest)
                       out      s0, ethernet_crc                                ; source port low (same as dest)
                       load     s0, $00                                         ; only send 0-255 bytes
                       out      s0, ethernet_crc                                ; length high
                       out      s1, ethernet_crc                                ; length low
                       out      s0, ethernet_crc                                ; checksum high
                       out      s0, ethernet_crc                                ; checksum low
                       ret                                                      ; done
do_crc_out:
                       load     s1, ethernet_crc_data                           ; Prepare to portcopy (src)
                       load     s2, ethernet_data                               ; Prepare to portcopy (dst)
                       load     s3, $00                                         ; Prepare to portcopy (src increment)
                       load     s4, $00                                         ; Prepare to portcopy (dst increment)
                       load     s0, 4                                           ; Prepare to portcopy (nbytes)
                       call     portcopy                                        ; Copy Ethernet CRC to Ethernet TX
                       load     s0, ETHERNET_CTL_TRANSMIT                       ; transmit
                       out      s0, ethernet_ctl                                ; actually output it
                       ret
store_connected_mac_ip:                                                         ; copy connected_mac and ip to sender_mac and ip
                       load     s0, 10                                          ; prepare to portcopy (nbytes)
                       load     s1, spram_connected_mac_0                       ; prepare to portcopy (src)
                       load     s2, spram_sender_mac_0                          ; prepare to portcopy (dst)
                       load     s3, 1                                           ; prepare to portcopy (src incr)
                       load     s4, 1                                           ; prepare to portcopy (dst incr)
                       jump     portcopy                                        ; portcopy will ret for us
wait_ethernet_tx_ready:                                                         ; Wait for Ethernet transmitter ready
                       in       s0, ethernet_ctl
                       test     s0, ETHERNET_CTL_TXRDY_BIT
                       jump     Z, wait_ethernet_tx_ready
                       ret
;
; ISR GOES HERE
;
; The ISR now handles EVERY IP packet immediately as soon as it comes in,
; and buffers it into an external dual-port RAM. This means that the total BRAM
; cost is 2 dual-port RAMs (not counting the external FIFOs since every PHY
; needs those).
;

ORG $300
isr_frame:                                                                      ; we have a frame
;                       in       in0, ethernet_ctl                               ; check to see if it's completed
;                      test     in0, ETHERNET_CTL_DONE_BIT                      ; check
;                      jump     Z, isr_frame                                    ; if not, loop back
                       in       in0, eframe_etype                               ; read ethernet frame type
                       comp     in0, ETHERTYPE_LOW_ARP                          ; is it ARP?
                       jump     Z, isr_arp                                      ; it is
                       comp     in0, ETHERTYPE_LOW_IP                           ; is it IP?
                       jump     Z, isr_ip                                       ; it is
                       jump     isr_dump_frame                                  ; um, ooookay
isr_arp:                                                                        ; it's an ARP packet
                       in       in0, ethernet_done                              ; check to see if it's completed
                       test     in0, ETHERNET_DONE_ARP
                       jump     Z, isr_arp
                       in       in0, ethernet_data                              ; HTYPE, high
                       comp     in0, ARP_HTYPE_HIGH_ETH                         ; is it Ethernet? (what else would it be?!)
                       jump     NZ, isr_dump_frame                              ; no, go away
                       in       in0, ethernet_data                              ; HTYPE, low
                       comp     in0, ARP_HTYPE_LOW_ETH                          ; is it Ethernet?
                       jump     NZ, isr_dump_frame                              ; no, go away
                       in       in0, ethernet_data                              ; PTYPE, high
                       comp     in0, ARP_PTYPE_HIGH_IPV4                        ; is it IPv4
                       jump     NZ, isr_dump_frame                              ; no, go away
                       in       in0, ethernet_data                              ; PTYPE, low
                       comp     in0, ARP_PTYPE_LOW_IPV4                         ; is it IPv4
                       jump     NZ, isr_dump_frame                              ; no, go away
                       load     in0, 3                                          ;
                       call     isr_skip                                        ; skip HLEN, PLEN, high byte of OPER
                       in       in0, ethernet_data                              ; check request
                       comp     in0, ARP_REQUEST                                ; is it a request?
                       jump     NZ, isr_dump_frame                              ; no, go away
                       load     in0, 10                                         ; prepare to isr_copy (n)
                       load     in1, ethernet_data                              ; prepare to isr_copy (src)
                       load     in2, spram_isr_sender_mac_0                     ; prepare to isr_copy (dst)
                       load     in3, 0                                          ; prepare to isr_copy (src incr)
                       load     in4, 1                                          ; prepare to isr_copy (dst incr)
                       call     isr_copy                                        ; copy data to scratchpad ram
                       load     in0, 6                                          ; prepare to isr_skip
                       call     isr_skip                                        ; skip Target Hardware Address (6 bytes)
                       call     isr_check_ip                                    ; check the next 4 bytes against our IP (if NZ, no match)
                       jump     NZ, isr_dump_frame                              ; not for us, go away
isr_arp_for_me:                                                                 ; it's an ARP packet for me!
                       load     in0, ETHERTYPE_LOW_ARP                          ; prepare to put into packet fifo
                       out      in0, packet_data                                ; output $06 (packet fifo)
                       load     in1, spram_isr_sender_mac_0                     ; prepare to isr_copy (src)
                       load     in2, packet_data                                ; prepare to isr_copy (dst)
                       load     in3, 1                                          ; prepare to isr_copy (src incr)
                       load     in4, 0                                          ; prepare to isr_copy (dst incr)
                       load     in0, 10                                         ; prepare to put length into packet FIFO
                       out      in0, packet_data                                ; output length (also isr_copy's nbytes)
                       call     isr_copy                                        ; copy data to packet fifo
                       jump     isr_dump_frame                                  ; we're done
isr_ip:                                                                         ; we have an IP packet
                       in       in0, ethernet_done                              ; check to see if it's completed
                       test     in0, ETHERNET_DONE_IP                           ; is the IP header completed?
                       jump     Z, isr_ip
                       in       in0, eframe_bcast                               ; was this a broadcast IP? I don't like those
                       comp     in0, 1                                          ; if it was eframe_bcast is 1
                       jump     Z, isr_dump_frame                               ; OK, skip it, you jerk
                       in       in0, ethernet_data                              ; load version and num header ints
                       comp     in0, IPV4_AND_5_INTS                            ; we only handle 'normal' IP packets
                       jump     NZ, isr_dump_frame
                       in       in0, ethernet_data                              ; Skip DSCP/ECN
                       in       in0, ethernet_data                              ; get length high
                       comp     in0, 0                                          ; we don't handle more than 256 byte packets. period. screw you, IPv4!
                       jump     NZ, isr_dump_frame                              ; go away
                       in       in0, ethernet_data                              ; get length low
                       sub      in0, 20                                         ; subtract off the header
                       jump     C, isr_dump_frame                               ; screwed up IP packet
                       jump     Z, isr_dump_frame                               ; zero byte IP packet (whatever)
                       store    in0, isr_ip_length                              ; store length
                       load     in0, 5                                          ; get ready to skip
                       call     isr_skip                                        ; skip ident, flags, fragment offset, and ttl
                       in       in6, ethernet_data                              ; get protocol
                       comp     in6, IPPROTO_UDP                                ; check if it's UDP
                       jump     Z, isr_ip_udp_or_icmp                           ; it is
                       comp     in6, IPPROTO_ICMP                               ; check if it's ICMP
                       jump     Z, isr_ip_udp_or_icmp                           ; it is
                       jump     isr_dump_frame                                  ; it's not, go away
isr_ip_udp_or_icmp:                                                             ; we have a UDP or ICMP packet
                       in       in0, ethernet_data                              ; skip header checksum
                       in       in0, ethernet_data                              ; skip header checksum (2)
                       load     in1, ethernet_data                              ; get ready to isr_copy (src)
                       load     in2, spram_isr_sender_ip_0                      ; get ready to isr_copy (dst)
                       load     in3, 0                                          ; prepare to isr_copy (src incr)
                       load     in4, 1                                          ; prepare to isr_copy (dst incr)
                       load     in0, 4                                          ; get ready to isr_copy (n)
                       call     isr_copy                                        ; copy data to scratchpad ram
                       call     isr_check_ip                                    ; check if it's for me (if NZ, no match)
                       jump     NZ, isr_dump_frame                              ; not for me, go away
isr_ip_for_me:                                                                  ; ICMP or UDP packet for me!
                       in       in0, ethernet_ctl                               ; check to see if it's completed
                       test     in0, ETHERNET_CTL_DONE_BIT                      ; check
                       jump     Z, isr_ip_for_me                                ; wait until it's done

                       out      in6, packet_data                                ; write protocol type into packet fifo
                       fetch    in6, isr_ip_length                              ; get length
                       out      in6, packet_data                                ; write length
                       load     in1, eframe_sender_mac                          ; get ready to isr_copy (src)
                       load     in2, packet_data                                ; get ready to isr_copy (dst)
                       load     in3, 1                                          ; get ready to isr_copy (src incr)
                       load     in4, 0                                          ; get ready to isr_copy (dst incr)
                       load     in0, 6                                          ; get ready to isr_copy (n)
                       call     isr_copy                                        ; copy 6 bytes from (eframe_sender_mac+5,eframe_sender_mac) to packet_data
                       load     in1, spram_isr_sender_ip_0                      ; get ready to isr_copy (src)
                       load     in2, packet_data                                ; get ready to isr_copy (dst)
                       load     in0, 4                                          ; get ready to isr_copy (n)
                       call     isr_copy                                        ; copy SPRAM to packet data (src incr, dst incr stayed the same), incrementing src
                       load     in1, ethernet_data                              ; get ready to isr_copy (src)
                       load     in2, packet_data                                ; get ready to isr_copy (dst)
                       load     in3, 0                                          ; get ready to isr_copy (src incr)
                       fetch    in0, isr_ip_length                              ; get ready to isr_copy (n)
                       call     isr_copy                                        ; copy to packet data (dst incr stayed the same): no src/dst increment
                       jump     isr_dump_frame                                  ; we're done
; isr_skip:
; in0: number of bytes to skip from ethernet_data (set this just before calling)
; in1: used as a temporary register
isr_skip:              in       in1, ethernet_data
                       sub      in0, 1
                       ret      Z
                       jump     isr_skip
; isr_copy: ludicrously slow, but useful
; in0: number of bytes to copy (set this just before calling)
; in1: source port
isr_copy:              in       in5, in1
                       out      in5, in2
                       add      in1, in3
                       add      in2, in4
                       sub      in0, 1
                       ret      Z
                       jump     isr_copy
isr_check_ip:          load     in2, 4
                       load     in1, ip
isr_check_ip_lp0:      in       in0, ethernet_data
                       in       in3, in1
                       comp     in0, in3
                       ret      NZ
                       sub      in2, 1
                       ret      Z
                       add      in1, 1
                       jump     isr_check_ip_lp0
isr_dump_frame:        load     in0, ETHERNET_CTL_DUMP
                       out      in0, ethernet_ctl
                       reti     enable                                          ; completely done
ORG $3FF
interrupt_vector:
                       jump     isr_frame
