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
sudo apt upgrade -y

# install packages
sudo apt install unclutter -y

# we are done
sudo shutdown -h "now"
