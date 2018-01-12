.SCR 0x380
arp_htype	.WBE	0x0001		; length 2
arp_ptype	.WBE	0x0800		; length 2
arp_hlen	.BYT	0x06		; length 1
arp_plen	.BYT	0x04		; length 1
arp_oper	.WBE	0x0002		; length 2
arp_filler	.BUF	24		; 2+2+1+1+2=8, 32-8 = 24
ident_string	.TXT	"PicoBlaze UDP v1.0 OK"
ident_filler	.BUF	11	;  32 - length of ident string
p2		.BUF	32
p3		.BUF	32
p4		.BUF	32
p5		.BUF	32
p6		.BUF	32
p7		.BUF	32		; length 32 - no filler
