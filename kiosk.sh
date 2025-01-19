#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
#  
#  Version 3.0 Added autoinstall
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# configuration parameters
WT_HEIGHT=18
WT_WIDTH=80
WT_MENU_HEIGHT=$((WT_HEIGHT - 7))
DEBUG=FALSE

# check for debug mode
is_debug () {
  if [ "$DEBUG" = TRUE ]; then
    return 0
  else
    return 1
  fi
}

# autoupgrade
sudo apt autoremove -y
sudo apt update
sudo apt upgrade -y

# install packages
sudo apt install unclutter -y

# autoupdate
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service   -O /home/kcckiosk/kiosk.service
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh    -O /home/kcckiosk/kiosk.run.sh
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-h.png  -O /home/kcckiosk/label-bg-h.png
wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-v.png  -O /home/kcckiosk/label-bg-v.png

# make kiosk.run.sh executable
chmod u+x /home/kcckiosk/kiosk.run.sh

# create service
sudo ln -s /home/kcckiosk/kiosk.service /lib/systemd/system/kiosk.service

# enable the kiosk service
sudo systemctl enable kiosk.service


# move the taskbar to the bottom
if grep -Fxq "position=bottom" .config/wf-panel-pi.ini; then
    # already exists do nothing
    echo "[Skipped] Taskbar set to bottom"
else
    # move taskbar to bottom
    echo "[Done] Taskbar set to bottom"
    echo "position=bottom" >> .config/wf-panel-pi.ini
fi

# autorun the kiosk configuration on login
if grep -Fxq "https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh" .bashrc; then
    # already exists do nothing
    echo "[Skipped] Kiosk configuration autorun"
else
    # move taskbar to bottom
    echo "[Done] Kiosk configuration autorun"
    echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' >> .bashrc
fi

# display main menu
while true; do
  # display menu
  FUN=$(whiptail --title "Kelowna Curling Club Kiosk Management v2" --backtitle "(c) Gareth Jones - gareth@gareth.com" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Quit --ok-button Select \
  "C1"  "Cameras over sheets 1 & 2"     \
  "C3"  "Cameras over sheets 3 & 4"     \
  "C5"  "Cameras over sheets 5 & 6"     \
  "C7"  "Cameras over sheets 7 & 8"     \
  "C9"  "Cameras over sheets 9 & 10"    \
  "C11" "Cameras over sheets 11 & 12"   \
  "K1"  "Kiosk Upstairs"                \
  "K2"  "Kiosk Downstairs"              \
  "S1"  "Screen is Horizontal"          \
  "S2"  "Screen is Vertical"            \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    # menu item was selected
    whiptail --yesno "Are you sure?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      case $FUN in
          S1)
            # horizontal rotation
            echo "H" > kiosk.rotation
            echo "H"
            return
            ;;

          S2)
            # vertical rotation
            echo "V" > kiosk.rotation
            echo "V"
            return
            ;;

          *)
            # do camera or kiosk
            echo "$FUN" > kiosk.config
            echo "$FUN"
            ;;
      esac
      if is_debug; then echo "sync";    else sudo sync;   fi
      if is_debug; then echo "reboot";  else sudo reboot; fi
      exit 1
    fi
  else
    # quit was selected
    whiptail --yesno "Are you sure you want to quit?" 20 60 2
    if [ $? -eq 0 ]; then exit 1; fi
  fi
done
