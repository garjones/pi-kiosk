#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.install2.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Installation script version 2 - Online only
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# remove unnecessary packages and update
sudo apt clean
sudo apt autoremove -y
sudo apt update
sudo apt upgrade -y

# install packages
sudo apt install unclutter sed wget

# get kiosk files
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk2.service /lib/systemd/system/kiosk2.service

# enable the kiosk service
sudo systemctl enable kiosk.service

# move taskbar to bottom
echo "position=bottom" >> .config/wf-panel-pi.ini

# autorun the kiosk configuration on login
echo "sudo /home/kcckiosk/kiosk.sh" >> .bashrc

# we are done
sudo reboot
 
