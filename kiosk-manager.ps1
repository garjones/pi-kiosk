#!/usr/bin/env pwsh
# --------------------------------------------------------------------------------
#  kiosk-manager.ps1
# --------------------------------------------------------------------------------
#  KCC Pi Kiosk — Windows Management Tool
#
#  GUI-based management tool for the Kelowna Curling Club Pi Kiosk fleet.
#
#  Features:
#    - Fleet monitoring (ping + SSH port check per Pi)
#    - Software updates (push latest files from GitHub to all Pis)
#    - Remote configuration (set display mode on any Pi)
#    - Remote reboot (one Pi or all Pis)
#    - Camera viewer (all 24 feeds via ffplay/xstack)
#
#  Requirements:
#    - PowerShell 5.1 or later (built into Windows 10/11)
#    - plink.exe  (from PuTTY) — for SSH commands
#    - ffplay.exe (from FFmpeg) — for camera viewer
#    - pi-hosts.txt  — list of Pi IPs and hostnames
#    - kiosk.env     — camera credentials and IPs
#
#  Place plink.exe and ffplay.exe either:
#    a) In the same folder as this script, or
#    b) Somewhere on your system PATH
#
#  Version 1.0
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

# --------------------------------------------------------------------------------
# configuration
# --------------------------------------------------------------------------------
$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$HOSTS_FILE  = Join-Path $SCRIPT_DIR "pi-hosts.txt"
$ENV_FILE    = Join-Path $SCRIPT_DIR "kiosk.env"
$SSH_USER    = "kcckiosk"
$SSH_PASS    = "kcc12345"
$SSH_PORT    = 22
$SCRN_WIDTH  = 1920
$SCRN_HEIGHT = 1080

# tool paths — looks in script folder first, then falls back to PATH
function Find-Tool($name) {
    $local = Join-Path $SCRIPT_DIR $name
    if (Test-Path $local) { return $local }
    $inPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

$PLINK  = Find-Tool "plink.exe"
$FFPLAY = Find-Tool "ffplay.exe"

# --------------------------------------------------------------------------------
# load pi-hosts.txt
# --------------------------------------------------------------------------------
function Load-Hosts {
    if (-not (Test-Path $HOSTS_FILE)) { return @() }
    $hosts = @()
    foreach ($line in Get-Content $HOSTS_FILE) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        $parts = $line -split '\s+'
        if ($parts.Count -ge 2) {
            $hosts += [PSCustomObject]@{ IP = $parts[0]; Name = $parts[1] }
        }
    }
    return $hosts
}

# --------------------------------------------------------------------------------
# load kiosk.env  (parse bash-style key=value and arrays)
# --------------------------------------------------------------------------------
function Load-Env {
    $env = @{
        CAM_USER = ""
        CAM_PASS = ""
        CAM_HOME = @("") * 13   # index 1-12
        CAM_AWAY = @("") * 13
    }
    if (-not (Test-Path $ENV_FILE)) { return $env }

    $homeList = @()
    $awayList = @()
    $inHome   = $false
    $inAway   = $false

    foreach ($line in Get-Content $ENV_FILE) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }

        if ($line -match '^CAM_USER="?([^"]*)"?') { $env.CAM_USER = $Matches[1]; continue }
        if ($line -match '^CAM_PASS="?([^"]*)"?') { $env.CAM_PASS = $Matches[1]; continue }

        if ($line -match '^CAM_HOME=\(')  { $inHome = $true;  $inAway = $false; continue }
        if ($line -match '^CAM_AWAY=\(')  { $inAway = $true;  $inHome = $false; continue }

        if ($inHome -or $inAway) {
            if ($line -eq ")") { $inHome = $false; $inAway = $false; continue }
            $ip = $line -replace '"','' -replace "'",''
            if ($ip -ne "") {
                if ($inHome) { $homeList += $ip }
                else         { $awayList += $ip }
            }
        }
    }

    # homeList[0] is the blank placeholder "", so index 1 = sheet 1
    $env.CAM_HOME = $homeList
    $env.CAM_AWAY = $awayList
    return $env
}

# --------------------------------------------------------------------------------
# SSH helper — run a command on a remote Pi via plink
# --------------------------------------------------------------------------------
function Invoke-SSH($ip, $command) {
    if (-not $PLINK) {
        return [PSCustomObject]@{ Success = $false; Output = "plink.exe not found" }
    }
    try {
        $output = & $PLINK -ssh -pw $SSH_PASS -batch -P $SSH_PORT "${SSH_USER}@${ip}" $command 2>&1
        return [PSCustomObject]@{ Success = ($LASTEXITCODE -eq 0); Output = ($output -join "`n") }
    } catch {
        return [PSCustomObject]@{ Success = $false; Output = $_.Exception.Message }
    }
}

# --------------------------------------------------------------------------------
# ping check
# --------------------------------------------------------------------------------
function Test-Ping($ip) {
    $result = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
    return $result
}

# --------------------------------------------------------------------------------
# SSH port check
# --------------------------------------------------------------------------------
function Test-SSHPort($ip) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect($ip, $SSH_PORT, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait) { $tcp.EndConnect($conn); $tcp.Close(); return $true }
        $tcp.Close()
        return $false
    } catch { return $false }
}

# --------------------------------------------------------------------------------
# GUI helpers
# --------------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$FONT_TITLE  = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$FONT_NORMAL = New-Object System.Drawing.Font("Segoe UI", 9)
$FONT_MONO   = New-Object System.Drawing.Font("Consolas", 9)
$COLOR_BG    = [System.Drawing.Color]::FromArgb(240, 240, 240)
$COLOR_HDR   = [System.Drawing.Color]::FromArgb(30,  80,  140)
$COLOR_WHITE = [System.Drawing.Color]::White
$COLOR_GREEN = [System.Drawing.Color]::FromArgb(0,  160,  80)
$COLOR_RED   = [System.Drawing.Color]::FromArgb(200,  40,  40)
$COLOR_AMBER = [System.Drawing.Color]::FromArgb(200, 140,   0)
$COLOR_GRAY  = [System.Drawing.Color]::FromArgb(140, 140, 140)

function New-Button($text, $x, $y, $w, $h) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text     = $text
    $btn.Location = New-Object System.Drawing.Point($x, $y)
    $btn.Size     = New-Object System.Drawing.Size($w, $h)
    $btn.Font     = $FONT_NORMAL
    $btn.FlatStyle = [System.Windows.Forms.FlatStyle]::System
    return $btn
}

function New-Label($text, $x, $y, $w, $h, $font, $color) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $text
    $lbl.Location  = New-Object System.Drawing.Point($x, $y)
    $lbl.Size      = New-Object System.Drawing.Size($w, $h)
    $lbl.Font      = if ($font)  { $font }  else { $FONT_NORMAL }
    $lbl.ForeColor = if ($color) { $color } else { [System.Drawing.Color]::Black }
    $lbl.AutoSize  = $false
    return $lbl
}

# --------------------------------------------------------------------------------
# status dot panel for a Pi row
# --------------------------------------------------------------------------------
function Add-StatusRow($panel, $pi, $y) {
    # name
    $name = New-Label $pi.Name 10 ($y+3) 110 20 $FONT_NORMAL $null
    $panel.Controls.Add($name)

    # ip
    $ipLbl = New-Label $pi.IP 125 ($y+3) 115 20 $FONT_MONO $COLOR_GRAY
    $panel.Controls.Add($ipLbl)

    # ping dot
    $pingDot = New-Object System.Windows.Forms.Label
    $pingDot.Size     = New-Object System.Drawing.Size(14, 14)
    $pingDot.Location = New-Object System.Drawing.Point(250, ($y+5))
    $pingDot.Text     = ""
    $pingDot.BackColor = $COLOR_GRAY
    $pingDot.Tag      = "ping_$($pi.IP)"
    $panel.Controls.Add($pingDot)

    # ping label
    $pingLbl = New-Label "Ping" 268 ($y+3) 34 20 $FONT_NORMAL $COLOR_GRAY
    $panel.Controls.Add($pingLbl)

    # ssh dot
    $sshDot = New-Object System.Windows.Forms.Label
    $sshDot.Size      = New-Object System.Drawing.Size(14, 14)
    $sshDot.Location  = New-Object System.Drawing.Point(310, ($y+5))
    $sshDot.Text      = ""
    $sshDot.BackColor = $COLOR_GRAY
    $sshDot.Tag       = "ssh_$($pi.IP)"
    $panel.Controls.Add($sshDot)

    # ssh label
    $sshLbl = New-Label "SSH" 328 ($y+3) 34 20 $FONT_NORMAL $COLOR_GRAY
    $panel.Controls.Add($sshLbl)
}

# --------------------------------------------------------------------------------
# show message box
# --------------------------------------------------------------------------------
function Show-Info($msg, $title) {
    [System.Windows.Forms.MessageBox]::Show($msg, $title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null
}

function Show-Error($msg, $title) {
    [System.Windows.Forms.MessageBox]::Show($msg, $title,
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
}

function Show-Confirm($msg, $title) {
    $r = [System.Windows.Forms.MessageBox]::Show($msg, $title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    return ($r -eq [System.Windows.Forms.DialogResult]::Yes)
}

# --------------------------------------------------------------------------------
# progress/log window — used for long-running multi-Pi operations
# --------------------------------------------------------------------------------
function Show-LogWindow($title) {
    $win = New-Object System.Windows.Forms.Form
    $win.Text          = $title
    $win.Size          = New-Object System.Drawing.Size(620, 420)
    $win.StartPosition = "CenterParent"
    $win.FormBorderStyle = "FixedDialog"
    $win.MaximizeBox   = $false
    $win.MinimizeBox   = $false
    $win.BackColor     = $COLOR_BG

    $txt = New-Object System.Windows.Forms.RichTextBox
    $txt.Location  = New-Object System.Drawing.Point(10, 10)
    $txt.Size      = New-Object System.Drawing.Size(580, 340)
    $txt.Font      = $FONT_MONO
    $txt.ReadOnly  = $true
    $txt.BackColor = [System.Drawing.Color]::FromArgb(20, 20, 20)
    $txt.ForeColor = [System.Drawing.Color]::LightGray
    $win.Controls.Add($txt)

    $closeBtn = New-Button "Close" 250 360 100 30
    $closeBtn.Add_Click({ $win.Close() })
    $win.Controls.Add($closeBtn)

    $win.Show()
    return @{ Window = $win; Log = $txt }
}

function Write-Log($logObj, $message, $color) {
    $rtb = $logObj.Log
    $c   = if ($color) { $color } else { [System.Drawing.Color]::LightGray }
    $rtb.SelectionStart  = $rtb.TextLength
    $rtb.SelectionLength = 0
    $rtb.SelectionColor  = $c
    $rtb.AppendText("$message`n")
    $rtb.ScrollToCaret()
    $logObj.Window.Refresh()
    [System.Windows.Forms.Application]::DoEvents()
}

# --------------------------------------------------------------------------------
# action: refresh monitoring status
# --------------------------------------------------------------------------------
function Invoke-Refresh($pis, $panel) {
    foreach ($pi in $pis) {
        $pingOk = Test-Ping $pi.IP
        $sshOk  = if ($pingOk) { Test-SSHPort $pi.IP } else { $false }

        $pingDot = $panel.Controls | Where-Object { $_.Tag -eq "ping_$($pi.IP)" }
        $sshDot  = $panel.Controls | Where-Object { $_.Tag -eq "ssh_$($pi.IP)" }

        if ($pingDot) { $pingDot.BackColor = if ($pingOk) { $COLOR_GREEN } else { $COLOR_RED } }
        if ($sshDot)  { $sshDot.BackColor  = if ($sshOk)  { $COLOR_GREEN } else { $COLOR_RED } }

        [System.Windows.Forms.Application]::DoEvents()
    }
}

# --------------------------------------------------------------------------------
# action: software update
# --------------------------------------------------------------------------------
function Invoke-Update($pis) {
    if (-not (Show-Confirm "Push latest files from GitHub to all $($pis.Count) Pi(s)?" "Confirm Update")) { return }

    $logObj = Show-LogWindow "Software Update"
    Write-Log $logObj "Starting software update on $($pis.Count) Pi(s)..." $COLOR_AMBER

    $cmd = 'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service     --no-verbose -O /home/kcckiosk/kiosk.service && ' +
           'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh      --no-verbose -O /home/kcckiosk/kiosk.run.sh && ' +
           'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.env         --no-verbose -O /home/kcckiosk/kiosk.env && ' +
           'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/wifi-watchdog.sh  --no-verbose -O /home/kcckiosk/wifi-watchdog.sh && ' +
           'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/unclutter.service --no-verbose -O /home/kcckiosk/unclutter.service && ' +
           'echo "Update complete"'

    foreach ($pi in $pis) {
        Write-Log $logObj "" $null
        Write-Log $logObj "--- $($pi.Name) ($($pi.IP)) ---" $COLOR_AMBER
        $result = Invoke-SSH $pi.IP $cmd
        if ($result.Success) {
            Write-Log $logObj "  OK" $COLOR_GREEN
        } else {
            Write-Log $logObj "  FAILED: $($result.Output)" $COLOR_RED
        }
    }

    Write-Log $logObj "" $null
    Write-Log $logObj "Done." $COLOR_GREEN
}

# --------------------------------------------------------------------------------
# action: reboot
# --------------------------------------------------------------------------------
function Invoke-Reboot($pis) {
    if (-not (Show-Confirm "Reboot all $($pis.Count) Pi(s)?" "Confirm Reboot")) { return }

    $logObj = Show-LogWindow "Reboot"
    Write-Log $logObj "Rebooting $($pis.Count) Pi(s)..." $COLOR_AMBER

    foreach ($pi in $pis) {
        Write-Log $logObj "" $null
        Write-Log $logObj "--- $($pi.Name) ($($pi.IP)) ---" $COLOR_AMBER
        $result = Invoke-SSH $pi.IP "sudo /sbin/shutdown -r now"
        if ($result.Success) {
            Write-Log $logObj "  Reboot command sent" $COLOR_GREEN
        } else {
            Write-Log $logObj "  FAILED: $($result.Output)" $COLOR_RED
        }
    }

    Write-Log $logObj "" $null
    Write-Log $logObj "Done." $COLOR_GREEN
}

# --------------------------------------------------------------------------------
# action: configure a single Pi
# --------------------------------------------------------------------------------
function Invoke-Configure($pis) {

    # --- sub form ---
    $cfgWin = New-Object System.Windows.Forms.Form
    $cfgWin.Text          = "Configure Pi Display"
    $cfgWin.Size          = New-Object System.Drawing.Size(400, 380)
    $cfgWin.StartPosition = "CenterParent"
    $cfgWin.FormBorderStyle = "FixedDialog"
    $cfgWin.MaximizeBox   = $false
    $cfgWin.BackColor     = $COLOR_BG

    # Pi selector
    $cfgWin.Controls.Add((New-Label "Target Pi:" 15 15 100 20 $FONT_NORMAL $null))
    $piCombo = New-Object System.Windows.Forms.ComboBox
    $piCombo.Location     = New-Object System.Drawing.Point(120, 12)
    $piCombo.Size         = New-Object System.Drawing.Size(240, 24)
    $piCombo.DropDownStyle = "DropDownList"
    foreach ($pi in $pis) { $piCombo.Items.Add("$($pi.Name)  ($($pi.IP))") | Out-Null }
    $piCombo.SelectedIndex = 0
    $cfgWin.Controls.Add($piCombo)

    # rotation
    $cfgWin.Controls.Add((New-Label "Rotation:" 15 55 100 20 $FONT_NORMAL $null))
    $rotCombo = New-Object System.Windows.Forms.ComboBox
    $rotCombo.Location    = New-Object System.Drawing.Point(120, 52)
    $rotCombo.Size        = New-Object System.Drawing.Size(240, 24)
    $rotCombo.DropDownStyle = "DropDownList"
    $rotCombo.Items.Add("H — Horizontal") | Out-Null
    $rotCombo.Items.Add("V — Vertical")   | Out-Null
    $rotCombo.SelectedIndex = 0
    $cfgWin.Controls.Add($rotCombo)

    # mode
    $cfgWin.Controls.Add((New-Label "Mode:" 15 95 100 20 $FONT_NORMAL $null))
    $modeCombo = New-Object System.Windows.Forms.ComboBox
    $modeCombo.Location   = New-Object System.Drawing.Point(120, 92)
    $modeCombo.Size       = New-Object System.Drawing.Size(240, 24)
    $modeCombo.DropDownStyle = "DropDownList"
    $modeCombo.Items.Add("C — Club Cameras (two sheets)") | Out-Null
    $modeCombo.Items.Add("S — Single Camera (one sheet)") | Out-Null
    $modeCombo.Items.Add("K — Kiosk / Advertising")       | Out-Null
    $modeCombo.SelectedIndex = 0
    $cfgWin.Controls.Add($modeCombo)

    # sheet / channel selectors
    $cfgWin.Controls.Add((New-Label "Bottom Sheet:" 15 135 100 20 $FONT_NORMAL $null))
    $botCombo = New-Object System.Windows.Forms.ComboBox
    $botCombo.Location    = New-Object System.Drawing.Point(120, 132)
    $botCombo.Size        = New-Object System.Drawing.Size(100, 24)
    $botCombo.DropDownStyle = "DropDownList"
    for ($i = 1; $i -le 12; $i++) { $botCombo.Items.Add("Sheet $i") | Out-Null }
    $botCombo.SelectedIndex = 0
    $cfgWin.Controls.Add($botCombo)

    $cfgWin.Controls.Add((New-Label "Top Sheet:" 15 170 100 20 $FONT_NORMAL $null))
    $topCombo = New-Object System.Windows.Forms.ComboBox
    $topCombo.Location    = New-Object System.Drawing.Point(120, 167)
    $topCombo.Size        = New-Object System.Drawing.Size(100, 24)
    $topCombo.DropDownStyle = "DropDownList"
    for ($i = 1; $i -le 12; $i++) { $topCombo.Items.Add("Sheet $i") | Out-Null }
    $topCombo.SelectedIndex = 1
    $cfgWin.Controls.Add($topCombo)

    # kiosk channel (hidden until K mode selected)
    $cfgWin.Controls.Add((New-Label "Kiosk Channel:" 15 170 110 20 $FONT_NORMAL $null))
    $kioCombo = New-Object System.Windows.Forms.ComboBox
    $kioCombo.Location    = New-Object System.Drawing.Point(130, 167)
    $kioCombo.Size        = New-Object System.Drawing.Size(200, 24)
    $kioCombo.DropDownStyle = "DropDownList"
    $kioCombo.Items.Add("01 — Upstairs Advertising")     | Out-Null
    $kioCombo.Items.Add("02 — Practice Ice (Downstairs)") | Out-Null
    $kioCombo.SelectedIndex = 0
    $kioCombo.Visible = $false
    $cfgWin.Controls.Add($kioCombo)

    # preview label
    $previewLbl = New-Label "Config: HC0102" 15 215 360 24 $FONT_TITLE $COLOR_HDR
    $cfgWin.Controls.Add($previewLbl)

    # update preview when combos change
    $updatePreview = {
        $rot  = if ($rotCombo.SelectedIndex  -eq 0) { "H" } else { "V" }
        $mode = switch ($modeCombo.SelectedIndex) { 0 {"C"} 1 {"S"} 2 {"K"} }
        if ($mode -eq "K") {
            $chan = "{0:D2}" -f ($kioCombo.SelectedIndex + 1)
            $previewLbl.Text = "Config: ${rot}K${chan}${chan}"
            $botCombo.Visible = $false; $topCombo.Visible = $false
            $kioCombo.Visible = $true
            $cfgWin.Controls | Where-Object { $_.Text -eq "Bottom Sheet:" -or $_.Text -eq "Top Sheet:" } | ForEach-Object { $_.Visible = $false }
            $cfgWin.Controls | Where-Object { $_.Text -eq "Kiosk Channel:" } | ForEach-Object { $_.Visible = $true }
        } else {
            $bot = "{0:D2}" -f ($botCombo.SelectedIndex + 1)
            $top = "{0:D2}" -f ($topCombo.SelectedIndex + 1)
            $previewLbl.Text = "Config: ${rot}${mode}${bot}${top}"
            $botCombo.Visible = $true; $topCombo.Visible = $true
            $kioCombo.Visible = $false
            $cfgWin.Controls | Where-Object { $_.Text -eq "Bottom Sheet:" -or $_.Text -eq "Top Sheet:" } | ForEach-Object { $_.Visible = $true }
            $cfgWin.Controls | Where-Object { $_.Text -eq "Kiosk Channel:" } | ForEach-Object { $_.Visible = $false }
        }
    }

    $rotCombo.Add_SelectedIndexChanged($updatePreview)
    $modeCombo.Add_SelectedIndexChanged($updatePreview)
    $botCombo.Add_SelectedIndexChanged($updatePreview)
    $topCombo.Add_SelectedIndexChanged($updatePreview)
    $kioCombo.Add_SelectedIndexChanged($updatePreview)
    & $updatePreview

    # apply button
    $applyBtn = New-Button "Apply & Reboot Pi" 100 260 180 34
    $applyBtn.BackColor = $COLOR_HDR
    $applyBtn.ForeColor = $COLOR_WHITE
    $applyBtn.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $applyBtn.Add_Click({
        $config = $previewLbl.Text -replace "Config: ", ""
        $piIdx  = $piCombo.SelectedIndex
        $pi     = $pis[$piIdx]

        if (-not (Show-Confirm "Write config '$config' to $($pi.Name) and reboot?" "Confirm")) { return }

        $cmd = "echo '$config' > /home/kcckiosk/kiosk.config && sudo sync && sudo reboot"
        $result = Invoke-SSH $pi.IP $cmd
        if ($result.Success) {
            Show-Info "Config '$config' written to $($pi.Name). Pi is rebooting." "Done"
        } else {
            Show-Error "Failed to configure $($pi.Name):`n$($result.Output)" "Error"
        }
        $cfgWin.Close()
    })
    $cfgWin.Controls.Add($applyBtn)

    $cancelBtn = New-Button "Cancel" 290 260 80 34
    $cancelBtn.Add_Click({ $cfgWin.Close() })
    $cfgWin.Controls.Add($cancelBtn)

    $cfgWin.ShowDialog() | Out-Null
}

# --------------------------------------------------------------------------------
# action: camera viewer (ffplay xstack)
# --------------------------------------------------------------------------------
function Invoke-CameraViewer {
    if (-not $FFPLAY) {
        Show-Error "ffplay.exe not found.`n`nPlace ffplay.exe in the same folder as this script, or install FFmpeg and add it to your PATH.`n`nDownload FFmpeg from: https://ffmpeg.org/download.html" "FFmpeg Not Found"
        return
    }

    $env = Load-Env
    if ($env.CAM_USER -eq "") {
        Show-Error "Could not load camera credentials from kiosk.env.`n`nMake sure kiosk.env is in the same folder as this script." "Config Not Found"
        return
    }

    $cellW = [int]($SCRN_WIDTH  / 12)
    $cellH = [int]($SCRN_HEIGHT / 2)

    # build input list: away cameras 0-11, home cameras 12-23
    $inputs = @()
    for ($i = 1; $i -le 12; $i++) {
        $inputs += "-i rtsp://$($env.CAM_USER):$($env.CAM_PASS)@$($env.CAM_AWAY[$i])/axis-media/media.amp"
    }
    for ($i = 1; $i -le 12; $i++) {
        $inputs += "-i rtsp://$($env.CAM_USER):$($env.CAM_PASS)@$($env.CAM_HOME[$i])/axis-media/media.amp"
    }

    # build filter_complex
    $scaleFilter  = ""
    $layout       = ""
    $xstackInputs = ""

    for ($i = 0; $i -lt 24; $i++) {
        $col = if ($i -lt 12) { $i } else { $i - 12 }
        $row = if ($i -lt 12) { 0  } else { 1 }
        $x   = $col * $cellW
        $y   = $row * $cellH

        $scaleFilter  += "[$i`:v]scale=${cellW}:${cellH}[v$i];"
        $layout        = if ($layout -eq "") { "${x}_${y}" } else { "$layout|${x}_${y}" }
        $xstackInputs += "[v$i]"
    }

    $filterComplex = "${scaleFilter}${xstackInputs}xstack=inputs=24:layout=${layout}[out]"

    $args = ($inputs -join " ") + " -filter_complex `"$filterComplex`" -map `"[out]`" -an -noborder -x $SCRN_WIDTH -y $SCRN_HEIGHT"

    Show-Info "Launching camera viewer with all 24 feeds.`n`nPress Q in the ffplay window to quit." "Camera Viewer"
    Start-Process -FilePath $FFPLAY -ArgumentList $args -NoNewWindow
}

# --------------------------------------------------------------------------------
# main window
# --------------------------------------------------------------------------------
function Show-MainWindow {
    $pis = Load-Hosts

    $win = New-Object System.Windows.Forms.Form
    $win.Text          = "KCC Pi Kiosk Manager"
    $win.Size          = New-Object System.Drawing.Size(420, 600)
    $win.StartPosition = "CenterScreen"
    $win.FormBorderStyle = "FixedSingle"
    $win.MaximizeBox   = $false
    $win.BackColor     = $COLOR_BG

    # header
    $hdr = New-Object System.Windows.Forms.Panel
    $hdr.Location  = New-Object System.Drawing.Point(0, 0)
    $hdr.Size      = New-Object System.Drawing.Size(420, 60)
    $hdr.BackColor = $COLOR_HDR
    $win.Controls.Add($hdr)

    $hdrTitle = New-Label "KCC Pi Kiosk Manager" 15 8 300 26 $FONT_TITLE $COLOR_WHITE
    $hdr.Controls.Add($hdrTitle)
    $hdrSub   = New-Label "Kelowna Curling Club" 15 34 300 18 $FONT_NORMAL $COLOR_WHITE
    $hdr.Controls.Add($hdrSub)

    # --- monitoring section ---
    $win.Controls.Add((New-Label "PI STATUS" 15 75 200 18 $FONT_TITLE $COLOR_HDR))

    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Location  = New-Object System.Drawing.Point(10, 96)
    $statusPanel.Size      = New-Object System.Drawing.Size(385, ([Math]::Max(1, $pis.Count)) * 28 + 8)
    $statusPanel.BackColor = $COLOR_WHITE
    $statusPanel.BorderStyle = "FixedSingle"
    $win.Controls.Add($statusPanel)

    if ($pis.Count -eq 0) {
        $statusPanel.Controls.Add((New-Label "No Pis found in pi-hosts.txt" 10 8 340 20 $FONT_NORMAL $COLOR_RED))
    } else {
        for ($i = 0; $i -lt $pis.Count; $i++) {
            Add-StatusRow $statusPanel $pis[$i] ($i * 28 + 4)
        }
    }

    $statusBottom = $statusPanel.Location.Y + $statusPanel.Height + 8

    $refreshBtn = New-Button "Refresh Status" 10 $statusBottom 120 28
    $refreshBtn.Add_Click({ Invoke-Refresh $pis $statusPanel })
    $win.Controls.Add($refreshBtn)

    # --- actions section ---
    $actionsTop = $statusBottom + 40
    $win.Controls.Add((New-Label "ACTIONS" 15 $actionsTop 200 18 $FONT_TITLE $COLOR_HDR))

    $btnTop = $actionsTop + 24

    # update all
    $updateBtn = New-Button "Software Update — All Pis" 10 $btnTop 385 36
    $updateBtn.Add_Click({ Invoke-Update $pis })
    $win.Controls.Add($updateBtn)

    # configure
    $configBtn = New-Button "Configure Pi Display" 10 ($btnTop + 44) 385 36
    $configBtn.Add_Click({ Invoke-Configure $pis })
    $win.Controls.Add($configBtn)

    # reboot all
    $rebootBtn = New-Button "Reboot All Pis" 10 ($btnTop + 88) 385 36
    $rebootBtn.Add_Click({ Invoke-Reboot $pis })
    $win.Controls.Add($rebootBtn)

    # cameras
    $camsBtn = New-Button "View All Cameras" 10 ($btnTop + 132) 385 36
    $camsBtn.Add_Click({ Invoke-CameraViewer })
    $win.Controls.Add($camsBtn)

    # resize form to fit content
    $formHeight = $btnTop + 132 + 36 + 50
    $win.ClientSize = New-Object System.Drawing.Size(420, $formHeight)

    # status bar
    $statusBar = New-Object System.Windows.Forms.StatusStrip
    $statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
    $statusLabel.Text = "Ready — $($pis.Count) Pi(s) loaded from pi-hosts.txt"
    $statusBar.Items.Add($statusLabel) | Out-Null
    $win.Controls.Add($statusBar)

    # check for missing tools on open
    $win.Add_Shown({
        $warnings = @()
        if (-not $PLINK)  { $warnings += "plink.exe not found — SSH actions will not work.`nDownload PuTTY from: https://www.putty.org" }
        if (-not $FFPLAY) { $warnings += "ffplay.exe not found — Camera Viewer will not work.`nDownload FFmpeg from: https://ffmpeg.org/download.html" }
        if ($warnings.Count -gt 0) {
            Show-Info ($warnings -join "`n`n") "Missing Tools"
        }
        if ($pis.Count -gt 0) {
            $statusLabel.Text = "Refreshing status..."
            Invoke-Refresh $pis $statusPanel
            $statusLabel.Text = "Ready — $($pis.Count) Pi(s) loaded"
        }
    })

    [System.Windows.Forms.Application]::Run($win)
}

# --------------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------------
Show-MainWindow
