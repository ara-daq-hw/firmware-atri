.SCR 0x380
scr1l1		.TXT	"MAC Address"	; length 12
fil1l1		.BUF	4		; 16-12 = 4
scr1l2		.BUF	16		; length 16 - no filler
scr2l1		.TXT	"IP Address"	; length 11
fil2l1		.BUF	5		; 16-11 = 5
fil2l2p1	.BUF	3		; length 3
scr2l2p1	.TXT	"."		; length 2
fil2l2p2	.BUF	2		; length 2
scr2l2p2	.TXT	"."		; length 2
fil2l2p3	.BUF	2		; length 2
scr2l2p3	.TXT	"."		; length 2
fil2l2p4	.BUF	3		; 3+2+2+2+2+2=13,16-13=3
scr3l1		.TXT	"DDA Present: "	; length 14
fil3l1		.BUF	2		; 16-14 = 2
scr3l2		.TXT	"DDA Powered: " ; length 14
fil3l2		.BUF	2		; 16-14 = 2
scr4l1p1	.TXT	"DDA V: "	; length 8
scr4l1p2	.TXT	"."		; length 2
fil4l1p1	.BUF	1		; length 1
scr4l1p3	.TXT	" V"		; length 3
fil4l1p2	.BUF	2		; 8+2+1+3=14, 16-14 = 2
scr4l2p1	.TXT	"DDA I: "	; length 8
fil4l2p1	.BUF	2		; length 2
scr4l2p2	.TXT	" mA"		; length 4
fil4l2p2	.BUF	2		; 8+2+4=14, 16-14 = 2
scr5l1p1	.TXT	"DDA T: "	; length 8
fil5l1p1	.BUF	3		; length 3
scr5l1p2	.TXT	" C"		; length 3
fil5l1p2	.BUF	2		; 8+3+3=14, 16-14 = 2
scr5l2p1	.TXT	"DDA Devices: " ; length 14
fil5l2p1	.BUF	2		; 16-14 = 2
scr6l1p1	.TXT	"Connected: "	; length 12
fil6l1p1	.BUF	4		; 16-12 = 4
scr6l2p1	.TXT	"Packets: "	; length 10
fil6l2p1	.BUF	6		; 16-10 = 6
scr7l1p1	.TXT	"PC IP Address" ; length 14
fil7l1p1	.BUF	2		; 16-14 = 2
fil7l2p1	.BUF	3		; length 3
scr7l2p1	.TXT	"."		; length 2
fil7l2p2	.BUF	2		; length 2
scr7l2p2	.TXT	"."		; length 2
fil7l2p3	.BUF	2		; length 2
scr7l2p3	.TXT	"."		; length 2
fil7l2p4	.BUF	3		; 3+2+2+2+2+2=13,16-13=3