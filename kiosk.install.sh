#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.install.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Installation script
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# remove unnecessary packages and update
sudo apt purge wolfram-engine scratch scratch2 nuscratch sonic-pi idle3 -y
sudo apt purge smartsim java-common minecraft-pi libreoffice* -y
sudo apt clean
sudo apt autoremove -y
sudo apt update
sudo apt upgrade

# install packages
sudo apt install unclutter sed wget

# move taskbar to bottom
echo "position=bottom" >> .config/wf-panel-pi.ini

# get kiosk files
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service

# make kiosk.sh executable
chmod u+x ~/kiosk.sh
chmod u+x ~/kiosk.run.sh

# create startup service
sudo ln -s /home/kcckiosk/kiosk.service /lib/systemd/system/kiosk.service

# enable and start the service
sudo systemctl enable kiosk.service

# we are done
sudo reboot
