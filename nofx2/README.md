# ATRI NOFX2 DETAILS

# SPI Flash (PROM)

The SPI Flash device is 128 Mbit (16 Mbyte) in size, so it has
addresses from 0x00_0000 to 0xFF_FFFF.

# Bootloader

The bootloader occupies SPI address 0x00_0000 - 0x20_0000.
You boot to it by /home/ara/reboot.py 0x0 (then rmmod xillybus_pcie,
reboot).

# Operating Firmware

The first operating firmware image starts at 0x20_0000.

# Generating MCS in iMPACT

Create a MultiBoot FPGA file with size 128M (it wants it in bits)
for a Spartan-6 with 2 revisions. There's no way to generate an offset,
so Python's going to rip apart the MCS file later.

When it asks for a file for revision 0 add atri_bootload_nodbg.bit.

Start address for revision 1 should be 200000. (20, followed by 4 zeroes).
Then add the bitfile. Yes, finished adding files. Then generate.

Next you need to trim the MCS file. You want to find the line
```
:020000040020DA
```
This is an "Extended Linear Address" marker which jumps the top 16 bits
of the address up to "0020" (0x0020) which is of course the start of
the new file.

