#!/bin/bash
# --------------------------------------------------------------------------------
#  deploy.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
#
#  Centralised deploy script. Runs administrative actions across all Pi kiosks
#  defined in pi-hosts.txt without needing to SSH into each one individually.
#
#  Run from your local Mac/Linux machine:
#    chmod +x deploy.sh
#    ./deploy.sh
#
#  Version 1.1
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------------------
HOSTS_FILE="$(dirname "$0")/pi-hosts.txt"
SSH_USER="kcckiosk"
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5"

# --------------------------------------------------------------------------------
# check dependencies
# --------------------------------------------------------------------------------
if ! command -v sshpass &> /dev/null; then
    echo "ERROR: sshpass is required but not installed."
    echo "Install it with: brew install sshpass"
    exit 1
fi

if [ ! -f "$HOSTS_FILE" ]; then
    echo "ERROR: Hosts file not found: $HOSTS_FILE"
    exit 1
fi

# --------------------------------------------------------------------------------
# load hosts (skip comments and blank lines)
# --------------------------------------------------------------------------------
mapfile -t HOSTS < <(grep -v '^\s*#' "$HOSTS_FILE" | grep -v '^\s*$')

if [ ${#HOSTS[@]} -eq 0 ]; then
    echo "ERROR: No hosts found in $HOSTS_FILE"
    echo "Add Pi IP addresses to pi-hosts.txt to get started."
    exit 1
fi

# --------------------------------------------------------------------------------
# display loaded hosts
# --------------------------------------------------------------------------------
echo ""
echo "=================================================="
echo "  KCC Pi Kiosk Deploy"
echo "=================================================="
echo ""
echo "Loaded ${#HOSTS[@]} Pi(s) from $HOSTS_FILE:"
echo ""
for HOST in "${HOSTS[@]}"; do
    IP=$(echo $HOST | awk '{print $1}')
    NAME=$(echo $HOST | awk '{print $2}')
    echo "  $NAME ($IP)"
done
echo ""

# --------------------------------------------------------------------------------
# display menu
# --------------------------------------------------------------------------------
# prompt for password
read -s -p "SSH Password: " SSH_PASS
echo ""
echo ""

echo "Actions:"
echo ""
echo "  1) Auto Update   — pull latest files from GitHub"
echo "  2) Install       — reinstall services and cron entries"
echo "  3) Reboot        — reboot all Pis"
echo "  4) Update & Install — auto update then reinstall (recommended after a release)"
echo ""
read -p "Select an action [1-4]: " ACTION
echo ""

case $ACTION in
    1) ACTION_LABEL="Auto Update" ;;
    2) ACTION_LABEL="Install" ;;
    3) ACTION_LABEL="Reboot" ;;
    4) ACTION_LABEL="Update & Install" ;;
    *) echo "Invalid selection. Exiting."; exit 1 ;;
esac

# --------------------------------------------------------------------------------
# confirm
# --------------------------------------------------------------------------------
read -p "Run '$ACTION_LABEL' on all ${#HOSTS[@]} Pi(s)? [y/N]: " CONFIRM
echo ""

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

# --------------------------------------------------------------------------------
# execute action on each Pi
# --------------------------------------------------------------------------------
SUCCESS=0
FAILED=0

for HOST in "${HOSTS[@]}"; do
    IP=$(echo $HOST | awk '{print $1}')
    NAME=$(echo $HOST | awk '{print $2}')

    echo "--------------------------------------------------"
    echo "  $NAME ($IP)"
    echo "--------------------------------------------------"

    case $ACTION in
        1)
            # auto update - pull latest files from GitHub
            sshpass -p "$SSH_PASS" ssh $SSH_OPTS ${SSH_USER}@${IP} \
                'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service     --no-verbose -O /home/kcckiosk/kiosk.service &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh      --no-verbose -O /home/kcckiosk/kiosk.run.sh &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.env         --no-verbose -O /home/kcckiosk/kiosk.env &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/wifi-watchdog.sh  --no-verbose -O /home/kcckiosk/wifi-watchdog.sh &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/unclutter.service --no-verbose -O /home/kcckiosk/unclutter.service &&
                 echo "Auto update complete"'
            ;;
        2)
            # install - reinstall services and cron
            sshpass -p "$SSH_PASS" ssh $SSH_OPTS ${SSH_USER}@${IP} \
                'sudo systemctl daemon-reload &&
                 sudo systemctl enable kiosk.service &&
                 sudo systemctl enable unclutter.service &&
                 (echo "0 7 * * * /sbin/shutdown -r now"; echo "*/15 * * * * /bin/bash /home/kcckiosk/wifi-watchdog.sh") | crontab - &&
                 echo "Install complete"'
            ;;
        3)
            # reboot
            sshpass -p "$SSH_PASS" ssh $SSH_OPTS ${SSH_USER}@${IP} \
                'echo "Rebooting..." && sudo /sbin/shutdown -r now'
            ;;
        4)
            # update & install
            sshpass -p "$SSH_PASS" ssh $SSH_OPTS ${SSH_USER}@${IP} \
                'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service     --no-verbose -O /home/kcckiosk/kiosk.service &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh      --no-verbose -O /home/kcckiosk/kiosk.run.sh &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.env         --no-verbose -O /home/kcckiosk/kiosk.env &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/wifi-watchdog.sh  --no-verbose -O /home/kcckiosk/wifi-watchdog.sh &&
                 wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/unclutter.service --no-verbose -O /home/kcckiosk/unclutter.service &&
                 sudo systemctl daemon-reload &&
                 sudo systemctl enable kiosk.service &&
                 sudo systemctl enable unclutter.service &&
                 (echo "0 7 * * * /sbin/shutdown -r now"; echo "*/15 * * * * /bin/bash /home/kcckiosk/wifi-watchdog.sh") | crontab - &&
                 echo "Update & install complete"'
            ;;
    esac

    if [ $? -eq 0 ]; then
        echo "  ✓ Success"
        ((SUCCESS++))
    else
        echo "  ✗ Failed — could not connect or command failed"
        ((FAILED++))
    fi

    echo ""
done

# --------------------------------------------------------------------------------
# summary
# --------------------------------------------------------------------------------
echo "=================================================="
echo "  Complete: $SUCCESS succeeded, $FAILED failed"
echo "=================================================="
echo ""
