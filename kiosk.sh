#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# configuration parameters
WT_HEIGHT=23
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

# display main menu
while true; do
  # display menu
  FUN=$(whiptail --title "Kelown Curling Club Kiosk Management" --backtitle "(c) Gareth Jones - gareth@gareth.com" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Quit --ok-button Select \
  "C1"  "Display Cameras over sheets 1 & 2"   \
  "C2"  "Display Cameras over sheets 3 & 4"   \
  "C3"  "Display Cameras over sheets 5 & 6"   \
  "C4"  "Display Cameras over sheets 7 & 8"   \
  "C5"  "Display Cameras over sheets 9 & 10"  \
  "C6"  "Display Cameras over sheets 11 & 12" \
  "K1"  "Display Kiosk Upstairs"              \
  "K2"  "Display Kiosk Downstairs"            \
  "U1"  "Update the Kiosk Application"        \  
  "U2"  "Upgrade the Rapsberry Pi OS"         \
  
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    whiptail --yesno "Are you sure?" 20 60 2
    if [ $? -eq 0 ]; then # yes
    case $kiosk in
      U1)
        # do update
        if is_debug ; then
          echo "update"
          exit 1
        else
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/update.sh)"
          exit 1
        fi
        ;;
  
      U2)
        # do upgrade
        if is_debug ; then
          echo "upgrade"
          exit 1
        else
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/upgrade.sh)"
          exit 1
        fi
        ;;
      *)
        # do camera or kiosk
        if is_debug ; then
          echo "$FUN" > kiosk.config 
          echo "$FUN"
          echo "sync"
          echo "reboot"
          exit 1
        else
          echo "$FUN" > kiosk.config 
          sync
          reboot
          exit 1
        fi
        ;;
      esac
    fi
  else
    whiptail --yesno "Are you sure you want to quit?" 20 60 2
    exit 1
  fi
  done
