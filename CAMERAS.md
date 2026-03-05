# KCC Pi Kiosk — Camera Reference

Axis IP camera assignments for all 12 curling sheets at Kelowna Curling Club.

All cameras are accessed via RTSP:
```
rtsp://<username>:<password>@<ip-address>/axis-media/media.amp
```

Credentials are stored in `kiosk.env`.

---

## Camera Map

| Sheet | Home Camera IP | Away Camera IP |
|---|---|---|
| 1  | 10.100.1.114 | 10.100.1.108 |
| 2  | 10.100.1.123 | 10.100.1.124 |
| 3  | 10.100.1.115 | 10.100.1.117 |
| 4  | 10.100.1.107 | 10.100.1.125 |
| 5  | 10.200.30.221 | 10.200.30.144 |
| 6  | 10.200.30.150 | 10.100.1.126 |
| 7  | 10.100.1.120 | 10.100.1.127 |
| 8  | 10.200.30.143 | 10.200.30.220 |
| 9  | 10.100.1.119 | 10.100.1.128 |
| 10 | 10.100.1.110 | 10.100.1.112 |
| 11 | 10.100.1.118 | 10.100.1.129 |
| 12 | 10.100.1.113 | 10.100.1.111 |

---

## TV Screen Assignments

| Screen | Sheets Displayed | Config Code |
|---|---|---|
| TV 1 | Sheets 1 & 2 | C0102 |
| TV 2 | Sheets 3 & 4 | C0304 |
| TV 3 | Sheets 5 & 6 | C0506 |
| TV 4 | Sheets 7 & 8 | C0708 |
| TV 5 | Sheets 9 & 10 | C0910 |
| TV 6 | Sheets 11 & 12 | C1112 |

---

## Subnets

| Subnet | Cameras |
|---|---|
| `10.100.1.x` | Sheets 1–4, 7, 9–12 |
| `10.200.30.x` | Sheets 5, 6, 8 |

---

## Troubleshooting a Camera

If a specific camera feed is black or not loading:

1. Identify the sheet and camera position (Home or Away) from the table above
2. Confirm the Pi can reach the camera IP:
```bash
ping <camera-ip>
```
3. Test the RTSP stream directly:
```bash
ffplay rtsp://<username>:<password>@<camera-ip>/axis-media/media.amp
```
4. If unreachable, check the camera's network connection and power
5. If the IP has changed, update `kiosk.env` in GitHub — all Pis will pick up the change on the next SSH login

---

*© Gareth Jones — gareth@gareth.com*
