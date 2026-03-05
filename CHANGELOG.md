# Changelog

All notable changes to the KCC Pi Kiosk project are documented here.

---

## [v9.1] — Current

### Added
- `kiosk.env` — new centralised config file committed to GitHub containing camera credentials (`CAM_USER`, `CAM_PASS`), home camera IPs (`CAM_HOME[]`), away camera IPs (`CAM_AWAY[]`), and kiosk advertising URLs (`URL_KIOSK[]`)
- `kiosk.run.sh` now sources `kiosk.env` at startup and builds RTSP URLs dynamically using credentials and IPs from that file
- `kiosk.run.sh` falls back to `whatismyipaddress.com` error screen if `kiosk.env` is missing on boot

### Changed
- `do_auto_update()` in `kiosk.sh` now downloads `kiosk.env` from GitHub alongside `kiosk.run.sh`, `kiosk.service`, and `unclutter.service` — ensuring all Pis receive config changes automatically on the next SSH login
- Camera credentials and IPs removed from `kiosk.run.sh` — now sourced entirely from `kiosk.env`
- Kiosk advertising URLs removed from `kiosk.run.sh` — now sourced entirely from `kiosk.env`
- `kiosk.run.sh` updated to version 8

---

## [v9.0]

### Added
- Single Sheet camera mode (`S`) — displays Home and Away cameras for one sheet only, with blank panels in the top half of the screen
- Sheet number label rendered in the centre column between camera feeds
- IP address bar displayed along the bottom of the screen (using `do_labelip`)
- Screen rotation support — Horizontal (`H`) and Vertical (`V`) modes, applying `transpose` filter to labels when vertical
- `do_labelip` function renders "Kelowna Curling Club" alongside the Pi's IP address
- Dev/Mac mode — substitutes `tiny-test.mp4` for all RTSP streams and uses Google Chrome instead of Chromium when not running on a Pi
- Fallback error mode — displays `whatismyipaddress.com` when config is unrecognised
- `cameras-all.sh` script to test all 24 cameras

### Changed
- Config file format extended to 6-character code: `{Rotation}{Mode}{Sheet1}{Sheet2}` (e.g. `HC0102`)
- `do_label` and `do_labelip` now accept a rotation parameter passed through from the config
- `kiosk.sh` menu title updated to `v8.3`
- `kiosk.run.sh` updated to version 7

---

## [v8.0]

### Added
- Kiosk / advertising mode (`K`) — launches Chromium in fullscreen kiosk mode pointing at the club's advertising display URLs
- Two kiosk channels: Upstairs (`K01`) and Practice Ice Downstairs (`K02`)
- `do_kiosk` function handles Chromium launch with `--noerrdialogs --disable-infobars --kiosk` flags
- Chromium crash recovery — on startup, `Preferences` file is patched to clear `exited_cleanly:false` and `exit_type:Crashed` flags

### Changed
- Config mode character expanded to support `K` in addition to `C`

---

## [v7.0]

### Added
- Club Cameras mode (`C`) — displays a 2×2 mosaic of Home and Away camera feeds for two curling sheets simultaneously
- Pre-defined sheet pairs in menu: 1&2, 3&4, 5&6, 7&8, 9&10, 11&12
- Custom Cameras option — operator can manually enter any two sheet numbers
- `do_video` function launches `ffplay` RTSP streams positioned and sized to fill screen quadrants
- `do_label` function draws sheet number labels in the centre column using `ffplay` and `ffmpeg` `drawtext` filter
- Screen resolution auto-detected on Pi using `kmsprint`
- Layout calculations for video width, height, position derived from screen resolution at runtime

### Changed
- Usable screen height reduced by label bar height to accommodate bottom IP bar

---

## [v6.0]

### Added
- `do_auto_update` — on every SSH login, latest `kiosk.run.sh`, `kiosk.service`, and `unclutter.service` are downloaded from GitHub before the menu is shown
- `do_install` function — installs `kiosk.service` and `unclutter.service` as systemd services, adds daily 7:00 AM reboot to cron, disables default desktop autostart, and configures menu to auto-launch on SSH login via `.bashrc`
- `unclutter.service` — hides mouse cursor after idle period
- `kiosk.service` — systemd service to launch `kiosk.run.sh` on boot
- Software Update menu option (`P5`) — runs `apt autoremove`, `apt update`, `apt upgrade`, and installs `unclutter`
- Raspberry Pi Config menu option (`P6`) — opens `raspi-config`
- Reboot menu option (`P8`)

---

## [v5.0]

### Added
- Single Camera menu (`P2`) — lists all 12 sheets individually for single-sheet display
- `do_write_config` — prompts for confirmation, writes config to `/home/kcckiosk/kiosk.config`, syncs filesystem, and reboots
- Config written as a single line and read back by `kiosk.run.sh` on next boot

---

## [v4.0]

### Added
- `whiptail`-based TUI menu system for SSH configuration
- Main menu with named options and Cancel/Quit handling
- Club Cameras menu (`P1`) with pre-defined sheet pair options
- `do_menu_custom_cameras` — freeform input for bottom and top sheet numbers

---

## [v3.0]

### Added
- RTSP camera URL arrays defined for all 12 Home and Away cameras
- Cameras distributed across two subnets: `10.100.1.x` and `10.200.30.x`
- Axis camera streams accessed via `rtsp://root:missionav@<ip>/axis-media/media.amp`

---

## [v2.0]

### Added
- Initial `kiosk.run.sh` display script
- Basic `ffplay` invocation to display a single video stream fullscreen

---

## [v1.0] — Initial Release

### Added
- Initial project structure
- `kiosk.sh` configuration script skeleton
- README with prerequisites and one-liner install command
- `.gitignore`

---

*© Gareth Jones — gareth@gareth.com*
