AS="C:/cygwin/home/barawn/bin/pBlazASM.exe"
MG="C:/cygwin/home/barawn/bin/pBlazMRG.exe"

RM = rm -f -v
CP = cp

# List of PSM Files
ATRI_I2C = atrii2c_rom
ATRI_I2C_ASM_SRC = atri_i2c_v1.asm scratchpad_v4.asm
ATRI_I2C_AFLAGS = -3 -l -m$(ATRI_I2C)
MGFLAGS = -v

ATRI_READOUT = atrireadout_rom
ATRI_READOUT_ASM_SRC = pb_event_control.psm
ATRI_READOUT_AFLAGS = -3 -l -m$(ATRI_READOUT)
TEMPLATE = ROM_blank
.SUFFIXES : .psm .mem .vhd .psh

ATRI_SAMPLEMON = atrisamplemon_rom
ATRI_SAMPLEMON_ASM_SRC = pb_sample_mon.psm
ATRI_SAMPLEMON_AFLAGS = -3 -l -m$(ATRI_SAMPLEMON)

# assemble and merge
all: $(ATRI_I2C).vh $(ATRI_READOUT).vh $(ATRI_SAMPLEMON).vh

$(ATRI_SAMPLEMON).mem: $(ATRI_SAMPLEMON_ASM_SRC)
	$(AS) $(ATRI_SAMPLEMON_ASM_SRC) $(ATRI_SAMPLEMON_AFLAGS)

$(ATRI_SAMPLEMON).vh: $(ATRI_SAMPLEMON).mem $(TEMPLATE).v
	$(MG) $(MGFLAGS) -e$(ATRI_SAMPLEMON) -c$(ATRI_SAMPLEMON).mem -t$(TEMPLATE).v $(ATRI_SAMPLEMON).vh

$(ATRI_READOUT).mem: $(ATRI_READOUT_ASM_SRC)
	$(AS) $(ATRI_READOUT_ASM_SRC) $(ATRI_READOUT_AFLAGS)

$(ATRI_READOUT).vh: $(ATRI_READOUT).mem $(TEMPLATE).v
	$(MG) $(MGFLAGS) -e$(ATRI_READOUT) -c$(ATRI_READOUT).mem -t$(TEMPLATE).v $(ATRI_READOUT).vh

$(ATRI_I2C).mem: $(ATRI_I2C_ASM_SRC)
	$(AS) $(ATRI_I2C_ASM_SRC) $(ATRI_I2C_AFLAGS)

$(ATRI_I2C).vh: $(ATRI_I2C).mem $(TEMPLATE).v
	$(MG) $(MGFLAGS) -e$(ATRI_I2C) -c$(ATRI_I2C).mem -t$(TEMPLATE).v $(ATRI_I2C).vh

# clean outputs
clean:
	$(RM) $(ATRI_I2C).lst $(ATRI_I2C).mem $(ATRI_I2C).vh
	$(RM) $(ATRI_READOUT).lst $(ATRI_READOUT).mem $(ATRI_READOUT).vh
	$(RM) $(ATRI_SAMPLEMON).lst $(ATRI_SAMPLEMON).mem $(ATRI_SAMPLEMON).vh