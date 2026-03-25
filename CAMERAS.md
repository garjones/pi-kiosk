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
| 1  | 10.100.1.51 | 10.100.1.71 |
| 2  | 10.100.1.52 | 10.100.1.72 |
| 3  | 10.100.1.53 | 10.100.1.73 |
| 4  | 10.100.1.54 | 10.100.1.74 |
| 5  | 10.100.1.55 | 10.100.1.75 |
| 6  | 10.100.1.56 | 10.100.1.76 |
| 7  | 10.100.1.57 | 10.100.1.77 |
| 8  | 10.100.1.58 | 10.100.1.78 |
| 9  | 10.100.1.59 | 10.100.1.79 |
| 10 | 10.100.1.60 | 10.100.1.80 |
| 11 | 10.100.1.61 | 10.100.1.81 |
| 12 | 10.100.1.62 | 10.100.1.82 |

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
| `10.100.1.51–62` | Home cameras, sheets 1–12 |
| `10.100.1.71–82` | Away cameras, sheets 1–12 |

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