#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
#  Version 2 - Online version
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

# configuration parameters
WT_HEIGHT=17
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
  "C1"  "Cameras over sheets 1 & 2"     \
  "C2"  "Cameras over sheets 3 & 4"     \
  "C3"  "Cameras over sheets 5 & 6"     \
  "C4"  "Cameras over sheets 7 & 8"     \
  "C5"  "Cameras over sheets 9 & 10"    \
  "C6"  "Cameras over sheets 11 & 12"   \
  "K1"  "Kiosk Upstairs"                \
  "K2"  "Kiosk Downstairs"              \
  "U1"  "Upgrade the Kiosk Application" \
  "U2"  "Upgrade the Rapsberry Pi OS"   \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    # menu item was selected
    whiptail --yesno "Are you sure?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      case $FUN in
          U1)
            # upgrade service
            if [ is_debug ]; then echo "upgrade service"; else wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh /home/kcckiosk/kiosk.run.sh; fi ;;

          U2)
            # upgrade OS
            if [ is_debug ]; then echo "apt update";  else sudo apt update; fi
            if [ is_debug ]; then echo "apt upgrade"; else sudo sudo apt upgrade -y; fi
            ;;

          *)
            # do camera or kiosk
            echo "$FUN" > kiosk.config
            echo "$FUN"
            ;;
      esac
      if [ is_debug ]; then echo "sync";    else sync;   fi
      if [ is_debug ]; then echo "reboot";  else reboot; fi
      exit 1
    fi
  else
    # quit was selected
    whiptail --yesno "Are you sure you want to quit?" 20 60 2
    if [ $? -eq 0 ]; then exit 1; fi
  fi
done
