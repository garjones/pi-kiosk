#!/bin/bash
# --------------------------------------------------------------------------------
#  menutest.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Configuration Script. Allows operator to configure actions of Pi
#  
#  Version 4 - Modularized and added submenus
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# configuration parameters
WT_TITLE="Kelowna Curling Club Kiosk Management v4"
WT_COPYRIGHT="(c) Gareth Jones - gareth@gareth.com"
WT_HEIGHT=10
WT_WIDTH=80
WT_MENU_HEIGHT=$((WT_HEIGHT - 7))


# --------------------------------------------------------------------------------
# menus
# --------------------------------------------------------------------------------
do_menu_main() {
  # display main menu
  while true; do
    # display menu
    FUN=$(whiptail --title "$WT_TITLE" --backtitle "$WT_COPYRIGHT" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Quit --ok-button Select \
    "P1" "Display Cameras"        \
    "P2" "Display Kiosk"          \
    "P3" "Change Screen Rotation" \
    3>&1 1>&2 2>&3)
    RET=$?

    # process response
    if [ $RET -eq 0 ]; then
      # menu item was selected
      case "$FUN" in
        P1) do_menu_cameras ;;
        P2) do_menu_kiosks;;
        P3) do_menu_screen ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    else
      # quit was selected
      whiptail --yesno "Are you sure you want to quit?" 20 60 2
      if [ $? -eq 0 ]; then exit 1; fi
    fi
  done
}


do_menu_cameras() {
  # display menu
  FUN=$(whiptail --title "$WT_TITLE" --backtitle "$WT_COPYRIGHT" --menu "Canera Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Back --ok-button Select \
  "C01" "Cameras over sheets 1 & 2"     \
  "C03" "Cameras over sheets 3 & 4"     \
  "C05" "Cameras over sheets 5 & 6"     \
  "C07" "Cameras over sheets 7 & 8"     \
  "C09" "Cameras over sheets 9 & 10"    \
  "C11" "Cameras over sheets 11 & 12"   \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    do_write_config
  else
    return 0
  fi
}


do_menu_kiosks() {
  # display menu
  FUN=$(whiptail --title "$WT_TITLE" --backtitle "$WT_COPYRIGHT" --menu "Kiosk Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Back --ok-button Select \
  "K01" "Kiosk Upstairs"   \
  "K02" "Kiosk Downstairs" \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    do_write_config
  else
    return 0
  fi
}


do_menu_screen() {
  # display menu
  FUN=$(whiptail --title "$WT_TITLE" --backtitle "$WT_COPYRIGHT" --menu "Screen Rotation" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT  --cancel-button Back --ok-button Select \
  "H" "Screen is Horizontal" \
  "V" "Screen is Vertical"   \
  3>&1 1>&2 2>&3)
  RET=$?

  # process response
  if [ $RET -eq 0 ]; then
    do_screen_rotation
  else
    return 0
  fi
}

# --------------------------------------------------------------------------------
#  functions for install
# --------------------------------------------------------------------------------

# autoupgrade
do_auto_upgrade() {
  sudo apt autoremove -y
  sudo apt update
  sudo apt upgrade -y
}

# install packages
do_install_packages() (
  sudo apt install unclutter -y
)

# autoupdate
do_auto_update() {
  wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service   -O /home/kcckiosk/kiosk.service
  wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh    -O /home/kcckiosk/kiosk.run.sh
  wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-h.png  -O /home/kcckiosk/label-bg-h.png
  wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/label-bg-v.png  -O /home/kcckiosk/label-bg-v.png
}

# create/enable service
do_create_service() {
  # make kiosk.run.sh executable
  chmod u+x /home/kcckiosk/kiosk.run.sh

  # create service
  sudo ln -s /home/kcckiosk/kiosk.service /lib/systemd/system/kiosk.service

  # enable the kiosk service
  sudo systemctl enable kiosk.service
}

# move the taskbar to the bottom
do_position_taskbar() {
  if grep -Fxq "position=bottom" .config/wf-panel-pi.ini; then
      # already exists do nothing
      echo "[Skipped] Taskbar set to bottom"
  else
      # move taskbar to bottom
      echo "[Done] Taskbar set to bottom"
      echo "position=bottom" >> .config/wf-panel-pi.ini
  fi
}

# autorun the kiosk configuration on login
do_set_autorun() {
  if grep -Fxq 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' .bashrc; then
      # already exists do nothing
      echo "[Skipped] Kiosk configuration autorun"
  else
      # move taskbar to bottom
      echo "[Done] Kiosk configuration autorun"
      echo 'sudo /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"' >> .bashrc
  fi
}


# --------------------------------------------------------------------------------
#  functions for actions
# --------------------------------------------------------------------------------
do_write_config() {
    # check if sure, then write it out and reboot
    whiptail --yesno "Are you sure?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      echo "$FUN$ROTATION" > kiosk.config
      echo "$FUN$ROTATION"
      sudo sync
      sudo reboot
    fi
}

do_screen_rotation() {
    if [ "$FUN"="H" ]; then 
      # horizontal rotation
      ROTATION="H"
      wlr-randr --output HDMI-A-1 --transform normal
      wlr-randr --output HDMI-A-2 --transform normal
      echo "HORIZONTAL"
    else
      # vertical rotation
      ROTATION="V"
      wlr-randr --output HDMI-A-1 --transform 90
      wlr-randr --output HDMI-A-2 --transform 90
      echo "VERTICAL"
    fi
    echo $ROTATION
}

# --------------------------------------------------------------------------------
#  execute
# --------------------------------------------------------------------------------
do_auto_upgrade
do_install_packages
do_auto_update
do_create_service
do_position_taskbar
do_set_autorun
do_menu_main
