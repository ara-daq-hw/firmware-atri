#!/bin/bash

# Check if we are in bootloader mode
if [ -e /dev/xillybus_spi_in ]; then
    echo "Not in bootloader mode. Please reboot to bootloader mode first by running 'bash toBootloader.sh'."
    exit 1
fi

# Run the Python script to load new firmware onto the SPI Flash
python3 /home/ara/loadSPIFlash.py $1
