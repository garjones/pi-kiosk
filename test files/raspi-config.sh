#!/bin/sh
# Part of raspi-config https://github.com/RPi-Distro/raspi-config
#
# See LICENSE file for copyright and license details

INTERACTIVE=True
ASK_TO_REBOOT=0
BLACKLIST=/etc/modprobe.d/raspi-blacklist.conf

if [ -e /boot/firmware/config.txt ] ; then
  FIRMWARE=/firmware
else
  FIRMWARE=
fi
CONFIG=/boot${FIRMWARE}/config.txt

USER=${SUDO_USER:-$(who -m | awk '{ print $1 }')}
if [ -z "$USER" ] && [ -n "$HOME" ]; then
  USER=$(getent passwd | awk -F: "\$6 == \"$HOME\" {print \$1}")
fi
if [ -z "$USER" ] || [ "$USER" = "root" ]; then
  USER=$(getent passwd | awk -F: '$3 == "1000" {print $1}')
fi

INIT="$(ps --no-headers -o comm 1)"

HOMEDIR="$(getent passwd "$USER" | cut -d: -f6)"
WAYFIRE_FILE="$HOMEDIR/.config/wayfire.ini"
LABWCENV_FILE="$HOMEDIR/.config/labwc/environment"
LABWCAST_FILE="$HOMEDIR/.config/labwc/autostart"

is_pi () {
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "armhf" ] || [ "$ARCH" = "arm64" ] ; then
    return 0
  else
    return 1
  fi
}

is_64bit () {
  ARCH=$(dpkg --print-architecture)
  if [ "$ARCH" = "arm64" ] ; then
    return 0
  else
    return 1
  fi
}

if is_pi ; then
  if [ -e /proc/device-tree/chosen/os_prefix ]; then
    PREFIX="$(tr -d '\0' < /proc/device-tree/chosen/os_prefix)"
  fi
  CMDLINE="/boot${FIRMWARE}/${PREFIX}cmdline.txt"
else
  CMDLINE=/proc/cmdline
fi

# tests for Pi 1, 2 and 0 all test for specific boards...

is_pione() {
  if grep -q "^Revision\s*:\s*00[0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo; then
    return 0
  elif grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[0-36][0-9a-fA-F]$" /proc/cpuinfo ; then
    return 0
  else
    return 1
  fi
}

is_pitwo() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]04[0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

is_pizero() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]0[9cC][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

# ...while tests for Pi 3 and 4 just test processor type, so will also find CM3, CM4, Zero 2 etc.

is_pithree() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F]2[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

is_pifour() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F]3[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

is_pifive() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F]4[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

is_cmfive() {
  grep -q "^Revision\s*:\s*[ 123][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]1[8aA][0-9a-fA-F]$" /proc/cpuinfo
  return $?
}

get_pi_type() {
  if is_pione; then
    echo 1
  elif is_pitwo; then
    echo 2
  elif is_pithree; then
    echo 3
  elif is_pifour; then
    echo 4
  elif is_pifive; then
    echo 5
  elif is_pizero; then
    echo 0
  else
    echo -1
  fi
}

gpu_has_mmu() {
  if is_pifour || is_pifive ; then
    return 0
  else
    return 1
  fi
}

is_live() {
  grep -q "boot=live" $CMDLINE
  return $?
}

is_ssh() {
  if pstree -p | grep -qE ".*sshd.*\($$\)"; then
    return 0
  else
    return 1
  fi
}

is_kms() {
    return 0
}

is_pulseaudio() {
  pgrep pulseaudio > /dev/null || pgrep pipewire-pulse > /dev/null
  return $?
}

is_wayfire() {
  pgrep wayfire > /dev/null
  return $?
}

is_labwc() {
  pgrep labwc > /dev/null
  return $?
}

is_wayland() {
  if is_wayfire; then
    return 0
  elif is_labwc; then
    return 0
  else
    return 1
  fi
}

has_analog() {
  if [ $(get_leds) -eq -1 ] ; then
    return 0
  else
    return 1
  fi
}

is_installed() {
  if [ "$(dpkg -l "$1" 2> /dev/null | tail -n 1 | cut -d ' ' -f 1)" != "ii" ]; then
    return 1
  else
    return 0
  fi
}

deb_ver () {
  ver=$(cut -d . -f 1 < /etc/debian_version)
  echo $ver
}

get_package_version() {
  dpkg-query --showformat='${Version}' --show "$1"
}

can_configure() {
  if [ ! -e /etc/init.d/lightdm ]; then
    return 1
  fi
  if ! is_pi; then
    return 0
  fi
  if [ ! -e /boot${FIRMWARE}/start_x.elf ]; then
    return 1
  fi
  if [ -e $CONFIG ] && grep -q "^device_tree=$" $CONFIG; then
    return 1
  fi
  if ! mountpoint -q /boot${FIRMWARE}; then
    return 1
  fi
  if [ ! -e $CONFIG ]; then
    touch $CONFIG
  fi
  return 0
}

calc_wt_size() {
  # NOTE: it's tempting to redirect stderr to /dev/null, so supress error
  # output from tput. However in this case, tput detects neither stdout or
  # stderr is a tty and so only gives default 80, 24 values
  WT_HEIGHT=18
  WT_WIDTH=$(tput cols)

  if [ -z "$WT_WIDTH" ] || [ "$WT_WIDTH" -lt 60 ]; then
    WT_WIDTH=80
  fi
  if [ "$WT_WIDTH" -gt 178 ]; then
    WT_WIDTH=120
  fi
  WT_MENU_HEIGHT=$((WT_HEIGHT - 7))
}

do_about() {
  whiptail --msgbox "\
This tool provides a straightforward way of doing initial
configuration of the Raspberry Pi. Although it can be run
at any time, some of the options may have difficulties if
you have heavily customised your installation.

$(dpkg -s raspi-config 2> /dev/null | grep Version)\
" 20 70 1
  return 0
}

get_can_expand() {
  ROOT_PART="$(findmnt / -o source -n)"
  ROOT_DEV="/dev/$(lsblk -no pkname "$ROOT_PART")"

  PART_NUM="$(echo "$ROOT_PART" | grep -o "[[:digit:]]*$")"

  if [ "$PART_NUM" -ne 2 ]; then
    echo 1
    exit
  fi

  LAST_PART_NUM=$(parted "$ROOT_DEV" -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ "$LAST_PART_NUM" -ne "$PART_NUM" ]; then
    echo 1
    exit
  fi
  echo 0
}

do_expand_rootfs() {
  ROOT_PART="$(findmnt / -o source -n)"
  ROOT_DEV="/dev/$(lsblk -no pkname "$ROOT_PART")"

  PART_NUM="$(echo "$ROOT_PART" | grep -o "[[:digit:]]*$")"

  LAST_PART_NUM=$(parted "$ROOT_DEV" -ms unit s p | tail -n 1 | cut -f 1 -d:)
  if [ "$LAST_PART_NUM" -ne "$PART_NUM" ]; then
    whiptail --msgbox "$ROOT_PART is not the last partition. Don't know how to expand" 20 60 2
    return 0
  fi

  # Get the starting offset of the root partition
  PART_START=$(parted "$ROOT_DEV" -ms unit s p | grep "^${PART_NUM}" | cut -f 2 -d: | sed 's/[^0-9]//g')
  [ "$PART_START" ] || return 1
  # Return value will likely be error for fdisk as it fails to reload the
  # partition table because the root fs is mounted
  fdisk "$ROOT_DEV" <<EOF
p
d
$PART_NUM
n
p
$PART_NUM
$PART_START

p
w
EOF
  ASK_TO_REBOOT=1

  # now set up an init.d script
cat <<EOF > /etc/init.d/resize2fs_once &&
#!/bin/sh
### BEGIN INIT INFO
# Provides:          resize2fs_once
# Required-Start:
# Required-Stop:
# Default-Start: 3
# Default-Stop:
# Short-Description: Resize the root filesystem to fill partition
# Description:
### END INIT INFO

. /lib/lsb/init-functions

case "\$1" in
  start)
    log_daemon_msg "Starting resize2fs_once" &&
    resize2fs "$ROOT_PART" &&
    update-rc.d resize2fs_once remove &&
    rm /etc/init.d/resize2fs_once &&
    log_end_msg \$?
    ;;
  *)
    echo "Usage: \$0 start" >&2
    exit 3
    ;;
esac
EOF
  chmod +x /etc/init.d/resize2fs_once &&
  update-rc.d resize2fs_once defaults &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Root partition has been resized.\nThe filesystem will be enlarged upon the next reboot" 20 60 2
  fi
}

set_config_var() {
  lua - "$1" "$2" "$3" <<EOF > "$3.bak"
local key=assert(arg[1])
local value=assert(arg[2])
local fn=assert(arg[3])
local file=assert(io.open(fn))
local made_change=false
for line in file:lines() do
  if line:match("^#?%s*"..key.."=.*$") then
    line=key.."="..value
    made_change=true
  end
  print(line)
end

if not made_change then
  print(key.."="..value)
end
EOF
mv "$3.bak" "$3"
}

clear_config_var() {
  lua - "$1" "$2" <<EOF > "$2.bak"
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
for line in file:lines() do
  if line:match("^%s*"..key.."=.*$") then
    line="#"..line
  end
  print(line)
end
EOF
mv "$2.bak" "$2"
}

get_config_var() {
  lua - "$1" "$2" <<EOF
local key=assert(arg[1])
local fn=assert(arg[2])
local file=assert(io.open(fn))
local found=false
for line in file:lines() do
  local val = line:match("^%s*"..key.."=(.*)$")
  if (val ~= nil) then
    print(val)
    found=true
    break
  end
end
if not found then
   print(0)
end
EOF
}

get_overscan() {
  OVS=$(get_config_var disable_overscan $CONFIG)
  if [ $OVS -eq 1 ]; then
    echo 1
  else
    echo 0
  fi
}

do_overscan() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_overscan) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable compensation for displays with overscan?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ] ; then
    set_config_var disable_overscan 0 $CONFIG
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^overscan_/#overscan_/"
    set_config_var disable_overscan 1 $CONFIG
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Display overscan compensation is $STATUS" 20 60 1
  fi
}

get_overscan_kms() {
  RES=$(grep "HDMI-$1" /usr/share/ovscsetup.sh 2> /dev/null | grep margin | rev | cut -d ' ' -f 1 | rev)
  if [ -z $RES ] ; then
    echo 1
  elif [ $RES -eq 0 ] ; then
    echo 1
  else
    echo 0
  fi
}

do_overscan_kms() {
  if [ "$INTERACTIVE" = True ]; then
    NDEVS=$(xrandr -q | grep -c connected)
    if [ $NDEVS -gt 1 ] ; then
      DEV=$(whiptail --menu "Select the output for which overscan compensation is to be set" 20 60 10 "1" "HDMI-1" "2" "HDMI-2" 3>&1 1>&2 2>&3)
      if [ $? -eq 1 ] ; then
        return
      fi
    else
      DEV=1
    fi
    if [ $(get_overscan_kms $DEV) -eq 1 ]; then
      DEFAULT=--defaultno
    else
      DEFAULT=
    fi
    if whiptail --yesno "Would you like to enable overscan compensation for HDMI-$DEV?" $DEFAULT 20 60 2 ; then
      PIX=16
      STATUS="enabled"
    else
      PIX=0
      STATUS="disabled"
    fi
  else
    DEV=$1
    if [ $2 -eq 1 ] ; then
      PIX=0
    else
      PIX=16
    fi
  fi
  xrandr --output HDMI-$DEV --set "left margin" $PIX --set "right margin" $PIX --set "top margin" $PIX --set "bottom margin" $PIX
  # hack to force reload when not using mutter
  if ! pgrep mutter > /dev/null ; then
    xrandr --output HDMI-$DEV --reflect x
    xrandr --output HDMI-$DEV --reflect normal
  fi
  sed $CONFIG -i -e "s/^overscan_/#overscan_/"
  set_config_var disable_overscan 1 $CONFIG
  if [ -e /usr/share/ovscsetup.sh ] ; then
    if grep "HDMI-$DEV" /usr/share/ovscsetup.sh 2> /dev/null | grep -q margin ; then
      sed /usr/share/ovscsetup.sh -i -e "s/xrandr --output HDMI-$DEV.*margin.*/xrandr --output HDMI-$DEV --set \"left margin\" $PIX --set \"right margin\" $PIX --set \"top margin\" $PIX --set \"bottom margin\" $PIX/"
    else
      echo "xrandr --output HDMI-$DEV --set \"left margin\" $PIX --set \"right margin\" $PIX --set \"top margin\" $PIX --set \"bottom margin\" $PIX" >> /usr/share/ovscsetup.sh
    fi
  else
    echo "#!/bin/sh" > /usr/share/ovscsetup.sh
    echo "xrandr --output HDMI-$DEV --set \"left margin\" $PIX --set \"right margin\" $PIX --set \"top margin\" $PIX --set \"bottom margin\" $PIX" >> /usr/share/ovscsetup.sh
  fi
  if ! grep -q ovscsetup /usr/share/dispsetup.sh 2> /dev/null ; then
    sed /usr/share/dispsetup.sh -i -e "s#exit#if [ -e /usr/share/ovscsetup.sh ] ; then\n. /usr/share/ovscsetup.sh\nfi\nexit#"
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Display overscan compensation for HDMI-$DEV is $STATUS" 20 60 1
  fi
}

get_blanking() {
  if is_wayfire; then
    if ! grep -q dpms_timeout $WAYFIRE_FILE ; then
      echo 1
    elif ! grep -q "dpms_timeout.*-1" $WAYFIRE_FILE ; then
      echo 0
    else
      echo 1
    fi
  elif is_labwc; then
    if [ -e $LABWCAST_FILE ] && grep -q swayidle $LABWCAST_FILE ; then
      echo 0
    else
      echo 1
    fi
  else
    if ! [ -f "/etc/X11/xorg.conf.d/10-blanking.conf" ]; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_blanking() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ "$(get_blanking)" -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if is_wayfire; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "Would you like to enable screen blanking?" $DEFAULT 20 60 2
      RET=$?
    else
      RET=$1
    fi
    if [ "$RET" -eq 0 ] ; then
      if grep -q dpms_timeout $WAYFIRE_FILE ; then
        sed -i 's/dpms_timeout.*/dpms_timeout=600/' $WAYFIRE_FILE
      else
        if grep -q "\[idle\]" $WAYFIRE_FILE ; then
          sed -i 's/\[idle]/[idle]\ndpms_timeout=600/' $WAYFIRE_FILE
        else
          echo '\n[idle]\ndpms_timeout=600' >> $WAYFIRE_FILE
          chown $USER:$USER $WAYFIRE_FILE
        fi
      fi
      STATUS=enabled
    elif [ "$RET" -eq 1 ]; then
      if grep -q dpms_timeout $WAYFIRE_FILE ; then
        sed -i 's/dpms_timeout.*/dpms_timeout=-1/' $WAYFIRE_FILE
      else
        if grep -q "\[idle\]" $WAYFIRE_FILE ; then
          sed -i 's/\[idle]/[idle]\ndpms_timeout=-1/' $WAYFIRE_FILE
        else
          echo '\n[idle]\ndpms_timeout=-1' >> $WAYFIRE_FILE
          chown $USER:$USER $WAYFIRE_FILE
        fi
      fi
      STATUS=disabled
    else
      return "$RET"
    fi
  elif is_labwc; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "Would you like to enable screen blanking?" $DEFAULT 20 60 2
      RET=$?
    else
      RET=$1
    fi
    if [ "$RET" -eq "$CURRENT" ]; then
      ASK_TO_REBOOT=1
    fi
    mkdir -p "$HOMEDIR/.config/labwc/"
    chown -R $USER:$USER "$HOMEDIR/.config/labwc/"
    if [ "$RET" -eq 0 ] ; then
      echo "swayidle -w timeout 600 'wlopm --off \\*' resume 'wlopm --on \\*' &" >> $LABWCAST_FILE
      chown $USER:$USER $LABWCAST_FILE
      STATUS=enabled
    elif [ "$RET" -eq 1 ]; then
      if [ -e $LABWCAST_FILE ] ; then
        sed -i '/swayidle/d' $LABWCAST_FILE
      fi
      STATUS=disabled
    else
      return "$RET"
    fi
  else
    if [ "$INTERACTIVE" = True ]; then
      if [ "$(dpkg -l xscreensaver | tail -n 1 | cut -d ' ' -f 1)" = "ii" ]; then
        whiptail --msgbox "Warning: xscreensaver is installed and may override raspi-config settings" 20 60 2
      fi
      whiptail --yesno "Would you like to enable screen blanking?" $DEFAULT 20 60 2
      RET=$?
    else
      RET=$1
    fi
    if [ "$RET" -eq "$CURRENT" ]; then
      ASK_TO_REBOOT=1
    fi
    rm -f /etc/X11/xorg.conf.d/10-blanking.conf
    sed -i '/^\o033/d' /etc/issue
    if [ "$RET" -eq 0 ] ; then
      STATUS=enabled
    elif [ "$RET" -eq 1 ]; then
      mkdir -p /etc/X11/xorg.conf.d/
      cp /usr/share/raspi-config/10-blanking.conf /etc/X11/xorg.conf.d/
      printf "\\033[9;0]" >> /etc/issue
      STATUS=disabled
    else
      return "$RET"
    fi
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Screen blanking is $STATUS" 20 60 1
  fi
}

do_change_pass() {
  whiptail --msgbox "You will now be asked to enter a new password for the $USER user" 20 60 1
  passwd $USER &&
  whiptail --msgbox "Password changed successfully" 20 60 1
}

update_wayfire_keyboard() {
  if ! is_wayfire ; then
    return
  fi
  MODEL=$(grep XKBMODEL /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  LAYOUT=$(grep XKBLAYOUT /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  VARIANT=$(grep XKBVARIANT /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  OPTIONS=$(grep XKBOPTIONS /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  UFILE=$WAYFIRE_FILE
  if [ ! -e $UFILE ] && [ -e /etc/wayfire/template.ini ] ; then
    CONFIG_DIR="$(dirname "$UFILE")"
    if ! [ -d "$CONFIG_DIR" ]; then
      install -o "$USER" -g "$USER" -d "$CONFIG_DIR"
    fi
    cp /etc/wayfire/template.ini $UFILE
    chown $USER:$USER $UFILE
  fi
  if [ -e $UFILE ] ; then
    grep -q "\\[input\\]" $UFILE || printf "\n[input]" >> $UFILE
    if grep -q xkb_model $UFILE ; then sed -i s/xkb_model.*/xkb_model=$MODEL/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_model=$MODEL/ $UFILE ; fi
    if grep -q xkb_layout $UFILE ; then sed -i s/xkb_layout.*/xkb_layout=$LAYOUT/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_layout=$LAYOUT/ $UFILE ; fi
    if grep -q xkb_variant $UFILE ; then sed -i s/xkb_variant.*/xkb_variant=$VARIANT/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_variant=$VARIANT/ $UFILE ; fi
    if grep -q xkb_options $UFILE ; then sed -i s/xkb_options.*/xkb_options=$OPTIONS/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_options=$OPTIONS/ $UFILE ; fi
  fi
  UFILE="/usr/share/greeter.ini"
  if [ ! -e $UFILE ] && [ -e /etc/wayfire/gtemplate.ini ] ; then
    cp /etc/wayfire/gtemplate.ini $UFILE
  fi
  if [ -e $UFILE ] ; then
    grep -q "\\[input\\]" $UFILE || printf "\n[input]" >> $UFILE
    if grep -q xkb_model $UFILE ; then sed -i s/xkb_model.*/xkb_model=$MODEL/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_model=$MODEL/ $UFILE ; fi
    if grep -q xkb_layout $UFILE ; then sed -i s/xkb_layout.*/xkb_layout=$LAYOUT/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_layout=$LAYOUT/ $UFILE ; fi
    if grep -q xkb_variant $UFILE ; then sed -i s/xkb_variant.*/xkb_variant=$VARIANT/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_variant=$VARIANT/ $UFILE ; fi
    if grep -q xkb_options $UFILE ; then sed -i s/xkb_options.*/xkb_options=$OPTIONS/ $UFILE ; else sed -i s/\\[input\\]/[input]\\nxkb_options=$OPTIONS/ $UFILE ; fi
  fi
}

update_labwc_keyboard() {
  MODEL=$(grep XKBMODEL /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  LAYOUT=$(grep XKBLAYOUT /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  VARIANT=$(grep XKBVARIANT /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  OPTIONS=$(grep XKBOPTIONS /etc/default/keyboard | cut -d= -f2 | tr -d '"')
  UFILE=$LABWCENV_FILE
  mkdir -p "$HOMEDIR/.config/labwc/"
  chown -R $USER:$USER "$HOMEDIR/.config/labwc/"
  if [ -e $UFILE ] ; then
    if grep -q XKB_DEFAULT_MODEL $UFILE ; then sed -i s/XKB_DEFAULT_MODEL.*/XKB_DEFAULT_MODEL=$MODEL/ $UFILE ; else echo XKB_DEFAULT_MODEL=$MODEL >> $UFILE ; fi
    if grep -q XKB_DEFAULT_LAYOUT $UFILE ; then sed -i s/XKB_DEFAULT_LAYOUT.*/XKB_DEFAULT_LAYOUT=$LAYOUT/ $UFILE ; else echo XKB_DEFAULT_LAYOUT=$LAYOUT >> $UFILE ; fi
    if grep -q XKB_DEFAULT_VARIANT $UFILE ; then sed -i s/XKB_DEFAULT_VARIANT.*/XKB_DEFAULT_VARIANT=$VARIANT/ $UFILE ; else echo XKB_DEFAULT_VARIANT=$VARIANT >> $UFILE ; fi
    if grep -q XKB_DEFAULT_OPTIONS $UFILE ; then sed -i s/XKB_DEFAULT_OPTIONS.*/XKB_DEFAULT_OPTIONS=$OPTIONS/ $UFILE ; else echo XKB_DEFAULT_OPTIONS=$OPTIONS >> $UFILE ; fi
  else
    echo XKB_DEFAULT_MODEL=$MODEL >> $UFILE
    echo XKB_DEFAULT_LAYOUT=$LAYOUT >> $UFILE
    echo XKB_DEFAULT_VARIANT=$VARIANT >> $UFILE
    echo XKB_DEFAULT_OPTIONS=$OPTIONS >> $UFILE
  fi
  chown $USER:$USER $UFILE
  UFILE="/usr/share/labwc/environment"
  if [ -e $UFILE ] ; then
    if grep -q XKB_DEFAULT_MODEL $UFILE ; then sed -i s/XKB_DEFAULT_MODEL.*/XKB_DEFAULT_MODEL=$MODEL/ $UFILE ; else echo XKB_DEFAULT_MODEL=$MODEL >> $UFILE ; fi
    if grep -q XKB_DEFAULT_LAYOUT $UFILE ; then sed -i s/XKB_DEFAULT_LAYOUT.*/XKB_DEFAULT_LAYOUT=$LAYOUT/ $UFILE ; else echo XKB_DEFAULT_LAYOUT=$LAYOUT >> $UFILE ; fi
    if grep -q XKB_DEFAULT_VARIANT $UFILE ; then sed -i s/XKB_DEFAULT_VARIANT.*/XKB_DEFAULT_VARIANT=$VARIANT/ $UFILE ; else echo XKB_DEFAULT_VARIANT=$VARIANT >> $UFILE ; fi
    if grep -q XKB_DEFAULT_OPTIONS $UFILE ; then sed -i s/XKB_DEFAULT_OPTIONS.*/XKB_DEFAULT_OPTIONS=$OPTIONS/ $UFILE ; else echo XKB_DEFAULT_OPTIONS=$OPTIONS >> $UFILE ; fi
  fi
  if is_labwc ; then
    kill -HUP `pgrep -x labwc`  # does the equivalent of labwc --reconfigure, but works as sudo...
  fi
}

update_squeekboard() {
  PREFIX=""
  if [ -n "$SUDO_USER" ] ; then
    PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
  fi
  LAYOUT1=$(grep XKBLAYOUT /etc/default/keyboard | cut -d= -f2 | tr -d '"' | cut -d, -f1)
  VARIANT1=$(grep XKBVARIANT /etc/default/keyboard | cut -d= -f2 | tr -d '"' | cut -d, -f1)
  LAYOUT2=$(grep XKBLAYOUT /etc/default/keyboard | cut -d= -f2 | tr -d '"' | cut -d, -f2 -s)
  VARIANT2=$(grep XKBVARIANT /etc/default/keyboard | cut -d= -f2 | tr -d '"' | cut -d, -f2 -s)
  GSET="[('xkb', '$LAYOUT1"
  if [ -z "$VARIANT1" ] ; then
    GSET=$GSET"')"
  else
    GSET=$GSET"+$VARIANT1')"
  fi
  if ! [ -z "$LAYOUT2" ] ; then
    GSET=$GSET", ('xkb', '$LAYOUT2"
    if [ -z "$VARIANT2" ] ; then
      GSET=$GSET"')"
    else
      GSET=$GSET"+$VARIANT2')"
    fi
  fi
  GSET=$GSET"]"
  if ! [ -e /etc/dconf/profile/user ] ; then
    mkdir -p "/etc/dconf/profile/"
    echo "user-db:user\nsystem-db:local" >> /etc/dconf/profile/user
  fi
  FILE=/etc/dconf/db/local.d/00_keyboard
  if [ -e $FILE ] ; then
    if grep -q "^sources" $FILE ; then
      sed $FILE -i -e "s/^sources=.*/sources=$GSET/"
    else
      if grep -q "\[org/gnome/desktop/input-sources\]" $FILE ; then
        sed $FILE -i -e "s#\[org/gnome/desktop/input-sources\]#\[org/gnome/desktop/input-sources\]\nsources=$GSET#" 
      else
        echo "[org/gnome/desktop/input-sources]\nsources=$GSET" >> $FILE
      fi
    fi
  else
    mkdir -p "/etc/dconf/db/local.d/"
    echo "[org/gnome/desktop/input-sources]\nsources=$GSET" > $FILE
  fi
  dconf update
  if [ "$1" = restart ] ; then
    if pgrep squeekboard > /dev/null ; then
      pkill squeekboard
      $PREFIX squeekboard > /dev/null 2> /dev/null &
    fi
  fi
}

do_configure_keyboard() {
  printf "Reloading keymap. This may take a short while\n"
  rm -f /etc/console-setup/cached_*
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure keyboard-configuration
  else
    KEYMAP="$1"
    sed -i /etc/default/keyboard -e "s/^XKBLAYOUT.*/XKBLAYOUT=\"$KEYMAP\"/"
    dpkg-reconfigure -f noninteractive keyboard-configuration
  fi
  update_wayfire_keyboard
  update_labwc_keyboard
  update_squeekboard restart
  if [ "$INIT" = "systemd" ]; then
    systemctl restart keyboard-setup
  fi
  setsid sh -c 'exec setupcon --save -k --force <> /dev/tty1 >&0 2>&1'
  udevadm trigger --subsystem-match=input --action=change
  return 0
}

do_change_keyboard_rc_gui () {
  grep -q XKBMODEL /etc/default/keyboard && sed -i "s/XKBMODEL=.*/XKBMODEL=\"$1\"/g" /etc/default/keyboard || echo "XKBMODEL=\"$1\"" >> /etc/default/keyboard
  grep -q XKBLAYOUT /etc/default/keyboard && sed -i "s/XKBLAYOUT=.*/XKBLAYOUT=\"$2\"/g" /etc/default/keyboard || echo "XKBLAYOUT=\"$2\"" >> /etc/default/keyboard
  grep -q XKBVARIANT /etc/default/keyboard && sed -i "s/XKBVARIANT=.*/XKBVARIANT=\"$3\"/g" /etc/default/keyboard || echo "XKBVARIANT=\"$3\"" >> /etc/default/keyboard
  grep -q XKBOPTIONS /etc/default/keyboard && sed -i "s/XKBOPTIONS=.*/XKBOPTIONS=\"$4\"/g" /etc/default/keyboard || echo "XKBOPTIONS=\"$4\"" >> /etc/default/keyboard
  update_wayfire_keyboard
  update_labwc_keyboard
  update_squeekboard restart
  if ! is_wayland ; then
    invoke-rc.d keyboard-setup start
  fi
  setsid sh -c 'exec setupcon -k --force <> /dev/tty1 >&0 2>&1'
  if ! is_wayland ; then
    udevadm trigger --subsystem-match=input --action=change
    udevadm settle
    KBSTR="-model $1 -layout $2"
    if [ -n "$3" ] ; then
      KBSTR="$KBSTR -variant $3"
    fi
    if [ -n "$4" ] ; then
      KBSTR="$KBSTR -option -option $4"
    fi
    setxkbmap "$KBSTR"
  fi
}

do_change_locale() {
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure locales
  else
    if ! LOCALE_LINE="$(grep -E "^$1( |$)" /usr/share/i18n/SUPPORTED)"; then
      return 1
    fi
    export LC_ALL=C
    export LANG=C
    LG="/etc/locale.gen"
    NEW_LANG="$(echo $LOCALE_LINE | cut -f1 -d " ")"
    [ -L "$LG" ] && [ "$(readlink $LG)" = "/usr/share/i18n/SUPPORTED" ] && rm -f "$LG"
    echo "$LOCALE_LINE" > /etc/locale.gen
    update-locale --no-checks LANG
    update-locale --no-checks "LANG=$NEW_LANG"
    dpkg-reconfigure -f noninteractive locales
  fi
}

do_change_locale_rc_gui() {
  sed -i "s/^\([^#].*\)/# \1/g" /etc/locale.gen
  if grep -q "$1 " /etc/locale.gen ; then
    LOC="$1"
  else
    LOC="$1.UTF-8"
  fi
  sed -i "s/^# \($LOC\s\)/\1/g" /etc/locale.gen
  locale-gen
  LC_ALL=$LOC LANG=$LOC LANGUAGE=$LOC update-locale LANG=$LOC LC_ALL=$LOC LANGUAGE=$LOC
}

do_change_timezone() {
  if [ "$INTERACTIVE" = True ]; then
    dpkg-reconfigure tzdata
  else
    TIMEZONE="$1"
    if [ ! -f "/usr/share/zoneinfo/$TIMEZONE" ]; then
      return 1;
    fi
    rm /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
    dpkg-reconfigure -f noninteractive tzdata 2> /dev/null
  fi
}

do_change_timezone_rc_gui() {
  echo $1 | tee /etc/timezone
  rm /etc/localtime
  dpkg-reconfigure --frontend noninteractive tzdata
}

get_wifi_country() {
  CODE=${1:-0}
  if is_installed crda && [ -e /etc/default/crda ]; then
    . /etc/default/crda
  elif grep -q "cfg80211.ieee80211_regdom=" "$CMDLINE"; then
    REGDOMAIN="$(sed -n 's/.*cfg80211.ieee80211_regdom=\(\S*\).*/\1/p' "$CMDLINE")"
  elif systemctl -q is-active dhcpcd; then
    REGDOMAIN="$(wpa_cli get country | tail -n 1)"
  else
    REGDOMAIN="$(iw reg get | sed -n "0,/country/s/^country \(.\+\):.*$/\1/p")"
  fi
  if [ -z "$REGDOMAIN" ] \
     || ! grep -q "^${REGDOMAIN}[[:space:]]" /usr/share/zoneinfo/iso3166.tab; then
    return 1
  fi
  if [ "$CODE" = 0 ]; then
    echo "$REGDOMAIN"
  fi
  return 0
}

do_wifi_country() {
  if [ "$INTERACTIVE" = True ]; then
    value=$(sed '/^#/d' /usr/share/zoneinfo/iso3166.tab | tr '\t\n' '/')
    oIFS="$IFS"
    IFS="/"
    #shellcheck disable=2086
    REGDOMAIN=$(whiptail --menu "Select the country in which the Pi is to be used" 20 60 10 ${value} 3>&1 1>&2 2>&3)
    IFS="$oIFS"
  else
    REGDOMAIN=$1
  fi
  if ! grep -q "^${REGDOMAIN}[[:space:]]" /usr/share/zoneinfo/iso3166.tab; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "$REGDOMAIN is not a valid ISO/IEC 3166-1 alpha2 code" 20 60
    fi
    return 1
  fi
  sed -i \
    -e "s/\s*cfg80211.ieee80211_regdom=\S*//" \
    -e "s/\(.*\)/\1 cfg80211.ieee80211_regdom=$REGDOMAIN/" \
    "$CMDLINE"
  if is_installed crda && [ -e /etc/default/crda ]; then
    # This mechanism has been removed from Bookworm and should no longer be used
    rm -f /etc/default/crda
  fi
  if ! ischroot; then
    iw reg set "$REGDOMAIN"
  fi

  IFACE="$(list_wlan_interfaces | head -n 1)"
  if [ "$INIT" = "systemd" ] && [ -n "$IFACE" ] && systemctl -q is-active dhcpcd; then
    wpa_cli -i "$IFACE" set country "$REGDOMAIN" > /dev/null 2>&1
    wpa_cli -i "$IFACE" save_config > /dev/null 2>&1
  fi

  if [ "$INIT" = "systemd" ] && ! ischroot && systemctl -q is-active NetworkManager; then
    nmcli radio wifi on
  elif hash rfkill 2> /dev/null; then
    rfkill unblock wifi
    if [ -f /var/lib/NetworkManager/NetworkManager.state ]; then
      sed -i 's/^WirelessEnabled=.*/WirelessEnabled=true/' /var/lib/NetworkManager/NetworkManager.state
    fi
  fi
  if is_pi; then
    for filename in /var/lib/systemd/rfkill/*:wlan ; do
      if ! [ -e "$filename" ]; then
        continue
      fi
      echo 0 > "$filename"
    done
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Wireless LAN country set to $REGDOMAIN" 20 60 1
  fi
  if ! ischroot && pgrep wf-panel-pi > /dev/null; then
    wfpanelctl netman cset
  fi
  if ! ischroot && pgrep lxpanel > /dev/null; then
    lxpanelctl command netman cset
  fi
}

get_hostname() {
  tr -d " \t\n\r" < /etc/hostname
}

do_hostname() {
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "\
Please note: RFCs mandate that a hostname's labels \
may contain only the ASCII letters 'a' through 'z' (case-insensitive),
the digits '0' through '9', and the hyphen.
Hostname labels cannot begin or end with a hyphen.
No other symbols, punctuation characters, or blank spaces are permitted.\
" 20 70 1
  fi
  CURRENT_HOSTNAME=$(get_hostname)
  if [ "$INTERACTIVE" = True ]; then
    NEW_HOSTNAME=$(whiptail --inputbox "Please enter a hostname" 20 60 "$CURRENT_HOSTNAME" 3>&1 1>&2 2>&3)
  else
    NEW_HOSTNAME="$1"
    true
  fi
  if [ $? -eq 0 ]; then
    if [ "$INIT" = "systemd" ] && systemctl -q is-active dbus && ! ischroot; then
      hostnamectl set-hostname "$NEW_HOSTNAME" 2> /dev/null
    else
      echo "$NEW_HOSTNAME" > /etc/hostname
    fi
    sed -i "s/127\.0\.1\.1.*$CURRENT_HOSTNAME/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
    ASK_TO_REBOOT=1
  fi
}

do_overclock() {
  if ! is_pione && ! is_pitwo; then
    whiptail --msgbox "Only Pi 1 or Pi 2 can be overclocked with this tool." 20 60 2
    return 1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "\
Be aware that overclocking may reduce the lifetime of your
Raspberry Pi. If overclocking at a certain level causes
system instability, try a more modest overclock. Hold down
shift during boot to temporarily disable overclock.
See https://www.raspberrypi.org/documentation/configuration/config-txt/overclocking.md for more information.\
" 20 70 1
  if is_pione; then
    OVERCLOCK=$(whiptail --menu "Choose overclock preset" 20 60 10 \
      "None" "700MHz ARM, 250MHz core, 400MHz SDRAM, 0 overvolt" \
      "Modest" "800MHz ARM, 250MHz core, 400MHz SDRAM, 0 overvolt" \
      "Medium" "900MHz ARM, 250MHz core, 450MHz SDRAM, 2 overvolt" \
      "High" "950MHz ARM, 250MHz core, 450MHz SDRAM, 6 overvolt" \
      "Turbo" "1000MHz ARM, 500MHz core, 600MHz SDRAM, 6 overvolt" \
      3>&1 1>&2 2>&3)
  elif is_pitwo; then
    OVERCLOCK=$(whiptail --menu "Choose overclock preset" 20 60 10 \
      "None" "900MHz ARM, 250MHz core, 450MHz SDRAM, 0 overvolt" \
      "High" "1000MHz ARM, 500MHz core, 500MHz SDRAM, 2 overvolt" \
      3>&1 1>&2 2>&3)
  fi
  else
    OVERCLOCK=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$OVERCLOCK" in
      None)
        clear_overclock
        ;;
      Modest)
        set_overclock Modest 800 250 400 0
        ;;
      Medium)
        set_overclock Medium 900 250 450 2
        ;;
      High)
        if is_pione; then
          set_overclock High 950 250 450 6
        else
          set_overclock High 1000 500 500 2
        fi
        ;;
      Turbo)
        set_overclock Turbo 1000 500 600 6
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised overclock preset" 20 60 2
        return 1
        ;;
    esac
    ASK_TO_REBOOT=1
  fi
}

set_overclock() {
  set_config_var arm_freq $2 $CONFIG &&
  set_config_var core_freq $3 $CONFIG &&
  set_config_var sdram_freq $4 $CONFIG &&
  set_config_var over_voltage $5 $CONFIG &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Set overclock to preset '$1'" 20 60 2
  fi
}

clear_overclock () {
  clear_config_var arm_freq $CONFIG &&
  clear_config_var core_freq $CONFIG &&
  clear_config_var sdram_freq $CONFIG &&
  clear_config_var over_voltage $CONFIG &&
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Set overclock to preset 'None'" 20 60 2
  fi
}

get_ssh() {
  if service ssh status | grep -q inactive; then
    echo 1
  else
    echo 0
  fi
}

do_ssh() {
  if [ -e /var/log/regen_ssh_keys.log ] && ! grep -q "^finished" /var/log/regen_ssh_keys.log; then
    whiptail --msgbox "Initial ssh key generation still running. Please wait and try again." 20 60 2
    return 1
  fi
  DEFAULT=--defaultno
  if [ $(get_ssh) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno \
      "Would you like the SSH server to be enabled?\n\nCaution: Default and weak passwords are a security risk when SSH is enabled!" \
      $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    ssh-keygen -A &&
    update-rc.d ssh enable &&
    invoke-rc.d ssh start &&
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    update-rc.d ssh disable &&
    invoke-rc.d ssh stop &&
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The SSH server is $STATUS" 20 60 1
  fi
}

get_vnc() {
  if is_wayland; then
    if systemctl status wayvnc.service | grep -q -w active; then
      echo 0
    else
      echo 1
    fi
  else
    if systemctl status vncserver-x11-serviced.service | grep -q -w active; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_vnc() {
  DEFAULT=--defaultno
  if [ $(get_vnc) -eq 0 ]; then
    DEFAULT=
  fi
  APT_GET_FLAGS=""
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the VNC Server to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
    APT_GET_FLAGS="-y"
  fi
  if [ $RET -eq 0 ]; then
    if is_installed wayvnc; then
      wayvnc_version="$(get_package_version wayvnc)"
      if dpkg --compare-versions "$wayvnc_version" lt 0.8; then
        whiptail --msgbox "WayVNC version 0.8 or greater is required (have $wayvnc_version)" 20 60 1
        return 1
      fi

      systemctl stop wayvnc.service

      # In case wayvnc is already running via older xdg-autostart machanism
      if [ -e /etc/xdg/autostart/wayvnc.desktop ] ; then
        rm /etc/xdg/autostart/wayvnc.desktop
      fi
    fi
    if is_installed realvnc-vnc-server; then
      systemctl disable vncserver-x11-serviced.service
      systemctl stop vncserver-x11-serviced.service
    fi
    if is_wayland; then
      if is_installed wayvnc; then
        systemctl enable wayvnc.service &&
        systemctl start wayvnc.service &&
        STATUS=enabled
      else
        return 1
      fi
    else
      if is_installed realvnc-vnc-server || apt-get install "$APT_GET_FLAGS" realvnc-vnc-server; then
        systemctl enable vncserver-x11-serviced.service &&
        systemctl start vncserver-x11-serviced.service &&
        STATUS=enabled
      else
        return 1
      fi
    fi
  elif [ $RET -eq 1 ]; then
    if is_installed wayvnc; then
      systemctl disable wayvnc.service
      systemctl stop wayvnc.service
    fi
    if is_installed realvnc-vnc-server; then
      systemctl disable vncserver-x11-serviced.service
      systemctl stop vncserver-x11-serviced.service
    fi
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The VNC Server is $STATUS" 20 60 1
  fi
}

get_rpi_connect() {
  PREFIX=""
  if [ -n "$SUDO_USER" ] ; then
    PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
  fi
  if $PREFIX systemctl --user -q status rpi-connect.service | grep -q -w active; then
    echo 0
  else
    echo 1
  fi
}

do_rpi_connect() {
  PREFIX=""
  if [ -n "$SUDO_USER" ] ; then
    PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
  fi
  APT_GET_FLAGS=""
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable screen sharing over Raspberry Pi Connect?" --defaultno 20 60 2
    RET=$?
  else
    APT_GET_FLAGS="-y"
    RET=$1
  fi
  rpi_connect_version="$(get_package_version rpi-connect)"
  if [ $RET -eq 0 ]; then
    if is_installed rpi-connect || apt-get install "$APT_GET_FLAGS" rpi-connect; then
      if dpkg --compare-versions "$rpi_connect_version" lt 1.3; then
        $PREFIX systemctl --user -q enable rpi-connect.service rpi-connect-wayvnc.service
        $PREFIX systemctl --user -q start rpi-connect.service rpi-connect-wayvnc.service
      elif dpkg --compare-versions "$rpi_connect_version" lt 2.0; then
        $PREFIX systemctl --user -q enable rpi-connect.service rpi-connect-wayvnc.service rpi-connect-wayvnc-watcher.path
        $PREFIX systemctl --user -q start rpi-connect.service
      else
        $PREFIX rpi-connect on > /dev/null 2>&1
      fi
      STATUS="Screen sharing via Raspberry Pi Connect is enabled"
    else
      return 1
    fi
  elif [ $RET -eq 1 ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "Would you like to enable remote shell access over Raspberry Pi Connect?" --defaultno 20 60 2
      RET=$?
    fi
    if [ $RET -eq 0 ]; then
      if is_installed rpi-connect || is_installed rpi-connect-lite || apt-get install "$APT_GET_FLAGS" rpi-connect-lite; then
        if dpkg --compare-versions "$rpi_connect_version" lt 2.0; then
          $PREFIX systemctl --user -q enable rpi-connect.service
          $PREFIX systemctl --user -q start rpi-connect.service
        else
          $PREFIX rpi-connect on > /dev/null 2>&1
        fi
        STATUS="Remote shell access via Raspberry Pi Connect is enabled"
      else
        return 1
      fi
    elif [ $RET -eq 1 ]; then
      if dpkg --compare-versions "$rpi_connect_version" lt 1.3; then
        $PREFIX systemctl --user -q stop rpi-connect.service rpi-connect-wayvnc.service
        $PREFIX systemctl --user -q disable rpi-connect-wayvnc.service rpi-connect.service
      elif dpkg --compare-versions "$rpi_connect_version" lt 2.0; then
        $PREFIX systemctl --user -q stop rpi-connect.service
        $PREFIX systemctl --user -q disable rpi-connect.service rpi-connect-wayvnc.service rpi-connect-wayvnc-watcher.path
      else
        $PREFIX rpi-connect off > /dev/null 2>&1
      fi
      STATUS="Raspberry Pi Connect is disabled"
    else
      return $RET
    fi
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "$STATUS" 20 60 1
  fi
}

get_spi() {
  if grep -q -E "^(device_tree_param|dtparam)=([^,]*,)*spi(=(on|true|yes|1))?(,.*)?$" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_spi() {
  DEFAULT=--defaultno
  if [ $(get_spi) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the SPI interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    SETTING=on
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    SETTING=off
    STATUS=disabled
  else
    return $RET
  fi

  set_config_var dtparam=spi $SETTING $CONFIG &&
  if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
  fi
  sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*spi[-_]bcm2708\)/#\1/"
  dtparam spi=$SETTING

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The SPI interface is $STATUS" 20 60 1
  fi
}

get_i2c() {
  if grep -q -E "^(device_tree_param|dtparam)=([^,]*,)*i2c(_arm)?(=(on|true|yes|1))?(,.*)?$" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_i2c() {
  DEFAULT=--defaultno
  if [ $(get_i2c) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the ARM I2C interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    SETTING=on
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    SETTING=off
    STATUS=disabled
  else
    return $RET
  fi

  set_config_var dtparam=i2c_arm $SETTING $CONFIG &&
  if ! [ -e $BLACKLIST ]; then
    touch $BLACKLIST
  fi
  sed $BLACKLIST -i -e "s/^\(blacklist[[:space:]]*i2c[-_]bcm2708\)/#\1/"
  sed /etc/modules -i -e "s/^#[[:space:]]*\(i2c[-_]dev\)/\1/"
  if ! grep -q "^i2c[-_]dev" /etc/modules; then
    printf "i2c-dev\n" >> /etc/modules
  fi
  dtparam i2c_arm=$SETTING
  modprobe i2c-dev

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The ARM I2C interface is $STATUS" 20 60 1
  fi
}

get_serial_cons() {
  if grep -q -E "console=(serial0|ttyAMA0|ttyS0)" $CMDLINE ; then
    echo 0
  else
    echo 1
  fi
}

get_serial_hw() {
  if is_pifive ; then
    if grep -q -E "dtparam=uart0=off" $CONFIG ; then
      echo 1
    elif grep -q -E "dtparam=uart0" $CONFIG ; then
      echo 0
    else
      echo 1
    fi
  else
    if grep -q -E "^enable_uart=1" $CONFIG ; then
      echo 0
    elif grep -q -E "^enable_uart=0" $CONFIG ; then
      echo 1
    elif [ -e /dev/serial0 ] ; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_serial_cons() {
  if [ $1 -eq 0 ] ; then
    if grep -q "console=ttyAMA0" $CMDLINE ; then
      if [ -e /proc/device-tree/aliases/serial0 ]; then
        sed -i $CMDLINE -e "s/console=ttyAMA0/console=serial0/"
      fi
    elif ! grep -q "console=ttyAMA0" $CMDLINE && ! grep -q "console=serial0" $CMDLINE ; then
      if [ -e /proc/device-tree/aliases/serial0 ]; then
        sed -i $CMDLINE -e "s/root=/console=serial0,115200 root=/"
      else
        sed -i $CMDLINE -e "s/root=/console=ttyAMA0,115200 root=/"
      fi
    fi
  else
    sed -i $CMDLINE -e "s/console=ttyAMA0,[0-9]\+ //"
    sed -i $CMDLINE -e "s/console=serial0,[0-9]\+ //"
  fi
}

do_serial_hw() {
  if [ $1 -eq 0 ] ; then
    if is_pifive ; then
      set_config_var dtparam=uart0 on $CONFIG
    else
      set_config_var enable_uart 1 $CONFIG
    fi
  else
    if is_pifive ; then
      sed $CONFIG -i -e "/dtparam=uart0.*/d"
    else
      set_config_var enable_uart 0 $CONFIG
    fi
  fi
}

do_serial() {
  DEFAULTS=--defaultno
  DEFAULTH=--defaultno
  CURRENTS=0
  CURRENTH=0
  if [ $(get_serial_cons) -eq 0 ]; then
    DEFAULTS=
    CURRENTS=1
  fi
  if [ $(get_serial_hw) -eq 0 ]; then
    DEFAULTH=
    CURRENTH=1
  fi
  whiptail --yesno "Would you like a login shell to be accessible over serial?" $DEFAULTS 20 60 2
  RET=$?
  if [ $RET -eq $CURRENTS ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    do_serial_cons 0
    SSTATUS=enabled
    do_serial_hw 0
    HSTATUS=enabled
  elif [ $RET -eq 1 ]; then
    do_serial_cons 1
    SSTATUS=disabled
    whiptail --yesno "Would you like the serial port hardware to be enabled?" $DEFAULTH 20 60 2
    RET=$?
    if [ $RET -eq $CURRENTH ]; then
      ASK_TO_REBOOT=1
    fi
    if [ $RET -eq 0 ]; then
      do_serial_hw 0
      HSTATUS=enabled
    elif [ $RET -eq 1 ]; then
      do_serial_hw 1
      HSTATUS=disabled
    else
      return $RET
    fi
  else
    return $RET
  fi
  whiptail --msgbox "The serial login shell is $SSTATUS\nThe serial interface is $HSTATUS" 20 60 1
}

do_serial_pi5() {
  DEFAULTS=--defaultno
  DEFAULTH=--defaultno
  CURRENTS=0
  CURRENTH=0
  if [ $(get_serial_cons) -eq 0 ]; then
    DEFAULTS=
    CURRENTS=1
  fi
  if [ $(get_serial_hw) -eq 0 ]; then
    DEFAULTH=
    CURRENTH=1
  fi
  whiptail --yesno "Would you like a login shell to be accessible over serial?" $DEFAULTS 20 60 2
  RET=$?
  if [ $RET -eq $CURRENTS ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    do_serial_cons 0
    SSTATUS=enabled
  elif [ $RET -eq 1 ]; then
    do_serial_cons 1
    SSTATUS=disabled
  else
    return $RET
  fi
  whiptail --yesno "Would you like the serial port hardware to be enabled?" $DEFAULTH 20 60 2
  RET=$?
  if [ $RET -eq $CURRENTH ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    do_serial_hw 0
    HSTATUS=enabled
  elif [ $RET -eq 1 ]; then
    do_serial_hw 1
    HSTATUS=disabled
  else
    return $RET
  fi
  whiptail --msgbox "The serial login shell is $SSTATUS\nThe serial interface is $HSTATUS" 20 60 1
}

get_pci() {
  if grep -q -E "^dtparam=pciex1_gen=3$" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_pci() {
  DEFAULT=--defaultno
  CURRENT=1
  if [ $(get_pci) -eq 0 ]; then
    DEFAULT=
    CURRENT=0
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like PCIe Gen 3 to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    set_config_var dtparam=pciex1_gen 3 $CONFIG
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    clear_config_var dtparam=pciex1_gen $CONFIG
    STATUS=disabled
  else
    return $RET
  fi
  if [ $RET -ne $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "PCIe Gen 3 is $STATUS" 20 60 1
  fi
}

disable_raspi_config_at_boot() {
  if [ -e /etc/profile.d/raspi-config.sh ]; then
    rm -f /etc/profile.d/raspi-config.sh
    if [ -e /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf ]; then
      rm /etc/systemd/system/getty@tty1.service.d/raspi-config-override.conf
    fi
    telinit q
  fi
}

get_boot_cli() {
  if [ "$(basename $(readlink -f /etc/systemd/system/default.target))" = graphical.target ] \
     && systemctl is-enabled lightdm > /dev/null 2>&1; then
    echo 1
  else
    echo 0
  fi
}

get_autologin() {
  if [ $(get_boot_cli) -eq 0 ]; then
    # booting to CLI
    if [ -e /etc/systemd/system/getty@tty1.service.d/autologin.conf ] ; then
      echo 0
    else
      echo 1
    fi
  else
    # booting to desktop - check the autologin for lightdm
    if grep -q "^autologin-user=" /etc/lightdm/lightdm.conf ; then
      echo 0
    else
      echo 1
    fi
  fi
}

get_pi4video () {
  if grep -q "^hdmi_enable_4kp60=1" $CONFIG ; then
    echo 0
  else
    echo 1
  fi
}

do_pi4video() {
  CURRENT=$(get_pi4video)
  DEFAULT=--defaultno
  if [ $CURRENT -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable 4Kp60 output on HDMI0?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e "s/^#\?hdmi_enable_4kp60=.*/hdmi_enable_4kp60=1/"
    if ! grep -q "hdmi_enable_4kp60" $CONFIG ; then
      sed $CONFIG -i -e "\$ahdmi_enable_4kp60=1"
    fi
    sed $CONFIG -i -e "s/^enable_tvout=/#enable_tvout=/"
    sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d.*/dtoverlay=vc4-kms-v3d/"
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^hdmi_enable_4kp60=/#hdmi_enable_4kp60=/"
    sed $CONFIG -i -e "s/^enable_tvout=/#enable_tvout=/"
    sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d.*/dtoverlay=vc4-kms-v3d/"
    STATUS=disabled
  else
    return $RET
  fi
  if [ $RET -ne $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "4Kp60 is $STATUS" 20 60 1
  fi
}

get_composite() {
  if grep -q "^dtoverlay=vc4-kms-v3d,composite" $CONFIG ; then
    echo 0
  else
    echo 1
  fi
}

do_composite() {
  CURRENT=$(get_composite)
  DEFAULT=--defaultno
  if [ $CURRENT -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like composite video output to be enabled? Warning - this will disable the HDMI outputs." $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d.*/dtoverlay=vc4-kms-v3d,composite/"
    sed $CONFIG -i -e "s/^#\?enable_tvout=.*/enable_tvout=1/"
    sed $CONFIG -i -e "s/^hdmi_enable_4kp60=/#hdmi_enable_4kp60=/"
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d.*/dtoverlay=vc4-kms-v3d/"
    sed $CONFIG -i -e "s/^enable_tvout=/#enable_tvout=/"
    STATUS=disabled
  else
    return $RET
  fi
  if [ $RET -ne $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Composite video output is $STATUS" 20 60 1
  fi
}

get_leds () {
  if [ ! -e /sys/class/leds/ACT/trigger ] ; then
    echo -1
  elif grep -q "\\[actpwr\\]" /sys/class/leds/ACT/trigger ; then
    echo 0
  elif grep -q "\\[default-on\\]" /sys/class/leds/ACT/trigger ; then
    echo 1
  else
    echo -1
  fi
}

do_leds() {
  CURRENT=$(get_leds)
  if [ $CURRENT -eq -1 ] ; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The LED behaviour cannot be changed on this model of Raspberry Pi" 20 60 1
    fi
    return 1
  fi
  DEFAULT=--defaultno
  if [ $CURRENT -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the power LED to flash during disk activity?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    LEDSET="actpwr"
    STATUS="flash for disk activity"
  elif [ $RET -eq 1 ]; then
    LEDSET="default-on"
    STATUS="be on constantly"
  else
    return $RET
  fi
  sed $CONFIG -i -e "s/dtparam=act_led_trigger=.*/dtparam=act_led_trigger=$LEDSET/"
  if ! grep -q "dtparam=act_led_trigger" $CONFIG ; then
    sed $CONFIG -i -e "\$adtparam=act_led_trigger=$LEDSET"
  fi
  echo $LEDSET | tee /sys/class/leds/ACT/trigger > /dev/null
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The power LED will $STATUS" 20 60 1
  fi
}

get_fan() {
  if grep -q ^dtoverlay=gpio-fan $CONFIG ; then
    echo 0
  else
    echo 1
  fi
}

get_fan_gpio() {
  GPIO=$(grep ^dtoverlay=gpio-fan $CONFIG | cut -d, -f2 | cut -d= -f2)
  if [ -z $GPIO ]; then
    GPIO=14
  fi
  echo $GPIO
}

get_fan_temp() {
  TEMP=$(grep ^dtoverlay=gpio-fan $CONFIG | cut -d, -f3 | cut -d= -f2)
  if [ -z $TEMP ]; then
    TEMP=80000
  fi
  echo $((TEMP / 1000))
}

do_fan() {
  GNOW=$(get_fan_gpio)
  TNOW=$(get_fan_temp)
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable fan temperature control?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ] ; then
    if [ "$INTERACTIVE" = True ]; then
      GPIO=$(whiptail --inputbox "To which GPIO is the fan connected?" 20 60 "$GNOW" 3>&1 1>&2 2>&3)
    else
      if [ -z $2 ]; then
        GPIO=14
      else
        GPIO=$2
      fi
    fi
    if [ $? -ne 0 ] ; then
      return 0
    fi
    if ! echo "$GPIO" | grep -q "^[[:digit:]]*$" ; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "GPIO must be a number between 2 and 27" 20 60 1
      fi
      return 1
    fi
    if [ "$GPIO" -lt 2 ] || [ "$GPIO" -gt 27 ]  ; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "GPIO must be a number between 2 and 27" 20 60 1
      fi
      return 1
    fi
    if [ "$INTERACTIVE" = True ]; then
      TIN=$(whiptail --inputbox "At what temperature in degrees Celsius should the fan turn on?" 20 60 "$TNOW" 3>&1 1>&2 2>&3)
    else
      if [ -z $3 ]; then
        TIN=80
      else
        TIN=$3
      fi
    fi
    if [ $? -ne 0 ] ; then
      return 0
    fi
    if ! echo "$TIN" | grep -q "^[[:digit:]]*$" ; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Temperature must be a number between 60 and 120" 20 60 1
      fi
      return 1
    fi
    if [ "$TIN" -lt 60 ] || [ "$TIN" -gt 120 ]  ; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Temperature must be a number between 60 and 120" 20 60 1
      fi
      return 1
    fi
    TEMP=$((TIN * 1000))
  fi
  if [ $RET -eq 0 ]; then
    if ! grep -q "dtoverlay=gpio-fan" $CONFIG ; then
      if ! tail -1 $CONFIG | grep -q "\\[all\\]" ; then
        sed $CONFIG -i -e "\$a[all]"
      fi
      sed $CONFIG -i -e "\$adtoverlay=gpio-fan,gpiopin=$GPIO,temp=$TEMP"
    else
      sed $CONFIG -i -e "s/^.*dtoverlay=gpio-fan.*/dtoverlay=gpio-fan,gpiopin=$GPIO,temp=$TEMP/"
    fi
    ASK_TO_REBOOT=1
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The fan on GPIO $GPIO is enabled and will turn on at $TIN degrees Celsius" 20 60 1
    fi
  else
    if grep -q "^dtoverlay=gpio-fan" $CONFIG ; then
      ASK_TO_REBOOT=1
    fi
    sed $CONFIG -i -e "/^.*dtoverlay=gpio-fan.*/d"
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The fan is disabled" 20 60 1
    fi
  fi
}

get_browser() {
  echo $(update-alternatives --display x-www-browser | grep currently | cut -d " " -f 7 | cut -d / -f 4)
}

do_browser() {
  if [ "$INTERACTIVE" = True ]; then
    RES=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Select Browser" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "1" "Chromium" \
      "2" "Firefox" \
      3>&1 1>&2 2>&3)
  else
    RES=""
    BROWSER=$1
    true
  fi
  if [ $? -eq 0 ]; then
    if [ "$RES" = "1" ] ; then
      BROWSER="chromium"
      BSTRING="Chromium"
    elif [ "$RES" = "2" ] ; then
      BROWSER="firefox"
      BSTRING="Firefox"
    fi
    update-alternatives --set x-www-browser /usr/bin/$BROWSER > /dev/null
    if [ -z $2 ] ; then
      sudo -u $USER xdg-settings set default-web-browser $BROWSER.desktop
    else
      sudo -u $2 xdg-settings set default-web-browser $BROWSER.desktop
    fi
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Default browser set to $BSTRING" 20 60 1
    fi
  fi
}

do_journald_storage() {
  if [ "$INTERACTIVE" = True ]; then
    RES=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Select Log Location" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "1" "Default" \
      "2" "Volatile" \
      "3" "Persistent" \
      "4" "Auto" \
      "5" "None" \
      3>&1 1>&2 2>&3)
  else
    RES=""
    true
  fi
  if [ $? -eq 0 ]; then
    case $RES in
      2) JSTRING="volatile"
      ;;
      3) JSTRING="persistent"
      ;;
      4) JSTRING="auto"
      ;;
      5) JSTRING="none"
      ;;
      *) JSTRING=""
      ;;
    esac
    REPLACEMENT="$([ ! -z $JSTRING ] && echo "Storage=$JSTRING" || echo "#Storage=auto")"
    sed --in-place -E "s/^#?Storage=.*/${REPLACEMENT}/" /etc/systemd/journald.conf
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "Logging location set to ${JSTRING:-default}" 20 60 1
    fi
  fi
}

do_boot_behaviour() {
  if [ "$INTERACTIVE" = True ]; then
    BOOTOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Boot Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "B1 Console" "Text console, requiring user to login" \
      "B2 Console Autologin" "Text console, automatically logged in as '$USER' user" \
      "B3 Desktop" "Desktop GUI, requiring user to login" \
      "B4 Desktop Autologin" "Desktop GUI, automatically logged in as '$USER' user" \
      3>&1 1>&2 2>&3)
  else
    BOOTOPT=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$BOOTOPT" in # Handle default target
      B1*|B2*) # Console
        systemctl --quiet set-default multi-user.target
        ;;
      B3*|B4*) # Desktop
        if [ -e /etc/init.d/lightdm ]; then
          systemctl --quiet set-default graphical.target
        else
          whiptail --msgbox "Do 'sudo apt-get install lightdm' to allow configuration of boot to desktop" 20 60 2
          return 1
        fi
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
    case "$BOOTOPT" in # Handle autologin
      B1*|B3*) # Autologin disabled
        if [ -z "${BOOTOPT%%B3*}" ]; then
          sed /etc/lightdm/lightdm.conf -i -e "s/^autologin-user=.*/#autologin-user=/"
        fi
        if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
          rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
          rmdir --ignore-fail-on-non-empty /etc/systemd/system/getty@tty1.service.d
        fi
        ;;
      B2*|B4*) # Autologin enabled
        if [ -z "${BOOTOPT%%B4*}" ]; then
          sed /etc/lightdm/lightdm.conf -i -e "s/^\(#\|\)autologin-user=.*/autologin-user=$USER/"
        fi
        mkdir -p /etc/systemd/system/getty@tty1.service.d
        cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $USER --noclear %I \$TERM
EOF
        ;;
    esac
    if [ "$INIT" = "systemd" ]; then
      systemctl daemon-reload
    fi
    ASK_TO_REBOOT=1
  fi
}

get_bootloader_filename() {
   CURDATE=$(date -d "$(vcgencmd bootloader_version |  head -n 1)" +%Y%m%d)
   FILNAME=""
   EEBASE=$(rpi-eeprom-update | grep RELEASE | sed 's/.*(//g' | sed 's/[^\/]*)//g')
   if grep FIRMWARE_RELEASE_STATUS /etc/default/rpi-eeprom-update | egrep -Eq "stable|latest"; then
      EEPATH="${EEBASE}/latest/pieeprom*.bin"
   else
      EEPATH="${EEBASE}/default/pieeprom*.bin"
   fi
   EXACT_MATCH=0
   for filename in $(find $EEPATH -name "pieeprom*.bin" 2>/dev/null | sort); do
      FILDATE=$(date -d "$(echo $filename | sed 's/.*\///g' | cut -d - -f 2- | cut -d . -f 1)" +%Y%m%d)
      FILNAME=$filename
      if [ $FILDATE -eq $CURDATE ]; then
         EXACT_MATCH=1
         break
      fi
   done
   if [ $EXACT_MATCH != 1 ]; then
      if [ "$INTERACTIVE" = True ]; then
         whiptail --yesno "Current EEPROM version $(date -d $CURDATE +%Y-%m-%d) or newer not found.\n\nTry updating the rpi-eeprom APT package.\n\nInstall latest local $(basename $FILNAME) anyway?" 20 70 3
         DEFAULTS=$?
         if [ "$DEFAULTS" -ne 0 ]; then
            FILNAME="none" # no
         fi
      fi
   fi
}

do_network_install_ui() {
  if [ "$INTERACTIVE" = True ]; then
    BOOTOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Bootloader network install UI" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "B1 Always" "Always display the UI for a few seconds after power on." \
      "B2 On demand" "Display the UI if the SHIFT key is presssed or if an error occurs." \
      3>&1 1>&2 2>&3)
  else
    BOOTOPT=$1
    true
  fi

  if [ $? -eq 0 ]; then
    get_bootloader_filename
    if [ "${FILNAME}" = "none" ]; then
       if [ "$INTERACTIVE" = True ]; then
          return 0
       else
          return 1
       fi
    fi
    EECFG=$(mktemp)
    rpi-eeprom-config > $EECFG
    sed $EECFG -i -e "/NET_INSTALL_AT_POWER_ON/d"
    case "$BOOTOPT" in
      B1*)
         echo "NET_INSTALL_AT_POWER_ON=1" >> $EECFG
         ;;
      B2*)
         # NET_INSTALL_AT_POWER_ON default value is 0
         true
         ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
    rpi-eeprom-config --apply $EECFG $FILNAME
    ASK_TO_REBOOT=1
  fi
 }

do_boot_order() {
  if [ "$INTERACTIVE" = True ]; then
    BOOTOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Boot Device Order" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "B1 SD Card Boot " "Boot from SD Card before trying NVMe and then USB (RECOMMENDED)" \
      "B2 NVMe/USB Boot" "Boot from NVMe before trying USB and then SD Card" \
      "B3 Network Boot " "Boot from Network unless override by SD Card" \
      3>&1 1>&2 2>&3)
  else
    BOOTOPT=$1
    true
  fi
  if [ $? -eq 0 ]; then
    EECFG=$(mktemp)
    rpi-eeprom-config > $EECFG
    sed $EECFG -i -e "/SD_BOOT_MAX_RETRIES/d"
    sed $EECFG -i -e "/NET_BOOT_MAX_RETRIES/d"
    case "$BOOTOPT" in
      B1*)
        if is_pifive; then
           ORD=0xf461
        else
           ORD=0xf41
        fi
        if ! grep -q "BOOT_ORDER" $EECFG ; then
          sed $EECFG -i -e "\$a[all]\nBOOT_ORDER=${ORD}"
        else
          sed $EECFG -i -e "s/^BOOT_ORDER=.*/BOOT_ORDER=${ORD}/"
        fi
        STATUS="SD Card"
        ;;
      B2*)
        if is_pifive; then
           ORD=0xf146
        else
           ORD=0xf14
        fi
        if ! grep -q "BOOT_ORDER" $EECFG ; then
          sed $EECFG -i -e "\$a[all]\nBOOT_ORDER=${ORD}"
        else
          sed $EECFG -i -e "s/^BOOT_ORDER=.*/BOOT_ORDER=${ORD}/"
        fi
        STATUS="NVMe/USB"
        ;;
      B3*)
        if ! grep -q "BOOT_ORDER" $EECFG ; then
          sed $EECFG -i -e "\$a[all]\nBOOT_ORDER=0xf21"
        else
          sed $EECFG -i -e "s/^BOOT_ORDER=.*/BOOT_ORDER=0xf21/"
        fi
        STATUS="Network"
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
    get_bootloader_filename
    if [ "${FILNAME}" = "none" ]; then
       if [ "$INTERACTIVE" = True ]; then
          return 0
       else
          return 1
       fi
    fi
    rpi-eeprom-config --apply $EECFG $FILNAME
    ASK_TO_REBOOT=1
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "$STATUS is default boot device" 20 60 1
    fi
  fi
}


do_boot_rom() {
  if [ "$INTERACTIVE" = True ]; then
    BOOTOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Bootloader Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "E1 Latest" "Use the latest bootloader image" \
      "E2 Default" "Use the factory default bootloader image" \
      3>&1 1>&2 2>&3)
  else
    BOOTOPT=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$BOOTOPT" in
      E1*)
        sed /etc/default/rpi-eeprom-update -i -e "s/^FIRMWARE_RELEASE_STATUS.*/FIRMWARE_RELEASE_STATUS=\"latest\"/"
        EETYPE="Latest version"
        ;;
      E2*)
        sed /etc/default/rpi-eeprom-update -i -e "s/^FIRMWARE_RELEASE_STATUS.*/FIRMWARE_RELEASE_STATUS=\"default\"/"
        EETYPE="Factory default"
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised bootloader option" 20 60 2
        return 1
        ;;
    esac
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "$EETYPE bootloader selected - will be loaded at next reboot.\n\nReset bootloader to default configuration?" 20 60 2
      DEFAULTS=$?
    else
      DEFAULTS=$2
    fi
    if [ "$DEFAULTS" -eq 0 ]; then # yes
      get_bootloader_filename
      if [ "${FILNAME}" = "none" ]; then
         if [ "$INTERACTIVE" = True ]; then
            return 0
         else
            return 1
         fi
      fi
      rpi-eeprom-update -d -f $FILNAME
      if [ "$INTERACTIVE" = True ]; then
         whiptail --msgbox "Bootloader reset to default configuration" 20 60 2
      fi
    else
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Bootloader not reset to defaults" 20 60 2
      fi
    fi
    ASK_TO_REBOOT=1
  fi
}

get_boot_splash() {
  if is_pi ; then
    if grep -q "splash" $CMDLINE ; then
      echo 0
    else
      echo 1
    fi
  else
    if grep -q "GRUB_CMDLINE_LINUX_DEFAULT.*splash" /etc/default/grub ; then
      echo 0
    else
      echo 1
    fi
  fi
}

do_boot_splash() {
  if [ ! -e /usr/share/plymouth/themes/pix/pix.script ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The splash screen is not installed so cannot be activated" 20 60 2
    fi
    return 1
  fi
  DEFAULT=--defaultno
  if [ $(get_boot_splash) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to show the splash screen at boot?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    if is_pi ; then
      if ! grep -q "splash" $CMDLINE ; then
        sed -i $CMDLINE -e "s/$/ quiet splash plymouth.ignore-serial-consoles/"
      fi
    else
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 quiet splash plymouth.ignore-serial-consoles\"/"
      sed -i /etc/default/grub -e "s/  \+/ /g"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\" /GRUB_CMDLINE_LINUX_DEFAULT=\"/"
      update-grub
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    if is_pi ; then
      if grep -q "splash" $CMDLINE ; then
        sed -i $CMDLINE -e "s/ quiet//"
        sed -i $CMDLINE -e "s/ splash//"
        sed -i $CMDLINE -e "s/ plymouth.ignore-serial-consoles//"
      fi
    else
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)quiet\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)splash\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)plymouth.ignore-serial-consoles\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1\2\"/"
      sed -i /etc/default/grub -e "s/  \+/ /g"
      sed -i /etc/default/grub -e "s/GRUB_CMDLINE_LINUX_DEFAULT=\" /GRUB_CMDLINE_LINUX_DEFAULT=\"/"
      update-grub
    fi
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Splash screen at boot is $STATUS" 20 60 1
  fi
}

get_rgpio() {
  if test -e /etc/systemd/system/pigpiod.service.d/public.conf; then
    echo 0
  else
    echo 1
  fi
}

do_rgpio() {
  DEFAULT=--defaultno
  if [ $(get_rgpio) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the GPIO server to be accessible over the network?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    mkdir -p /etc/systemd/system/pigpiod.service.d/
    cat > /etc/systemd/system/pigpiod.service.d/public.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/bin/pigpiod
EOF
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    rm -f /etc/systemd/system/pigpiod.service.d/public.conf
    STATUS=disabled
  else
    return $RET
  fi
  systemctl daemon-reload
  if systemctl -q is-enabled pigpiod ; then
    systemctl restart pigpiod
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Remote access to the GPIO server is $STATUS" 20 60 1
  fi
}

get_camera() {
  if [ $(deb_ver) -le 10 ]; then
    CAM=$(get_config_var start_x $CONFIG)
    if [ $CAM -eq 1 ]; then
      echo 0
    else
      echo 1
    fi
  else
    if grep -q camera_auto_detect $CONFIG ; then
      CAM=$(get_config_var camera_auto_detect $CONFIG)
      if [ $CAM -eq 1 ]; then
        echo 0
      else
        echo 1
      fi
    else
      echo 0
    fi
  fi
}

do_camera() {
  if [ $(deb_ver) -le 10 ] && [ ! -e /boot${FIRMWARE}/start_x.elf ]; then
    whiptail --msgbox "Your firmware appears to be out of date (no start_x.elf). Please update" 20 60 2
    return 1
  fi
  sed $CONFIG -i -e "s/^startx/#startx/"
  sed $CONFIG -i -e "s/^fixup_file/#fixup_file/"

  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_camera) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the camera interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    if [ $(deb_ver) -le 10 ] ; then
      set_config_var start_x 1 $CONFIG
      CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
      if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
        set_config_var gpu_mem 128 $CONFIG
      fi
    else
      set_config_var camera_auto_detect 1 $CONFIG
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    if [ $(deb_ver) -le 10 ] ; then
      set_config_var start_x 0 $CONFIG
      sed $CONFIG -i -e "s/^start_file/#start_file/"
    else
      set_config_var camera_auto_detect 0 $CONFIG
    fi
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The camera interface is $STATUS" 20 60 1
  fi
}

get_onewire() {
  if grep -q -E "^dtoverlay=w1-gpio" $CONFIG; then
    echo 0
  else
    echo 1
  fi
}

do_onewire() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_onewire) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the one-wire interface to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e "s/^#dtoverlay=w1-gpio/dtoverlay=w1-gpio/"
    if ! grep -q -E "^dtoverlay=w1-gpio" $CONFIG; then
      printf "dtoverlay=w1-gpio\n" >> $CONFIG
    fi
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "s/^dtoverlay=w1-gpio/#dtoverlay=w1-gpio/"
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The one-wire interface is $STATUS" 20 60 1
  fi
}

get_legacy() {
  if sed -n '/\[pi4\]/,/\[/ !p' $CONFIG | grep -q '^dtoverlay=vc4-kms-v3d' ; then
    echo 1
  else
    echo 0
  fi
}

do_legacy() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_legacy) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable legacy camera support?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    sed $CONFIG -i -e '/\[pi4\]/,/\[/ s/^#\?dtoverlay=vc4-f\?kms-v3d/dtoverlay=vc4-fkms-v3d/g'
    sed $CONFIG -i -e '/\[pi4\]/,/\[/ !s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/g'
    sed $CONFIG -i -e '/\[pi4\]/,/\[/ !s/^dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/g'
    if ! sed -n '/\[pi4\]/,/\[/ p' $CONFIG | grep -q '^dtoverlay=vc4-fkms-v3d' ; then
      if grep -q '[pi4]' $CONFIG ; then
        sed $CONFIG -i -e 's/\[pi4\]/\[pi4\]\ndtoverlay=vc4-fkms-v3d/'
      else
        printf "[pi4]\ndtoverlay=vc4-fkms-v3d\n" >> $CONFIG
      fi
    fi
    CUR_GPU_MEM=$(get_config_var gpu_mem $CONFIG)
    if [ -z "$CUR_GPU_MEM" ] || [ "$CUR_GPU_MEM" -lt 128 ]; then
      set_config_var gpu_mem 128 $CONFIG
    fi
    sed $CONFIG -i -e 's/^camera_auto_detect.*/start_x=1/g'
    sed $CONFIG -i -e 's/^dtoverlay=camera/#dtoverlay=camera/g'
    STATUS="Legacy camera support is enabled.\n\nPlease note that this functionality is deprecated and will not be supported for future development."
  else
    sed $CONFIG -i -e 's/^#\?dtoverlay=vc4-f\?kms-v3d/dtoverlay=vc4-kms-v3d/g'
    sed $CONFIG -i -e '/\[pi4\]/,/\[/ {/dtoverlay=vc4-kms-v3d/d}'
    if ! sed -n '/\[pi4\]/,/\[/ !p' $CONFIG | grep -q '^dtoverlay=vc4-kms-v3d' ; then
      if grep -q '[all]' $CONFIG ; then
        sed $CONFIG -i -e 's/\[all\]/\[all\]\ndtoverlay=vc4-kms-v3d/'
      else
        printf "[all]\ndtoverlay=vc4-kms-v3d\n" >> $CONFIG
      fi
    fi
    sed $CONFIG -i -e 's/^start_x.*/camera_auto_detect=1/g'
    sed $CONFIG -i -e 's/^#dtoverlay=camera/dtoverlay=camera/g'
    STATUS="Legacy camera support is disabled."
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "$STATUS" 20 60 1
  fi
}

do_gldriver() {
  if [ ! -e /boot${FIRMWARE}/overlays/vc4-kms-v3d.dtbo ]; then
    whiptail --msgbox "Driver and kernel not present on your system. Please update" 20 60 2
    return 1
  fi
  for package in gldriver-test libgl1-mesa-dri; do
    if [ "$(dpkg -l "$package" 2> /dev/null | tail -n 1 | cut -d ' ' -f 1)" != "ii" ]; then
      missing_packages="$package $missing_packages"
    fi
  done
  if [ -n "$missing_packages" ] && ! apt-get install $missing_packages; then
    whiptail --msgbox "Required packages not found, please install: ${missing_packages}" 20 60 2
    return 1
  fi
  GLOPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "GL Driver" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
    "G1 Legacy" "Original non-GL desktop driver" \
    "G2 GL (Full KMS)" "OpenGL desktop driver with full KMS" \
    3>&1 1>&2 2>&3)
  if [ $? -eq 0 ]; then
    case "$GLOPT" in
      G1*)
        if sed -n "/\[pi4\]/,/\[/ !p" $CONFIG | grep -q -E "^dtoverlay=vc4-f?kms-v3d" ; then
          ASK_TO_REBOOT=1
        fi
        sed $CONFIG -i -e "s/^dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/g"
        sed $CONFIG -i -e "s/^dtoverlay=vc4-kms-v3d/#dtoverlay=vc4-kms-v3d/g"
        STATUS="The GL driver is disabled."
        ;;
      G2*)
        if ! sed -n "/\[pi4\]/,/\[/ !p" $CONFIG | grep -q "^dtoverlay=vc4-kms-v3d" ; then
          ASK_TO_REBOOT=1
        fi
        sed $CONFIG -i -e "s/^dtoverlay=vc4-fkms-v3d/#dtoverlay=vc4-fkms-v3d/g"
        sed $CONFIG -i -e "s/^#dtoverlay=vc4-kms-v3d/dtoverlay=vc4-kms-v3d/g"
        if ! sed -n "/\[pi4\]/,/\[/ !p" $CONFIG | grep -q "^dtoverlay=vc4-kms-v3d" ; then
          printf "[all]\ndtoverlay=vc4-kms-v3d\n" >> $CONFIG
        fi
        STATUS="The full KMS GL driver is enabled."
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
  else
    return 0
  fi
  whiptail --msgbox "$STATUS" 20 60 1
}

do_xcompmgr() {
  DEFAULT=--defaultno
  CURRENT=0
  if [ -e /etc/xdg/autostart/xcompmgr.desktop ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the xcompmgr composition manager to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    if [ ! -e /usr/bin/xcompmgr ] ; then
      apt-get -y install xcompmgr
    fi
    cat << EOF > /etc/xdg/autostart/xcompmgr.desktop
[Desktop Entry]
Type=Application
Name=xcompmgr
Comment=Start xcompmgr compositor
NoDisplay=true
Exec=/usr/lib/raspi-config/cmstart.sh
EOF
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    rm -f /etc/xdg/autostart/xcompmgr.desktop
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The xcompmgr composition manager is $STATUS" 20 60 1
  fi
}

do_glamor() {
  DEFAULT=
  CURRENT=1
  if [ -e /usr/share/X11/xorg.conf.d/20-noglamor.conf ] ; then
    DEFAULT=--defaultno
    CURRENT=0
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like glamor acceleration to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    systemctl disable glamor-test.service
    systemctl stop glamor-test.service
    rm -f /usr/share/X11/xorg.conf.d/20-noglamor.conf
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    systemctl enable glamor-test.service &&
    systemctl start glamor-test.service &&
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Glamor acceleration is $STATUS" 20 60 1
  fi
}

do_wayland() {
  if [ "$INTERACTIVE" = True ]; then
    if [ -f /usr/bin/labwc ]; then
      RET=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Wayland Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
          "W1 X11" "Openbox window manager with X11 backend" \
          "W2 Wayfire" "Wayfire window manager with Wayland backend" \
          "W3 Labwc" "Labwc window manager with Wayland backend" \
          3>&1 1>&2 2>&3)
    else
      RET=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Wayland Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
          "W1 X11" "Openbox window manager with X11 backend" \
          "W2 Wayfire" "Wayfire window manager with Wayland backend" \
          3>&1 1>&2 2>&3)
    fi
  else
    RET=$1
    true
  fi
  if [ $? -eq 0 ]; then
    case "$RET" in
      W1*)
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?user-session.*/user-session=LXDE-pi-x/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?autologin-session.*/autologin-session=LXDE-pi-x/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?greeter-session.*/greeter-session=pi-greeter/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-test.*/#fallback-test=/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-session.*/#fallback-session=/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-greeter.*/#fallback-greeter=/"
        if [ -e "/var/lib/AccountsService/users/$USER" ] ; then
          sed "/var/lib/AccountsService/users/$USER" -i -e "s/XSession=.*/XSession=LXDE-pi-x/"
        fi
        STATUS="Openbox on X11"
        ;;
      W2*)
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?user-session.*/user-session=LXDE-pi-wayfire/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?autologin-session.*/autologin-session=LXDE-pi-wayfire/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?greeter-session.*/greeter-session=pi-greeter-wayfire/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?fallback-test.*/fallback-test=\/usr\/bin\/xfallback.sh/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?fallback-session.*/fallback-session=LXDE-pi-x/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?fallback-greeter.*/fallback-greeter=pi-greeter/"
        if [ -e "/var/lib/AccountsService/users/$USER" ] ; then
          sed "/var/lib/AccountsService/users/$USER" -i -e "s/XSession=.*/XSession=LXDE-pi-wayfire/"
        fi
        STATUS="Wayfire on Wayland"
        ;;
      W3*)
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?user-session.*/user-session=LXDE-pi-labwc/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?autologin-session.*/autologin-session=LXDE-pi-labwc/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^#\\?greeter-session.*/greeter-session=pi-greeter-labwc/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-test.*/#fallback-test=/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-session.*/#fallback-session=/"
        sed /etc/lightdm/lightdm.conf -i -e "s/^fallback-greeter.*/#fallback-greeter=/"
        if [ -e "/var/lib/AccountsService/users/$USER" ] ; then
          sed "/var/lib/AccountsService/users/$USER" -i -e "s/XSession=.*/XSession=LXDE-pi-wayfire/"
        fi
        STATUS="Labwc on Wayland"
        ;;
      *)
        whiptail --msgbox "Programmer error, unrecognised boot option" 20 60 2
        return 1
        ;;
    esac
    ASK_TO_REBOOT=1
  else
    return 0
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "$STATUS is active" 20 60 1
  fi
}

do_audioconf() {
  sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus systemctl --user -q is-enabled pipewire-pulse > /dev/null 2>&1
  PPENABLED=$?
  sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus systemctl --user -q is-enabled pulseaudio > /dev/null 2>&1
  PAENABLED=$?
  if [ "$INTERACTIVE" = True ]; then
    DEFAULT=1
    if [ "$PPENABLED" = 0 ] ; then
      DEFAULT=2
    fi
    if ! is_installed pulseaudio && ! is_installed pipewire-pulse ; then
      whiptail --msgbox "No audio systems installed" 20 60 1
      RET=1
    else
      if is_installed pulseaudio ; then
        OPTIONS="1 PulseAudio"
      fi
      if is_installed pipewire-pulse ; then
        OPTIONS="$OPTIONS 2 Pipewire"
      fi
      #shellcheck disable=2086
      PPOPT=$(whiptail --menu "Select the audio configuration to use" 20 60 10 $OPTIONS --default-item "$DEFAULT" 3>&1 1>&2 2>&3)
      RET="$?"
    fi
  else
    PPOPT="$1"
    RET=0
  fi
  if [ "$RET" -ne 0 ] ; then
    return
  fi

  if [ "$PPOPT" -eq 2 ] ; then # pipewire selected
    systemctl --global -q disable pulseaudio
    systemctl --global -q enable pipewire-pulse
    systemctl --global -q enable wireplumber
    if [ -e /usr/share/doc/pipewire/examples/alsa.conf.d/99-pipewire-default.conf ] ; then
      cp /usr/share/doc/pipewire/examples/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/
    fi
    AUDCON="Pipewire"
    if [ "$PAENABLED" = 0 ] ; then
      ASK_TO_REBOOT=1
    fi
  else # pulse selected
    systemctl --global -q disable pipewire-pulse
    systemctl --global -q disable wireplumber
    systemctl --global -q enable pulseaudio
    if [ -e /etc/alsa/conf.d/99-pipewire-default.conf ] ; then
      rm /etc/alsa/conf.d/99-pipewire-default.conf
    fi
    AUDCON="PulseAudio"
    if [ "$PPENABLED" = 0 ] ; then
      ASK_TO_REBOOT=1
    fi
  fi

  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "$AUDCON is active" 20 60 1
  fi
}

get_net_names() {
  if grep -q "net.ifnames=0" $CMDLINE || \
    ( [ "$(readlink -f /etc/systemd/network/99-default.link)" = "/dev/null" ] && \
      [ "$(readlink -f /etc/systemd/network/73-usb-net-by-mac.link)" = "/dev/null" ] ); then
    echo 1
  else
    echo 0
  fi
}

do_net_names () {
  DEFAULT=--defaultno
  CURRENT=0
  if [ $(get_net_names) -eq 0 ]; then
    DEFAULT=
    CURRENT=1
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like to enable predictable network interface names?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    ASK_TO_REBOOT=1
  fi
  if [ $RET -eq 0 ]; then
    sed -i $CMDLINE -e "s/net.ifnames=0 *//"
    rm -f /etc/systemd/network/99-default.link
    rm -f /etc/systemd/network/73-usb-net-by-mac.link
    STATUS=enabled
  elif [ $RET -eq 1 ]; then
    ln -sf /dev/null /etc/systemd/network/99-default.link
    ln -sf /dev/null /etc/systemd/network/73-usb-net-by-mac.link
    STATUS=disabled
  else
    return $RET
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Predictable network interface names are $STATUS" 20 60 1
  fi
}

do_update() {
  apt-get update &&
  apt-get install raspi-config &&
  printf "Sleeping 5 seconds before reloading raspi-config\n" &&
  sleep 5 &&
  exec raspi-config
}

do_audio() {
  if is_pulseaudio ; then
    oIFS="$IFS"
    if [ "$INTERACTIVE" = True ]; then
      list=$(sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID LANG=C pactl list sinks | grep -e "Sink #" -e "alsa.card_name" | sed s/*//g | sed s/^[' '\\t]*//g | sed s/'Sink #'//g | sed s/'alsa.card_name = '//g | sed s/'bcm2835 '//g | sed s/\"//g | tr '\n' '/')
      if [ -n "$list" ] ; then
        IFS="/"
        AUDIO_OUT=$(whiptail --menu "Choose the audio output" 20 60 10 ${list} 3>&1 1>&2 2>&3)
      else
        whiptail --msgbox "No internal audio devices found" 20 60 1
        return 1
      fi
    else
      AUDIO_OUT=$1
      true
    fi
    if [ $? -eq 0 ]; then
      sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID pactl set-default-sink $AUDIO_OUT
    fi
    IFS="$oIFS"
  else
    if aplay -l | grep -q "bcm2835 ALSA"; then
      if [ "$INTERACTIVE" = True ]; then
        AUDIO_OUT=$(whiptail --menu "Choose the audio output" 20 60 10 \
          "0" "Auto" \
          "1" "Force 3.5mm ('headphone') jack" \
          "2" "Force HDMI" \
          3>&1 1>&2 2>&3)
      else
        AUDIO_OUT=$1
      fi
      if [ "$?" -eq 0 ] && [ -n "$AUDIO_OUT" ]; then
        amixer cset numid=3 "$AUDIO_OUT"
      fi
    else
      ASPATH=$(getent passwd $USER | cut -d : -f 6)/.asoundrc
      if [ "$INTERACTIVE" = True ]; then
        n=0
        array=""
        while [ $n -le 9 ]
        do
          CARD=$(LC_ALL=C aplay -l | grep "card $n" | cut -d [ -f 2 | cut -d ] -f 1)
          if [ -z "$CARD" ] ; then
            break
          else
            if [ -z "$array" ] ; then
              array=$n"/"$CARD
            else
              #shellcheck disable=2027
              array=$array"/"$n"/"$CARD
            fi
          fi
          n=$(( n+1 ))
        done
        if [ $n -eq 0 ] ; then
          whiptail --msgbox "No audio devices found" 20 60 1
          false
        else
          oIFS="$IFS"
          IFS="/"
          AUDIO_OUT=$(whiptail --menu "Choose the audio output" 20 60 10 ${array} 3>&1 1>&2 2>&3)
          IFS="$oIFS"
        fi
      else
        AUDIO_OUT=$1
      fi
      if [ "$?" -eq 0 ] && [ -n "$AUDIO_OUT" ]; then
        cat << EOF > $ASPATH
pcm.!default {
  type asym
  playback.pcm {
    type plug
    slave.pcm "output"
  }
  capture.pcm {
    type plug
    slave.pcm "input"
  }
}

pcm.output {
  type hw
  card $AUDIO_OUT
}

ctl.!default {
  type hw
  card $AUDIO_OUT
}
EOF
      fi
    fi
  fi
}

do_resolution() {
  if [ "$INTERACTIVE" = True ]; then
    CMODE=$(get_config_var hdmi_mode $CONFIG)
    CGROUP=$(get_config_var hdmi_group $CONFIG)
    if [ $CMODE -eq 0 ] ; then
      CSET="Default"
    elif [ $CGROUP -eq 2 ] ; then
      CSET="DMT Mode "$CMODE
    else
      CSET="CEA Mode "$CMODE
    fi
    oIFS="$IFS"
    IFS="/"
    if tvservice -d /dev/null | grep -q Nothing ; then
      value="Default/720x480/DMT Mode 4/640x480 60Hz 4:3/DMT Mode 9/800x600 60Hz 4:3/DMT Mode 16/1024x768 60Hz 4:3/DMT Mode 85/1280x720 60Hz 16:9/DMT Mode 35/1280x1024 60Hz 5:4/DMT Mode 51/1600x1200 60Hz 4:3/DMT Mode 82/1920x1080 60Hz 16:9/"
    else
      value="Default/Monitor preferred resolution/"
      value=$value$(tvservice -m CEA | grep progressive | cut -b 12- | sed 's/mode \([0-9]\+\): \([0-9]\+\)x\([0-9]\+\) @ \([0-9]\+\)Hz \([0-9]\+\):\([0-9]\+\), clock:[0-9]\+MHz progressive/CEA Mode \1\/\2x\3 \4Hz \5:\6/' | tr '\n' '/')
      value=$value$(tvservice -m DMT | grep progressive | cut -b 12- | sed 's/mode \([0-9]\+\): \([0-9]\+\)x\([0-9]\+\) @ \([0-9]\+\)Hz \([0-9]\+\):\([0-9]\+\), clock:[0-9]\+MHz progressive/DMT Mode \1\/\2x\3 \4Hz \5:\6/' | tr '\n' '/')
    fi
    RES=$(whiptail --default-item $CSET --menu "Choose screen resolution" 20 60 10 ${value} 3>&1 1>&2 2>&3)
    STATUS=$?
    IFS="$oIFS"
    if [ $STATUS -eq 0 ] ; then
      GRS=$(echo "$RES" | cut -d ' ' -f 1)
      MODE=$(echo "$RES" | cut -d ' ' -f 3)
      if [ $GRS = "Default" ] ; then
        MODE=0
      elif [ $GRS = "DMT" ] ; then
        GROUP=2
      else
        GROUP=1
      fi
    fi
  else
    GROUP=$1
    MODE=$2
    STATUS=0
  fi
  if [ $STATUS -eq 0 ]; then
    if [ $MODE -eq 0 ]; then
      clear_config_var hdmi_force_hotplug $CONFIG
      clear_config_var hdmi_group $CONFIG
      clear_config_var hdmi_mode $CONFIG
    else
      set_config_var hdmi_force_hotplug 1 $CONFIG
      set_config_var hdmi_group $GROUP $CONFIG
      set_config_var hdmi_mode $MODE $CONFIG
    fi
    if [ "$INTERACTIVE" = True ]; then
      if [ $MODE -eq 0 ] ; then
        whiptail --msgbox "The resolution is set to default" 20 60 1
      else
        whiptail --msgbox "The resolution is set to $GRS mode $MODE" 20 60 1
      fi
    fi
    if [ $MODE -eq 0 ] ; then
      TSET="Default"
    elif [ $GROUP -eq 2 ] ; then
      TSET="DMT Mode "$MODE
    else
      TSET="CEA Mode "$MODE
    fi
    if [ "$TSET" != "$CSET" ] ; then
      ASK_TO_REBOOT=1
    fi
  fi
}

get_vnc_resolution() {
  if is_wayfire ; then
    W=$(grep ^headless_width $WAYFIRE_FILE | grep -o "[0-9]*")
    H=$(grep ^headless_height $WAYFIRE_FILE | grep -o "[0-9]*")
    if [ -n "$W" ] && [ -n "$H" ] ; then
      echo $W"x"$H
    else
      echo "1280x720"
    fi
  else
    if [ -e /etc/xdg/autostart/vnc_xrandr.desktop ] ; then
      grep fb /etc/xdg/autostart/vnc_xrandr.desktop | cut -f 15 -d ' '
    else
      echo ""
    fi
  fi
}

do_vnc_resolution() {
  if [ "$INTERACTIVE" = True ]; then
    CUR=$(get_vnc_resolution)
    if [ "$CUR" = "" ] ; then
      CUR=640x480
    fi
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --default-item $CUR --menu "Set VNC Resolution" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "640x480" "" "720x480" "" "800x600" "" "1024x768" "" "1280x720" "" "1280x1024" "" "1600x1200" "" "1920x1080" "" 3>&1 1>&2 2>&3)
    RET=$?
  else
    FUN=$1
    RET=0
  fi
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    if is_wayfire ; then
      W=$(echo "$FUN" | cut -d x -f 1)
      H=$(echo "$FUN" | cut -d x -f 2)
      if grep -q ^headless_width $WAYFIRE_FILE ; then
        sed -i "s/headless_width.*/headless_width = $W/" $WAYFIRE_FILE
        sed -i "s/headless_height.*/headless_height = $H/" $WAYFIRE_FILE
      else
        if grep -q "\[output\]" $WAYFIRE_FILE ; then
          sed -i "s/\[output]/[output]\nheadless_width = $W\nheadless_height = $H/" $WAYFIRE_FILE
        else
          printf '\n[output]\nheadless_width = %d\nheadless_height = %d\n' "$W" "$H" >> $WAYFIRE_FILE
        fi
      fi
    else
      cat > /etc/xdg/autostart/vnc_xrandr.desktop << EOF
[Desktop Entry]
Type=Application
Name=vnc_xrandr
Comment=Set resolution for VNC
NoDisplay=true
Exec=sh -c "if ! (xrandr | grep -q -w connected) ; then /usr/bin/xrandr --fb $FUN ; fi"
EOF
    fi
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The resolution is set to $FUN" 20 60 1
      ASK_TO_REBOOT=1
    fi
  fi
}

list_wlan_interfaces() {
  for dir in /sys/class/net/*/wireless; do
    if [ -d "$dir" ]; then
      IFACE="$(basename "$(dirname "$dir")")"
      if wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
        echo "$IFACE"
      fi
    fi
  done
}

do_wifi_ssid_passphrase() {
  RET=0
  if [ "$INTERACTIVE" = True ] && [ -z "$(get_wifi_country)" ]; then
    do_wifi_country
  fi

  if systemctl -q is-active dhcpcd; then
    IFACE="$(list_wlan_interfaces | head -n 1)"

    if [ -z "$IFACE" ]; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "No wireless interface found" 20 60
      fi
      return 1
    fi

    if ! wpa_cli -i "$IFACE" status > /dev/null 2>&1; then
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Could not communicate with wpa_supplicant" 20 60
      fi
      return 1
    fi
  elif ! systemctl -q is-active NetworkManager; then
    if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "No supported network connection manager found" 20 60
      fi
      return 1
  fi

  SSID="$1"
  while [ -z "$SSID" ] && [ "$INTERACTIVE" = True ]; do
    if ! SSID=$(whiptail --inputbox "Please enter SSID" 20 60 3>&1 1>&2 2>&3); then
      return 0
    elif [ -z "$SSID" ]; then
      whiptail --msgbox "SSID cannot be empty. Please try again." 20 60
    fi
  done

  PASSPHRASE="$2"
  while [ "$INTERACTIVE" = True ]; do
    if ! PASSPHRASE=$(whiptail --passwordbox "Please enter passphrase. Leave it empty if none." 20 60 3>&1 1>&2 2>&3); then
      return 0
    else
      break
    fi
  done

  # Escape special characters for embedding in regex below
  ssid="$(echo "$SSID" \
   | sed 's;\\;\\\\;g' \
   | sed -e 's;\.;\\\.;g' \
         -e 's;\*;\\\*;g' \
         -e 's;\+;\\\+;g' \
         -e 's;\?;\\\?;g' \
         -e 's;\^;\\\^;g' \
         -e 's;\$;\\\$;g' \
         -e 's;\/;\\\/;g' \
         -e 's;\[;\\\[;g' \
         -e 's;\];\\\];g' \
         -e 's;{;\\{;g'   \
         -e 's;};\\};g'   \
         -e 's;(;\\(;g'   \
         -e 's;);\\);g'   \
         -e 's;";\\\\\";g')"

  HIDDEN=${3:-0}
  PLAIN=${4:-1}

  if systemctl -q is-active dhcpcd; then
    wpa_cli -i "$IFACE" list_networks \
     | tail -n +2 | cut -f -2 | grep -P "\t$ssid$" | cut -f1 \
     | while read -r ID; do
      wpa_cli -i "$IFACE" remove_network "$ID" > /dev/null 2>&1
    done

    ID="$(wpa_cli -i "$IFACE" add_network)"
    wpa_cli -i "$IFACE" set_network "$ID" ssid "\"$SSID\"" 2>&1 | grep -q "OK"
    RET=$((RET + $?))

    if [ -z "$PASSPHRASE" ]; then
      wpa_cli -i "$IFACE" set_network "$ID" key_mgmt NONE 2>&1 | grep -q "OK"
      RET=$((RET + $?))
    else
      if [ "$PLAIN" = 1 ]; then
        PASSPHRASE="\"$PASSPHRASE\""
      fi
      wpa_cli -i "$IFACE" set_network "$ID" psk "$PASSPHRASE" 2>&1 | grep -q "OK"
      RET=$((RET + $?))
    fi
    if [ "$HIDDEN" -ne 0 ]; then
      wpa_cli -i "$IFACE" set_network "$ID" scan_ssid 1 2>&1 | grep -q "OK"
      RET=$((RET + $?))
    fi
    if [ $RET -eq 0 ]; then
      wpa_cli -i "$IFACE" enable_network "$ID" > /dev/null 2>&1
    else
      wpa_cli -i "$IFACE" remove_network "$ID" > /dev/null 2>&1
      if [ "$INTERACTIVE" = True ]; then
        whiptail --msgbox "Failed to set SSID or passphrase" 20 60
      fi
    fi
    wpa_cli -i "$IFACE" save_config > /dev/null 2>&1
    echo "$IFACE_LIST" | while read -r IFACE; do
      wpa_cli -i "$IFACE" reconfigure > /dev/null 2>&1
    done
  else
    IFACE="$(list_wlan_interfaces | head -n 1)"
    if [ "$HIDDEN" -ne 0 ]; then
      nmcli device wifi connect "$SSID" password "$PASSPHRASE" ifname "${IFACE}" hidden true | grep -q "activated"
    else
      nmcli device wifi connect "$SSID" password "$PASSPHRASE" ifname "${IFACE}" | grep -q "activated"
    fi
    RET=$((RET + $?))
  fi

  return "$RET"
}

do_finish() {
  disable_raspi_config_at_boot
  if [ $ASK_TO_REBOOT -eq 1 ]; then
    whiptail --yesno "Would you like to reboot now?" 20 60 2
    if [ $? -eq 0 ]; then # yes
      sync
      reboot
    fi
  fi
  exit 0
}

# $1 = filename, $2 = key name
get_json_string_val() {
  sed -n -e "s/^[[:space:]]*\"$2\"[[:space:]]*:[[:space:]]*\"\(.*\)\"[[:space:]]*,$/\1/p" $1
}

# TODO: This is probably broken
do_apply_os_config() {
  [ -e /boot/os_config.json ] || return 0
  NOOBSFLAVOUR=$(get_json_string_val /boot/os_config.json flavour)
  NOOBSLANGUAGE=$(get_json_string_val /boot/os_config.json language)
  NOOBSKEYBOARD=$(get_json_string_val /boot/os_config.json keyboard)

  if [ -n "$NOOBSFLAVOUR" ]; then
    printf "Setting flavour to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSFLAVOUR"

    printf "Unrecognised flavour. Ignoring\n"
  fi

  # TODO: currently ignores en_gb settings as we assume we are running in a
  # first boot context, where UK English settings are default
  case "$NOOBSLANGUAGE" in
    "en")
      if [ "$NOOBSKEYBOARD" = "gb" ]; then
        DEBLANGUAGE="" # UK english is the default, so ignore
      else
        DEBLANGUAGE="en_US.UTF-8"
      fi
      ;;
    "de")
      DEBLANGUAGE="de_DE.UTF-8"
      ;;
    "fi")
      DEBLANGUAGE="fi_FI.UTF-8"
      ;;
    "fr")
      DEBLANGUAGE="fr_FR.UTF-8"
      ;;
    "hu")
      DEBLANGUAGE="hu_HU.UTF-8"
      ;;
    "ja")
      DEBLANGUAGE="ja_JP.UTF-8"
      ;;
    "nl")
      DEBLANGUAGE="nl_NL.UTF-8"
      ;;
    "pt")
      DEBLANGUAGE="pt_PT.UTF-8"
      ;;
    "ru")
      DEBLANGUAGE="ru_RU.UTF-8"
      ;;
    "zh_CN")
      DEBLANGUAGE="zh_CN.UTF-8"
      ;;
    *)
      printf "Language '%s' not handled currently. Run sudo raspi-config to set up" "$NOOBSLANGUAGE"
      ;;
  esac

  if [ -n "$DEBLANGUAGE" ]; then
    printf "Setting language to %s based on os_config.json from NOOBS. May take a while\n" "$DEBLANGUAGE"
    do_change_locale "$DEBLANGUAGE"
  fi

  if [ -n "$NOOBSKEYBOARD" -a "$NOOBSKEYBOARD" != "gb" ]; then
    printf "Setting keyboard layout to %s based on os_config.json from NOOBS. May take a while\n" "$NOOBSKEYBOARD"
    do_configure_keyboard "$NOOBSKEYBOARD"
  fi
  return 0
}

get_overlay_now() {
  grep -q "overlayroot=tmpfs" /proc/cmdline
  echo $?
}

get_overlay_conf() {
  grep -q "overlayroot=tmpfs" $CMDLINE
  echo $?
}

get_bootro_now() {
  findmnt /boot${FIRMWARE} | grep -q " ro,"
  echo $?
}

get_bootro_conf() {
  grep /boot${FIRMWARE} /etc/fstab | grep -q "defaults.*,ro[ ,]"
  echo $?
}

is_uname_current() {
  test -d "/lib/modules/$(uname -r)"
}

enable_overlayfs() {
  if [ "$(awk '/MemTotal/{print $2; exit}' /proc/meminfo)" -le 262144 ]; then
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "At least 512MB of RAM is recommended for overlay filesystem" 20 60 1
    else
      echo "At least 512MB of RAM is recommended for overlay filesystem"
    fi
    return 1
  fi
  is_installed overlayroot || apt-get install -y overlayroot
  # mount the boot partition as writable if it isn't already
  if [ $(get_bootro_now) -eq 0 ] ; then
    if ! mount -o remount,rw /boot${FIRMWARE} 2>/dev/null ; then
      echo "Unable to mount boot partition as writable - cannot enable"
      return 1
    fi
    BOOTRO=yes
  else
    BOOTRO=no
  fi

  # modify command line
  if ! grep -q "overlayroot=tmpfs" $CMDLINE ; then
    sed -i $CMDLINE -e "s/^/overlayroot=tmpfs /"
  fi

  if [ "$BOOTRO" = "yes" ] ; then
    if ! mount -o remount,ro /boot${FIRMWARE} 2>/dev/null ; then
      echo "Unable to remount boot partition as read-only"
    fi
  fi
}

disable_overlayfs() {
  # mount the boot partition as writable if it isn't already
  if [ $(get_bootro_now) -eq 0 ] ; then
    if ! mount -o remount,rw /boot${FIRMWARE} 2>/dev/null ; then
      echo "Unable to mount boot partition as writable - cannot disable"
      return 1
    fi
    BOOTRO=yes
  else
    BOOTRO=no
  fi

  # modify command line
  sed -i $CMDLINE -e "s/\(.*\)overlayroot=tmpfs \(.*\)/\1\2/"

  if [ "$BOOTRO" = "yes" ] ; then
    if ! mount -o remount,ro /boot${FIRMWARE} 2>/dev/null ; then
      echo "Unable to remount boot partition as read-only"
    fi
  fi
}

enable_bootro() {
  if [ $(get_overlay_now) -eq 0 ] ; then
    echo "Overlay in use; cannot update fstab"
    return 1
  fi
  sed -i /etc/fstab -e "s#\(.*/boot$FIRMWARE.*\)defaults\(.*\)#\1defaults,ro\2#"
}

disable_bootro() {
  if [ $(get_overlay_now) -eq 0 ] ; then
    echo "Overlay in use; cannot update fstab"
    return 1
  fi
  sed -i /etc/fstab -e "s#\(.*/boot$FIRMWARE.*\)defaults,ro\(.*\)#\1defaults\2#"
}

do_overlayfs() {
  DEFAULT=--defaultno
  CURRENT=0
  STATUS="disabled"

  if [ "$INTERACTIVE" = True ] && ! is_uname_current; then
    whiptail --msgbox "Could not find modules for the running kernel ($(uname -r))." 20 60 1
    return 1
  fi

  if [ $(get_overlay_conf) -eq 0 ] ; then
    DEFAULT=
    CURRENT=1
    STATUS="enabled"
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the overlay file system to be enabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq $CURRENT ]; then
    if [ $RET -eq 0 ]; then
      if enable_overlayfs; then
        STATUS="enabled"
        ASK_TO_REBOOT=1
      else
        STATUS="unchanged"
      fi
    elif [ $RET -eq 1 ]; then
      if disable_overlayfs; then
        STATUS="disabled"
        ASK_TO_REBOOT=1
      else
        STATUS="unchanged"
      fi
    else
      return $RET
    fi
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The overlay file system is $STATUS." 20 60 1
  fi
  if [ $(get_overlay_now) -eq 0 ] ; then
    if [ $(get_bootro_conf) -eq 0 ] ; then
      BPRO="read-only"
    else
      BPRO="writable"
    fi
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The boot partition is currently $BPRO. This cannot be changed while an overlay file system is enabled." 20 60 1
    fi
  else
    DEFAULT=--defaultno
    CURRENT=0
    STATUS="writable"
    if [ $(get_bootro_conf) -eq 0 ]; then
      DEFAULT=
      CURRENT=1
      STATUS="read-only"
    fi
    if [ "$INTERACTIVE" = True ]; then
      whiptail --yesno "Would you like the boot partition to be write-protected?" $DEFAULT 20 60 2
      RET=$?
    else
      RET=$1
    fi
    if [ $RET -eq $CURRENT ]; then
      if [ $RET -eq 0 ]; then
        if enable_bootro; then
          STATUS="read-only"
          ASK_TO_REBOOT=1
        else
          STATUS="unchanged"
        fi
      elif [ $RET -eq 1 ]; then
        if disable_bootro; then
          STATUS="writable"
          ASK_TO_REBOOT=1
        else
          STATUS="unchanged"
        fi
      else
        return $RET
      fi
    fi
    if [ "$INTERACTIVE" = True ]; then
      whiptail --msgbox "The boot partition is $STATUS." 20 60 1
    fi
  fi
}

get_proxy() {
  SCHEME="$1"
  VAR_NAME="${SCHEME}_proxy"
  if [ -f /etc/profile.d/proxy.sh ]; then
    # shellcheck disable=SC1091
    . /etc/profile.d/proxy.sh
  fi
  eval "echo \$$VAR_NAME"
}

do_proxy() {
  SCHEMES="$1"
  ADDRESS="$2"
  if [ "$SCHEMES" = "all" ]; then
    CURRENT="$(get_proxy http)"
    SCHEMES="http https ftp rsync"
  else
    CURRENT="$(get_proxy "$SCHEMES")"
  fi
  if [ "$INTERACTIVE" = True ]; then
    if [ "$SCHEMES" = "no" ]; then
      STRING="Please enter a comma separated list of addresses that should be excluded from using proxy servers.\\nEg: localhost,127.0.0.1,localaddress,.localdomain.com"
    else
      STRING="Please enter proxy address.\\nEg: http://user:pass@proxy:8080"
    fi
    if ! ADDRESS="$(whiptail --inputbox "$STRING"  20 60 "$CURRENT" 3>&1 1>&2 2>&3)"; then
      return 0
    fi
  fi
  for SCHEME in $SCHEMES; do
    unset "${SCHEME}_proxy"
    CURRENT="$(get_proxy "$SCHEME")"
    if [ "$CURRENT" != "$ADDRESS" ]; then
      ASK_TO_REBOOT=1
    fi
    if [ -f /etc/profile.d/proxy.sh ]; then
      sed -i "/^export ${SCHEME}_/Id" /etc/profile.d/proxy.sh
    fi
    if [ "${SCHEME#*http}" != "$SCHEME" ]; then
      if [ -f /etc/apt/apt.conf.d/01proxy ]; then
        sed -i "/::${SCHEME}::Proxy/d" /etc/apt/apt.conf.d/01proxy
      fi
    fi
    if [ -z "$ADDRESS" ]; then
      STATUS=cleared
      continue
    fi
    STATUS=updated
    SCHEME_UPPER="$(echo "$SCHEME" | tr '[:lower:]' '[:upper:]')"
    echo "export ${SCHEME_UPPER}_PROXY=\"$ADDRESS\"" >> /etc/profile.d/proxy.sh
    if [ "$SCHEME" != "rsync" ]; then
      echo "export ${SCHEME}_proxy=\"$ADDRESS\"" >> /etc/profile.d/proxy.sh
    fi
    if [ "${SCHEME#*http}" != "$SCHEME" ]; then
      echo "Acquire::$SCHEME::Proxy \"$ADDRESS\";"  >> /etc/apt/apt.conf.d/01proxy
    fi
  done
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "Proxy settings $STATUS" 20 60 1
  fi
}

get_usb_current() {
  USB=$(get_config_var usb_max_current_enable $CONFIG)
  if [ $USB -eq 1 ]; then
    echo 0
  else
    echo 1
  fi
}

do_usb_current() {
  DEFAULT=--defaultno
  if [ $(get_usb_current) -eq 0 ]; then
    DEFAULT=
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --yesno "Would you like the USB current limit to be disabled?" $DEFAULT 20 60 2
    RET=$?
  else
    RET=$1
  fi
  if [ $RET -eq 0 ]; then
    set_config_var usb_max_current_enable 1 $CONFIG &&
    STATUS=disabled
  elif [ $RET -eq 1 ]; then
    sed $CONFIG -i -e "/usb_max_current_enable.*/d"
    STATUS=enabled
  else
    return $RET
  fi


  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The USB current limit is $STATUS" 20 60 1
  fi
}

get_squeekboard() {
  if ! is_installed squeekboard ; then
    echo 2
  elif [ -e /etc/xdg/autostart/squeekboard.desktop ] ; then
    if grep -q sbtest /etc/xdg/autostart/squeekboard.desktop ; then
      echo 1
    else
      echo 0
    fi
  else
    echo 2
  fi
}

do_squeekboard() {
  if [ "$INTERACTIVE" = True ]; then
    OPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "On-screen Keyboard" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      "S1 Always On" "On-screen keyboard always enabled" \
      "S2 Autodetect" "On-screen keyboard enabled if touch device found" \
      "S3 Always Off" "On-screen keyboard disabled" \
      3>&1 1>&2 2>&3)
  else
    OPT=$1
    true
  fi
  case "$OPT" in
    S1*)
      is_installed squeekboard || apt-get install -y squeekboard
      cat > /etc/xdg/autostart/squeekboard.desktop << EOF
[Desktop Entry]
Name=Squeekboard
Comment=Launch the on-screen keyboard
Exec=/usr/bin/sbout
Terminal=false
Type=Application
NoDisplay=true
EOF
      sed -i '/sbtest/d' /usr/share/labwc/autostart
      if ! grep -q sbout /usr/share/labwc/autostart ; then
        echo "/usr/bin/sbout &" >> /usr/share/labwc/autostart
      fi
      PREFIX=""
      if [ -n "$SUDO_USER" ] ; then
        PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
      fi
      $PREFIX sbout > /dev/null 2> /dev/null &
      STATUS="enabled"
      ;;
    S2*)
      is_installed squeekboard || apt-get install -y squeekboard
      cat > /etc/xdg/autostart/squeekboard.desktop << EOF
[Desktop Entry]
Name=Squeekboard
Comment=Launch the on-screen keyboard
Exec=/usr/bin/sbtest
Terminal=false
Type=Application
NoDisplay=true
EOF
      sed -i '/sbout/d' /usr/share/labwc/autostart
      if ! grep -q sbtest /usr/share/labwc/autostart ; then
        echo "/usr/bin/sbtest &" >> /usr/share/labwc/autostart
      fi
      PREFIX=""
      if [ -n "$SUDO_USER" ] ; then
        PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
      fi
      pkill squeekboard
      $PREFIX sbtest > /dev/null 2> /dev/null &
      STATUS="using autodetect"
      ;;
    S3*)
      pkill squeekboard
      rm -f /etc/xdg/autostart/squeekboard.desktop
      sed -i '/sbout/d' /usr/share/labwc/autostart
      sed -i '/sbtest/d' /usr/share/labwc/autostart
      STATUS="disabled"
      ;;
    *)
      return $OPT
      ;;
  esac
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The onscreen keyboard is $STATUS" 20 60 1
  fi
}

get_squeek_output (){
  if [ -e /usr/share/squeekboard/output ] ; then
    echo `grep SQUEEKBOARD_PREFERRED_OUTPUT /usr/share/squeekboard/output | cut -d = -f 2`
  else
    echo ""
  fi
}

do_squeek_output() {
  PREFIX=""
  if [ -n "$SUDO_USER" ] ; then
    PREFIX="sudo -u $USER XDG_RUNTIME_DIR=/run/user/$SUDO_UID DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$SUDO_UID/bus "
  fi
  if [ "$INTERACTIVE" = True ]; then
    menu=$($PREFIX wlr-randr | grep -v ^' ' | cut -d ' ' -f 1 | tr '\n' '/' | sed 's#/#//#g')
    oIFS="$IFS"
    IFS="/"
    OPT=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Select where the on-screen keyboard is to be shown" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT \
      ${menu} \
      3>&1 1>&2 2>&3)
    IFS="$oIFS"
  else
    OPT=$1
    true
  fi
  mkdir -p /usr/share/squeekboard/
  echo "#!/bin/sh\nexport SQUEEKBOARD_PREFERRED_OUTPUT=$OPT" > /usr/share/squeekboard/output
  chmod a+x /usr/share/squeekboard/output
  if pgrep sbtest > /dev/null ; then
    pkill squeekboard
    $PREFIX sbtest > /dev/null 2> /dev/null &
  elif pgrep squeekboard > /dev/null ; then
    pkill squeekboard
    $PREFIX sbout > /dev/null 2> /dev/null &
  fi
  if [ "$INTERACTIVE" = True ]; then
    whiptail --msgbox "The onscreen keyboard is on $OPT" 20 60 1
  fi
}

nonint() {
  "$@"
}

#
# Command line options for non-interactive use
#
for i in $*
do
  case $i in
  --memory-split)
    OPT_MEMORY_SPLIT=GET
    printf "Not currently supported\n"
    exit 1
    ;;
  --memory-split=*)
    OPT_MEMORY_SPLIT=$(echo $i | sed 's/[-a-zA-Z0-9]*=//')
    printf "Not currently supported\n"
    exit 1
    ;;
  --expand-rootfs)
    INTERACTIVE=False
    do_expand_rootfs
    printf "Please reboot\n"
    exit 0
    ;;
  --apply-os-config)
    INTERACTIVE=False
    do_apply_os_config
    exit $?
    ;;
  nonint)
    INTERACTIVE=False
    #echo "$@"
    "$@"
    exit $?
    ;;
  *)
    # unknown option
    ;;
  esac
done

#if [ "GET" = "${OPT_MEMORY_SPLIT:-}" ]; then
#  set -u # Fail on unset variables
#  get_current_memory_split
#  echo $CURRENT_MEMSPLIT
#  exit 0
#fi

# Everything else needs to be run as root
if [ $(id -u) -ne 0 ]; then
  printf "Script must be run as root. Try 'sudo raspi-config'\n"
  exit 1
fi

if [ -n "${OPT_MEMORY_SPLIT:-}" ]; then
  set -e # Fail when a command errors
  set_memory_split "${OPT_MEMORY_SPLIT}"
  exit 0
fi

do_system_menu() {
  if is_pi ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "System Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "S1 Wireless LAN" "Enter SSID and passphrase" \
      "S2 Audio" "Select audio out through HDMI or 3.5mm jack" \
      "S3 Password" "Change password for the '$USER' user" \
      "S4 Hostname" "Set name for this computer on a network" \
      "S5 Boot / Auto Login" "Select boot into desktop or to command line" \
      "S6 Splash Screen" "Choose graphical splash screen or text boot" \
      "S7 Power LED" "Set behaviour of power LED" \
      "S8 Browser" "Choose default web browser" \
      "S9 Logging" "Set storage location for logs" \
      3>&1 1>&2 2>&3)
  elif is_live ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "System Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "S1 Wireless LAN" "Enter SSID and passphrase" \
      "S3 Password" "Change password for the '$USER' user" \
      "S4 Hostname" "Set name for this computer on a network" \
      "S5 Boot / Auto Login" "Select boot into desktop or to command line" \
      3>&1 1>&2 2>&3)
  else
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "System Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "S1 Wireless LAN" "Enter SSID and passphrase" \
      "S3 Password" "Change password for the '$USER' user" \
      "S4 Hostname" "Set name for this computer on a network" \
      "S5 Boot / Auto Login" "Select boot into desktop or to command line" \
      "S6 Splash Screen" "Choose graphical splash screen or text boot" \
      3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      S1\ *) do_wifi_ssid_passphrase ;;
      S2\ *) do_audio ;;
      S3\ *) do_change_pass ;;
      S4\ *) do_hostname ;;
      S5\ *) do_boot_behaviour ;;
      S6\ *) do_boot_splash ;;
      S7\ *) do_leds ;;
      S8\ *) do_browser ;;
      S9\ *) do_journald_storage ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_display_menu() {
  if is_pi ; then
    if is_wayland; then
      if is_pifour; then
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Display Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "D2 Screen Blanking" "Enable/disable screen blanking" \
          "D4 Composite" "Enable/disable composite output" \
          "D5 4Kp60 HDMI" "Enable 4Kp60 resolution on HDMI0" \
          "D6 Onscreen Keyboard" "Enable on-screen keyboard" \
          "D7 Keyboard Output" "Select monitor used for on-screen keyboard" \
          3>&1 1>&2 2>&3)
      else
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Display Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "D2 Screen Blanking" "Enable/disable screen blanking" \
          "D4 Composite" "Enable/disable composite output" \
          "D6 Onscreen Keyboard" "Enable on-screen keyboard" \
          "D7 Keyboard Output" "Select monitor used for on-screen keyboard" \
          3>&1 1>&2 2>&3)
      fi
    else
      if is_pifour; then
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Display Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "D1 Underscan" "Remove black border around screen" \
          "D2 Screen Blanking" "Enable/disable screen blanking" \
          "D3 VNC Resolution" "Set resolution for headless use" \
          "D4 Composite" "Enable/disable composite output" \
          "D5 4Kp60 HDMI" "Enable 4Kp60 resolution on HDMI0" \
          3>&1 1>&2 2>&3)
      else
        FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Display Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "D1 Underscan" "Remove black border around screen" \
          "D2 Screen Blanking" "Enable/disable screen blanking" \
          "D3 VNC Resolution" "Set resolution for headless use" \
          "D4 Composite" "Enable/disable composite output" \
          3>&1 1>&2 2>&3)
      fi
    fi
  else
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Display Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "D1 Underscan" "Remove black border around screen" \
      "D2 Screen Blanking" "Enable/disable screen blanking" \
      3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      D1\ *) do_overscan_kms ;;
      D2\ *) do_blanking ;;
      D3\ *) do_vnc_resolution ;;
      D4\ *) do_composite ;;
      D5\ *) do_pi4video ;;
      D6\ *) do_squeekboard ;;
      D7\ *) do_squeek_output ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_interface_menu() {
  if is_pi ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Interfacing Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "I1 SSH" "Enable/disable remote command line access using SSH" \
      "I2 RPi Connect" "Enable/disable Raspberry Pi Connect" \
      "I3 VNC" "Enable/disable graphical remote desktop access" \
      "I4 SPI" "Enable/disable automatic loading of SPI kernel module" \
      "I5 I2C" "Enable/disable automatic loading of I2C kernel module" \
      "I6 Serial Port" "Enable/disable shell messages on the serial connection" \
      "I7 1-Wire" "Enable/disable one-wire interface" \
      "I8 Remote GPIO" "Enable/disable remote access to GPIO pins" \
      3>&1 1>&2 2>&3)
  else
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Interfacing Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "I2 SSH" "Enable/disable remote command line access using SSH" \
      3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      I1\ *) do_ssh ;;
      I2\ *) do_rpi_connect ;;
      I3\ *) do_vnc ;;
      I4\ *) do_spi ;;
      I5\ *) do_i2c ;;
      I6\ *) if is_pifive ; then do_serial_pi5 ; else do_serial ; fi ;;
      I7\ *) do_onewire ;;
      I8\ *) do_rgpio ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_performance_menu() {
  case "$(get_pi_type)" in
    [03]) FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "P2 Overlay File System" "Enable/disable read-only file system" \
          3>&1 1>&2 2>&3) ;;
    [12]) FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "P1 Overclock" "Configure CPU overclocking" \
          "P2 Overlay File System" "Enable/disable read-only file system" \
          3>&1 1>&2 2>&3) ;;
    4) FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "P2 Overlay File System" "Enable/disable read-only file system" \
          "P3 Fan" "Set behaviour of GPIO case fan" \
          3>&1 1>&2 2>&3) ;;
    *) FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Performance Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
          "P2 Overlay File System" "Enable/disable read-only file system" \
          "P4 USB Current" "Set USB current limit" \
          3>&1 1>&2 2>&3) ;;
  esac
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      P1\ *) do_overclock ;;
      P2\ *) do_overlayfs ;;
      P3\ *) do_fan ;;
      P4\ *) do_usb_current ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_internationalisation_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Localisation Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "L1 Locale" "Configure language and regional settings" \
    "L2 Timezone" "Configure time zone" \
    "L3 Keyboard" "Set keyboard layout to match your keyboard" \
    "L4 WLAN Country" "Set legal wireless channels for your country" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      L1\ *) do_change_locale ;;
      L2\ *) do_change_timezone ;;
      L3\ *) do_configure_keyboard ;;
      L4\ *) do_wifi_country ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_advanced_menu() {
  if gpu_has_mmu ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "A1 Expand Filesystem" "Ensures that all of the SD card is available" \
      "A2 Network Interface Names" "Enable/disable predictable network i/f names" \
      "A3 Network Proxy Settings" "Configure network proxy settings" \
      "A4 Boot Order" "Choose SD, network, USB or NVMe device boot priority" \
      "A5 Bootloader Version" "Select latest or factory default bootloader software" \
      "A6 Wayland" "Switch between X and Wayland backends" \
      "A7 Audio Config" "Set audio control system" \
      "A8 PCIe Speed" "Set PCIe x1 port speed" \
      "A9 Network install UI" "Select when to display the bootloader network-install UI" \
      3>&1 1>&2 2>&3)
  elif is_pi ; then
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "A1 Expand Filesystem" "Ensures that all of the SD card is available" \
      "A2 Network Interface Names" "Enable/disable predictable network i/f names" \
      "A3 Network Proxy Settings" "Configure network proxy settings" \
      "A6 Wayland" "Switch between X and Wayland backends" \
      "A7 Audio Config" "Set audio control system" \
      3>&1 1>&2 2>&3)
  else
    FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Advanced Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
      "A2 Network Interface Names" "Enable/disable predictable network i/f names" \
      "A3 Network Proxy Settings" "Configure network proxy settings" \
      "A6 Wayland" "Switch between X and Wayland backends" \
      "A7 Audio Config" "Set audio control system" \
      3>&1 1>&2 2>&3)
  fi
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      A1\ *) do_expand_rootfs ;;
      A2\ *) do_net_names ;;
      A3\ *) do_proxy_menu ;;
      A4\ *) do_boot_order ;;
      A5\ *) do_boot_rom ;;
      A6\ *) do_wayland ;;
      A7\ *) do_audioconf ;;
      A8\ *) do_pci ;;
      A9\ *) do_network_install_ui ;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

do_proxy_menu() {
  FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Network Proxy Settings" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Back --ok-button Select \
    "P1 All" "Set the same proxy for all schemes" \
    "P2 HTTP" "Set the HTTP proxy" \
    "P3 HTTPS" "Set the HTTPS/SSL proxy" \
    "P4 FTP" "Set the FTP proxy" \
    "P5 RSYNC" "Set the RSYNC proxy" \
    "P6 Exceptions" "Set addresses for which a proxy server should not be used" \
    3>&1 1>&2 2>&3)
  RET=$?
  if [ $RET -eq 1 ]; then
    return 0
  elif [ $RET -eq 0 ]; then
    case "$FUN" in
      P1\ *) do_proxy all ;;
      P2\ *) do_proxy http ;;
      P3\ *) do_proxy https ;;
      P4\ *) do_proxy ftp ;;
      P5\ *) do_proxy rsync ;;
      P6\ *) do_proxy no;;
      *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
    esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
  fi
}

#
# Interactive use loop
#
if [ "$INTERACTIVE" = True ]; then
  [ -e $CONFIG ] || touch $CONFIG
  calc_wt_size
  while [ "$USER" = "root" ] || [ -z "$USER" ]; do
    if ! USER=$(whiptail --inputbox "raspi-config could not determine the default user.\\n\\nWhat user should these settings apply to?" 20 60 pi 3>&1 1>&2 2>&3); then
      return 0
    fi
  done
  while true; do
    if is_pi ; then
      MEMSIZE=$(vcgencmd get_config total_mem|cut -d= -f2)
      if [ $MEMSIZE -lt 1024 ]; then
        FMEMSIZE="${MEMSIZE}MB"
      else
        FMEMSIZE="$(expr $MEMSIZE / 1024)GB"
      fi
      FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --backtitle "$(cat /proc/device-tree/model), ${FMEMSIZE}" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 System Options" "Configure system settings" \
        "2 Display Options" "Configure display settings" \
        "3 Interface Options" "Configure connections to peripherals" \
        "4 Performance Options" "Configure performance settings" \
        "5 Localisation Options" "Configure language and regional settings" \
        "6 Advanced Options" "Configure advanced settings" \
        "8 Update" "Update this tool to the latest version" \
        "9 About raspi-config" "Information about this configuration tool" \
        3>&1 1>&2 2>&3)
    else
      FUN=$(whiptail --title "Raspberry Pi Software Configuration Tool (raspi-config)" --menu "Setup Options" $WT_HEIGHT $WT_WIDTH $WT_MENU_HEIGHT --cancel-button Finish --ok-button Select \
        "1 System Options" "Configure system settings" \
        "2 Display Options" "Configure display settings" \
        "3 Interface Options" "Configure connections to peripherals" \
        "5 Localisation Options" "Configure language and regional settings" \
        "6 Advanced Options" "Configure advanced settings" \
        "8 Update" "Update this tool to the latest version" \
        "9 About raspi-config" "Information about this configuration tool" \
        3>&1 1>&2 2>&3)
    fi
    RET=$?
    if [ $RET -eq 1 ]; then
      do_finish
    elif [ $RET -eq 0 ]; then
      case "$FUN" in
        1\ *) do_system_menu ;;
        2\ *) do_display_menu ;;
        3\ *) do_interface_menu ;;
        4\ *) do_performance_menu ;;
        5\ *) do_internationalisation_menu ;;
        6\ *) do_advanced_menu ;;
        8\ *) do_update ;;
        9\ *) do_about ;;
        *) whiptail --msgbox "Programmer error: unrecognized option" 20 60 1 ;;
      esac || whiptail --msgbox "There was an error running option $FUN" 20 60 1
    else
      exit 1
    fi
  done
fi
