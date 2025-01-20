#!/bin/bash
# --------------------------------------------------------------------------------
#  kiosk.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
#  
#  Version 3.1 remove debug code
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# configuration parameters
WT_HEIGHT=18
WT_WIDTH=80
WT_MENU_HEIGHT=$((WT_HEIGHT - 7))

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
if grep -Fxq 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' .bashrc; then
    # already exists do nothing
    echo "[Skipped] Kiosk configuration autorun"
else
    # move taskbar to bottom
    echo "[Done] Kiosk configuration autorun"
    echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' >> .bashrc
fi

# get the current config
#  check if we are on a pi and set the home path
if [ -d "/home/kcckiosk/" ]; then
  KCC_KIOSKCONFIG=$(cat /home/kcckiosk/kiosk.config)
else
  KCC_KIOSKCONFIG=$(cat kiosk.config)
fi

# get config & index & rotation
KCC_CONFIG=${KCC_KIOSKCONFIG:0:3}
KCC_ROTATION=${KCC_KIOSKCONFIG:3:1}

# display main menu
while true; do
  # display menu
  FUN=$(whiptail --title "Kelowna Curling Club Kiosk Management v3" --backtitle "(c) Gareth Jones - gareth@gareth.com" --default-item $KCC_CONFIG --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Quit --ok-button Select \
  "C01" "Cameras over sheets 1 & 2"     \
  "C03" "Cameras over sheets 3 & 4"     \
  "C05" "Cameras over sheets 5 & 6"     \
  "C07" "Cameras over sheets 7 & 8"     \
  "C09" "Cameras over sheets 9 & 10"    \
  "C11" "Cameras over sheets 11 & 12"   \
  "K01" "Kiosk Upstairs"                \
  "K02" "Kiosk Downstairs"              \
  "S01" "Screen is Horizontal"          \
  "S02" "Screen is Vertical"            \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    # menu item was selected
    case $FUN in
        S01)
          # horizontal rotation
          KCC_ROTATION="H"
          /bin/bash -c "wlr-randr --output HDMI-A-1 --mode 1920x1080@60Hz --transform normal"
          /bin/bash -c "wlr-randr --output HDMI-A-2 --mode 1920x1080@60Hz --transform normal"
          ;;
        S02)
          # vertical rotation
          KCC_ROTATION="V"
          /bin/bash -c "wlr-randr --output HDMI-A-1 --mode 1920x1080@60Hz --transform 90"
          /bin/bash -c "wlr-randr --output HDMI-A-2 --mode 1920x1080@60Hz --transform 90"
          ;;
        *)
          # check if sure, then write it out and reboot
          whiptail --yesno "Are you sure?" 20 60 2
          if [ $? -eq 0 ]; then # yes
            echo "$FUN$KCC_ROTATION" > kiosk.config
            echo "$FUN$KCC_ROTATION"
            sudo sync
            sudo reboot
          fi
          ;;
    esac  
  else
    # quit was selected
    whiptail --yesno "Are you sure you want to quit?" 20 60 2
    if [ $? -eq 0 ]; then exit 1; fi
  fi
done

wlr-randr --output HDMI-A-1 --transform 90
wlr-randr --output HDMI-A-2 --transform 90


