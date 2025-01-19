# pi-kiosk
Raspberry PI Kiosk Cofiguration for Kelowna Curling Club
Scripts and instructions to automatically build raspberry pi kiosks

## Pre-requisites
Image Raspberry Pi with full desktop image
Settings - 
- Configure account as kcckiosk and enabling auto login.
- Configure correct Wifi details.
- Configure correct hostname
- Enable ssh

## Install
`code` /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.sh)"
