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
sudo apt clean
sudo apt autoremove -y
sudo apt update
sudo apt upgrade -y

# install packages
sudo apt install unclutter

# get kiosk files
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service

# create startup service
sudo ln -s /home/kcckiosk/kiosk.service /lib/systemd/system/kiosk.service

# enable the kiosk service
sudo systemctl enable kiosk.service

# make kiosk.sh executable
chmod u+x /home/kcckiosk/kiosk.run.sh

# move taskbar to bottom
echo "position=bottom" >> .config/wf-panel-pi.ini

# autorun the kiosk configuration on login
# echo "sudo /home/kcckiosk/kiosk.sh" >> .bashrc
echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' >> .bashrc

# we are done
sudo reboot
