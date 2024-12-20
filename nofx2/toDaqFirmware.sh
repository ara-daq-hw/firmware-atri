#!/bin/bash

#check if /dev/xillybus_spi_in exists
if [ ! -e /dev/xillybus_spi_in ]; then
    echo "/dev/xillybus_spi_in does not exist. Nothing to do."
    exit 0
fi

# Reboot using the reboot.py script to address 0x200000
python3 reboot.py 0x200000

# Unload the xillybus PCIe module
sudo rmmod xillybus_pcie

# Reboot the system
sudo reboot
