# rotate #1 & #3
ffplay rtsp://root:missionav@10.100.1.127/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 0    -vf "transpose=1, transpose=1" &
ffplay rtsp://root:missionav@10.100.1.120/axis-media/media.amp   -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 0    &
ffplay rtsp://root:missionav@10.200.30.220/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 0   -top 540  -vf "transpose=1, transpose=1"  &
ffplay rtsp://root:missionav@10.200.30.143/axis-media/media.amp  -an -noborder -alwaysontop -x 960 -y 540 -left 960 -top 540  &
