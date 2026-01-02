row=320

#sheet 1
ffplay rtsp://root:missionav@10.100.1.108/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 0))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.114/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 0))   -top $((row * 1))  -vf "transpose=1" &

#sheet 2
ffplay rtsp://root:missionav@10.100.1.124/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 1))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.123/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 1))   -top $((row * 1))  -vf "transpose=1" &

#sheet 3
ffplay rtsp://root:missionav@10.100.1.117/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 2))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.115/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 2))   -top $((row * 1))  -vf "transpose=1" &

#sheet 4
ffplay rtsp://root:missionav@10.100.1.125/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 3))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.107/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 3))   -top $((row * 1))  -vf "transpose=1" &    

#sheet 5
ffplay rtsp://root:missionav@10.200.30.144/axis-media/media.amp  -an -noborder -alwaysontop -x $width  -left $((width * 4))   -top $((row * 0))  -vf "transpose=3" &
ffplay rtsp://root:missionav@10.200.30.221/axis-media/media.amp  -an -noborder -alwaysontop -x $width  -left $((width * 4))   -top $((row * 1))  -vf "transpose=1" &

#sheet 6
ffplay rtsp://root:missionav@10.100.1.126/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 5))   -top $((row * 0))  -vf "transpose=3" &
ffplay rtsp://root:missionav@10.200.30.150/axis-media/media.amp  -an -noborder -alwaysontop -x $width  -left $((width * 5))   -top $((row * 1))  -vf "transpose=1" &
q
#sheet 7
ffplay rtsp://root:missionav@10.100.1.127/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 6))   -top $((row * 0))  -vf "transpose=3" &
ffplay rtsp://root:missionav@10.100.1.120/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 6))   -top $((row * 1))  -vf "transpose=1" &

#sheet 8
ffplay rtsp://root:missionav@10.200.30.220/axis-media/media.amp  -an -noborder -alwaysontop -x $width  -left $((width * 7))   -top $((row * 0))  -vf "transpose=3" &
ffplay rtsp://root:missionav@10.200.30.143/axis-media/media.amp  -an -noborder -alwaysontop -x $width  -left $((width * 7))   -top $((row * 1))  -vf "transpose=1" &

#sheet 9
ffplay rtsp://root:missionav@10.100.1.128/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 8))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.119/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 8))   -top $((row * 1))  -vf "transpose=1" &

#sheet 10
ffplay rtsp://root:missionav@10.100.1.112/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 9))   -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.110/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 9))   -top $((row * 1))  -vf "transpose=1" &

#sheet 11
ffplay rtsp://root:missionav@10.100.1.129/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 10))  -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.118/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 10))  -top $((row * 1))  -vf "transpose=1" &

#sheet 12
ffplay rtsp://root:missionav@10.100.1.111/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 11))  -top $((row * 0))  -vf "transpose=1" &
ffplay rtsp://root:missionav@10.100.1.113/axis-media/media.amp   -an -noborder -alwaysontop -x $width  -left $((width * 11))  -top $((row * 1))  -vf "transpose=1" &
