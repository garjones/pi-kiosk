#!/bin/bash
# --------------------------------------------------------------------------------
#  update.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Update kiosk application
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# get kiosk files
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service

# make kiosk.sh executable
chmod u+x /home/kcckiosk/kiosk.sh
chmod u+x /home/kcckiosk/kiosk.run.sh

# we are done
sudo reboot
 
