#!/bin/bash
# --------------------------------------------------------------------------------
#  upgrade.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Upgrade the Pi OS
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# remove unnecessary packages and update
sudo apt clean
sudo apt autoremove -y
sudo apt update
sudo apt upgrade

# install packages
sudo apt install unclutter sed wget

# we are done
sudo reboot
