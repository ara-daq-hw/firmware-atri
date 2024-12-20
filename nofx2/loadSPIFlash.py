#!/usr/bin/env python3

# update, let's take parameters, sigh.
import argparse
from atrispi import atrispi
from spiflash import SPIFlash

parser = argparse.ArgumentParser(prog="loadSPIFlash.py",
                                 description="Program a new bit of firmware")
parser.add_argument('filename', help='MCS file to program')
args = parser.parse_args()

fn = args.filename
print("Gonna program", fn)
yep = input("This is your last chance, enter yep to proceed: ")
if yep != 'yep':
    print("Aborting")
    exit(1)

# Initialize the SPI Flash interface through atrispi
spi = SPIFlash(atrispi())

# Program the SPI Flash with the specified .mcs file
spi.program_mcs(fn)
