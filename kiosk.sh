#!/bin/bash

# --------------------------------------------------------------------------------
#  kiosk.sh
# --------------------------------------------------------------------------------
#  Raspberry Pi based Kiosks
# 
#  Displays HTML kiosks or RTSP camera feeds in a mosaic on a Raspberry Pi
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------
# 

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

# execute
case $kiosk in
    cameras-01-02)
        ffplay rtsp://root:missionav@10.100.1.108/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.114/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.124/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.123/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    cameras-03-04)
        ffplay rtsp://root:missionav@10.100.1.117/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.115/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.125/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.107/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    cameras-05-06)
        ffplay rtsp://root:missionav@10.200.30.144/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.221/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.126/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.150/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    cameras-07-08)
        ffplay rtsp://root:missionav@10.100.1.127/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.100.1.120/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.200.30.220/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  -vf "transpose=1, transpose=1" &
        ffplay rtsp://root:missionav@10.200.30.143/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    cameras-09-10)
        ffplay rtsp://root:missionav@10.100.1.128/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.119/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.112/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.110/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    cameras-11-12)
        ffplay rtsp://root:missionav@10.100.1.129/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    &
        ffplay rtsp://root:missionav@10.100.1.118/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
        ffplay rtsp://root:missionav@10.100.1.111/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  &
        ffplay rtsp://root:missionav@10.100.1.113/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
        ;;

    kiosk-01)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=580&synchronization_code=90916-52342&key=e47b9a7553a35065e5d07080be5b44be8b0b23a3c50ba65b76bacd913b24ceedd823c6df667698ce9daabaf61004b7af769a27721a7786f9463767ea65271a29
        ;;

    kiosk-02)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=581&synchronization_code=79844-79798&key=f76346c1cb478b51a00f86f04003efe9f7492853635869241e8023ec1dcce1313c467df3b81923adb937ddcf348306b12642596ad73da15e6a4540e0d5f8f82c
        ;;

    kiosk-03)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=582&synchronization_code=47046-59070&key=06aebbbc2e3ec279f2425f445f63905ba1fd2877c1bf1d0c0784b4c0a2581508962c710963b6595d31508fda66a93dda3d3264cdd4c459e7f26e4e200fb6b508
        ;;

    kiosk-04)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=583&synchronization_code=42516-49612&key=929c5a1ae3047f41bff52ebe83de8b92aae2c075c2a3bae068d4639d629b9a281a374e7a160eaf21f0fb841488cd4969b5e79e9163601a72ebf4003d5792a520
        ;;

    kiosk-05)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=584&synchronization_code=89508-53109&key=d486ba58b0975cf4594ca8a6d389b72b23e871b9ed4b0f3c6cc60856fd967e1118574582e2d8d92ee4812e60d10ad8f764ddc5364c6db8291f14a1f3f3462186
        ;;

    kiosk-06)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=585&synchronization_code=75085-20998&key=58117483a3132ce3c538c8d6ded2a9c16c4b632d035e90e18ca8e66791c92c0b6d9178b7231e30175706f798bc5f85d5adedc78741e8cb7ec1f7ab1d1fc51340
        ;;

    kiosk-07)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=586&synchronization_code=63205-29238&key=b02243ab0855fe738cef40726f3af4c488cffea3e8671330741337bac05e748b4bb0e4bc588279db110de585840e20e996557f9e8bb2e5658f18f35bae670c9f
        ;;

    kiosk-08)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=587&synchronization_code=38669-85267&key=97881d7fdffe1ce5c13e677a7ae535de5702e15e712bca27a46e572e922c9da77e718971d8cef4e5605f0a61b45647967d13d46580907119ac5ad3b19f66e321
        ;;

    kiosk-09)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=588&synchronization_code=47002-78953&key=7d2b240e215df37deee5e6edafac9d3d5ae47806a5a1f97eb25dd1bdbcc2d3c3f4ab6de17d5a790344be28743b79cdbb736dbb10c8eb2d8f9688c9c53f0c1702
        ;;

    kiosk-10)
    	/usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://marquee.csekcreative.com/launch/display.php?device_id=589&synchronization_code=52534-29094&key=3a766a6bc120708ba0d71410b3b5cc3b9ec0f6a8ea7025c0675fb61e93fad30ba64792ab0c7cec8dd0711dccbbc07743f2b2e73a09be776c5c1fe7e0e1b8593c
        ;;

    *)
        /usr/bin/chromium-browser --noerrdialogs --disable-infobars --kiosk https://whatismyipaddress.com/
        ;;
esac

# keep process alive
while true; do
   sleep 10
done
