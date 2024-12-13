#!/bin/bash

# read config variable
kiosk=$(cat /home/kcckiosk/kiosk.config)

# set xwindows variables
xset s noblank
xset s off
xset -dpms

# hide the mouse
unclutter -idle 0.5 -root &

# fix chromium errors that may distrupt
sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' /home/$USER/.config/chromium/Default/Preferences
sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' /home/$USER/.config/chromium/Default/Preferences

case $kiosk in
  camera12)
	ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
	ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
	ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
	ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
	;;

  camera34)
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
        ;;

  camera56)
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
        ;;

  camera78)
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
        ;;

  camera910)
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
        ;;

  camera1112)
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0   &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540 &
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0   & 
        ffplay /home/kcckiosk/bigbuckbunny_30sclip.mp4 -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540 &
        ;;

  kiosk1)
	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://www.gareth.com
	;;

  *)
        /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
	;;
esac

while true; do
   sleep 10
done
