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
sudo apt install unclutter sed wget

# get kiosk files
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service

# create startup service
sudo ln -s /home/kcckiosk/kiosk.service /lib/systemd/system/kiosk.service

# enable the kiosk service
sudo systemctl enable kiosk.service

# make kiosk.sh executable
chmod u+x /home/kcckiosk/kiosk.sh
chmod u+x /home/kcckiosk/kiosk.run.sh

# move taskbar to bottom
echo "position=bottom" >> .config/wf-panel-pi.ini

# autorun the kiosk configuration on login
echo "sudo /home/kcckiosk/kiosk.sh" >> .bashrc

# we are done
sudo reboot
 


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
sudo apt install unclutter -y

# get kiosk service
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk2.service /lib/systemd/system/kiosk.service

# enable the kiosk service
sudo systemctl enable kiosk.service

# move taskbar to bottom
echo "position=bottom" >> .config/wf-panel-pi.ini

# autorun the kiosk configuration on login
echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk2.sh)"' >> .bashrc

# we are done
sudo reboot


















