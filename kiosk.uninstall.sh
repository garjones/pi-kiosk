#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.uninstall.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Uninstallation script
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# disable the kiosk service
sudo systemctl disable kiosk.service

# remove  service
sudo rm /lib/systemd/system/kiosk.service

# remove kiosk files
sudo rm /home/kcckiosk/main/kiosk.*

# remove autorun from .bashrc
# echo "sudo /home/kcckiosk/kiosk.sh" >> .bashrc
# echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk2.sh)"' >> .bashrc

# we are done
sudo reboot
