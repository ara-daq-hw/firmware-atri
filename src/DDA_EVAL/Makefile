AS="C:/cygwin/home/barawn/bin/pBlazASM.exe"
MG="C:/cygwin/home/barawn/bin/pBlazMRG.exe"

RM = rm -f -v
CP = cp

# List of PSM Files
ENETPV2 = enetpacketv2_rom
ENETPV2_ASM_SRC = ethernet_packet_v2.asm scratchpad_ethv3.asm
ENETPV2_AFLAGS = -l -m$(ENETPV2)
MGFLAGS = -v

TEMPLATE = ROM_blank
.SUFFIXES : .psm .mem .vhd .psh

# assemble and merge
all: $(ENETPV2).vh

$(ENETPV2).mem:	$(ENETPV2_ASM_SRC)
	$(AS)	$(ENETPV2_ASM_SRC) $(ENETPV2_AFLAGS)

$(ENETPV2).vh: $(ENETPV2).mem $(TEMPLATE).v
	$(MG) $(MGFLAGS) -e$(ENETPV2) $(ENETPV2).mem $(TEMPLATE).v $(ENETPV2).vh

# clean outputs
clean:
	$(RM) *.mem *.lst $(ENETPV2).vh