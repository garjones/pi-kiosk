#!/bin/bash
echo "Raspberry PI Initial Configuration"
echo

# via ssh
sudo apt update
sudo apt upgrade
sudo apt install git

# install the X Window System (X11)
sudo apt install --no-install-recommends xserver-xorg
sudo apt install --no-install-recommends xinit
sudo apt install --no-install-recommends x11-xserver-utils

# install Chromium and kiosk dependencies
sudo apt install chromium-browser
sudo apt install matchbox-window-manager xautomation unclutter
sudo apt install fonts-noto-color-emoji

# create the kiosk startup script
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk

# add the kiosk script to .bashrc
echo "xinit /home/pi/kiosk -- vt$(fgconsole)" >> ~/.bashrc

#####
#	 Option	Action(s)
# 1	 System Options	S5 Boot / Auto Login
#    [B2 Console Autologin]
