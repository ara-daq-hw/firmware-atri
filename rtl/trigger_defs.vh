`ifndef TRIGGER_DEFS_VH
`define TRIGGER_DEFS_VH

//////////////////////////////////
// Trigger Definitions Header   //
//////////////////////////////////

//////////////////////////////////
// Scaler Definitions           //
//////////////////////////////////

////
// NOTE NOTE NOTE
////
// These should not be changed unless needed
// (e.g. to increase the number). If these
// numbers are *decreased* the firmware will
// not compile without changing both WISHBONE
// modules
// If they are increased, the firmware will compile
// but the additional scalers need to be mapped in
// the WISHBONE scaler space and the trigger control space.
// -- wishbone_scaler_block   (v2 or later)
// -- wishbone_trigctrl_block

// Number of L1 triggers.
`define SCAL_NUM_L1 20
// Number of L2 triggers.
`define SCAL_NUM_L2 16
// Number of L3 triggers.
`define SCAL_NUM_L3 8
// Number of RF L4 triggers (i.e. number handled by rf_trigger_top).
`define SCAL_NUM_RF_L4 2
// Number of external L4 triggers (i.e. not RF)
`define SCAL_NUM_EXT_L4 3
// Number of L4 triggers.
`define SCAL_NUM_L4 ( `SCAL_NUM_RF_L4 + `SCAL_NUM_EXT_L4 )


//////////////////////////////////
// Trigger Definitions          //
//////////////////////////////////

// This is the 0.3 trigger: this uses the same logic as the 0.2 trigger,
// but now assumes that the triggers go VVHH VVHH VVHH VVHH.

// Trigger type. Values from 0-15.
`define TRIG_VER_TYPE 0
// Month of this implementation.
`define TRIG_VER_MONTH 12
// Day of this implementation
`define TRIG_VER_DAY 17
// Major # of this implementation.
`define TRIG_VER_MAJOR 0
// Minor # of this implementation.
`define TRIG_VER_MINOR 3
// Revision of this implementation.
`define TRIG_VER_REV 1

// Number of (48 MHz) clocks needed to complete a reset.
`define RESET_CYCLES 12


// Number of bits in the number of blocks field (i.e. 1-256 blocks).
`define NBLOCK_BITS 8
// Number of bits in the pretrigger blocks field (i.e. 0-16 pretrigger blocks).
// If this is increased, trigger_handling needs to be able to handle more delay.
`define PRETRG_BITS 4

// RF0 (deep ice)

// Read out 20 blocks by default. This number is number of blocks-1.
`define TRIG_RF0_NUM_BLOCKS 19
// Number of pretrigger blocks.
// There's a base offset of 8 blocks for all triggers. The current RF trigger only takes
// 3-4 cycles, or 1.5-2 blocks. If we want 10 pretrigger blocks, that means we only need
// this to be 4. (num_pretrig = ((trig_rf0_pretrigger) + base_offset - trigger delay))
// num_pretrig = 4+8-2 = 10
`define TRIG_RF0_PRETRIGGER 4
`define TRIG_RF0_DELAY 0

// RF1 (surface)

// Read out 20 blocks by default. This number is number of blocks-1.
`define TRIG_RF1_NUM_BLOCKS 19
// Number of pretrigger blocks. This is actually number of blocks to 'back up' from the trigger.
`define TRIG_RF1_PRETRIGGER 4
`define TRIG_RF1_DELAY 0

// CPU trigger
// The CPU pretrigger is kindof unimportant (it's random, after all) 
// Base offset is 8. The CPU delay of 8 clocks puts us right at trigger. Back up 2
// to frame it.
`define TRIG_CPU_NUM_BLOCKS 3
`define TRIG_CPU_PRETRIGGER 2
`define TRIG_CPU_DELAY 8

// Cal trigger
// Base offset is 8. The CAL delay of 8 clocks puts us right at trigger. Back up 5
// to frame it.
`define TRIG_CAL_NUM_BLOCKS 9
`define TRIG_CAL_PRETRIGGER 5
`define TRIG_CAL_DELAY 8

// Ext trigger.
// Base offset is 6. We have a 4-clock delay (2 blocks) after trigger received, so compensate here.
`define TRIG_EXT_NUM_BLOCKS 9
`define TRIG_EXT_PRETRIGGER 5
`define TRIG_EXT_DELAY 6

// If we want to delay the trigger, this is the only place to do it.

// ALL triggers, by default, are assumed predelayed by 8 blocks.
// If a trigger wishes to be closer to its 'actual' time, then add
// a delay specific for that trigger.
`define BASE_OFFSET	  8

// Number of bits in the delay field.
`define DELAY_BITS 4
// Number of bits in the info for each trigger.
`define INFO_BITS 32
// Number of bits in the trigger oneshot length.
`define TRIG_ONESHOT_BITS 5
`define L1_ONESHOT_DEFAULT 10

//FIXME: addition from Patrick's Patch: 4 lines
// Number of bits in the trigger delay value
`define TRIG_DELAY_VAL_BITS 5
// Default delay value (0).
`define TRIG_DELAY_DEFAULT {TRIG_DELAY_VAL_BITS{1'b0}}
 

// No masks by default.
`define L4_MASK_DEFAULT 5'b00000

`endif
