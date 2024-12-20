#!/bin/bash

# Check if /dev/xillybus_spi_in exists
if [ -e /dev/xillybus_spi_in ]; then
    echo "/dev/xillybus_spi_in exists. Nothing to do."
    exit 0
fi

# Reboot using the reboot.py script to address 0x0
python3 reboot.py 0x0

# Unload the xillybus PCIe module
sudo rmmod xillybus_pcie

# Reboot the system
sudo reboot
