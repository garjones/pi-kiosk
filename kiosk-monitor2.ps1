#!/usr/bin/env pwsh
# --------------------------------------------------------------------------------
#  kiosk-monitor.ps1
# --------------------------------------------------------------------------------
#  KCC Pi Kiosk -- Background Monitor
#
#  Polls all Raspberry Pis and cameras every 30 seconds and writes a
#  self-contained kiosk-monitor.html with status data embedded directly.
#  Open kiosk-monitor.html in any browser -- no server required.
#
#  Run this script once -- it loops indefinitely until closed.
#
#  Requirements:
#    - PowerShell 7 or later (cross-platform: Windows, macOS, Linux)
#    - ssh (built-in on macOS/Linux; included with Windows 10/11)
#    - sshpass (macOS/Linux only -- install via: brew install sshpass)
#    - curl (built-in on macOS/Linux and Windows 10/11)
#    - pi-hosts.txt -- Pi IP addresses and hostnames
#    - kiosk.env    -- camera credentials and IPs
#
#  Version 4.2
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$HOSTS_FILE  = Join-Path $SCRIPT_DIR "pi-hosts.txt"
$ENV_FILE    = Join-Path $SCRIPT_DIR "kiosk.env"
$HTML_FILE   = Join-Path $SCRIPT_DIR "kiosk-monitor.html"
$SSH_USER    = "kcckiosk"
$SSH_PASS    = "kcc12345"
$SSH_PORT    = 22
$RTSP_PORT   = 554
$POLL_SECS   = 30
$HTTP_PORT   = 8080

# detect platform and locate SSH tools
$IS_WINDOWS = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows

function Find-Tool($name) {
    $inPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    # check common Homebrew locations (macOS) when not on PATH
    foreach ($prefix in @("/opt/homebrew/bin", "/usr/local/bin")) {
        $candidate = Join-Path $prefix $name
        if (Test-Path $candidate) { return $candidate }
    }
    return $null
}

$SSH     = Find-Tool "ssh"
$SSHPASS = Find-Tool "sshpass"   # macOS/Linux only; install via: brew install sshpass
$CURL    = Find-Tool "curl"

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
# load kiosk.env
# --------------------------------------------------------------------------------
function Load-Env {
    $env = @{ CAM_USER = ""; CAM_PASS = ""; CAM_HOME = @(); CAM_AWAY = @() }
    if (-not (Test-Path $ENV_FILE)) { return $env }
    $homeList = @(); $awayList = @()
    $inHome = $false; $inAway = $false
    foreach ($line in Get-Content $ENV_FILE) {
        $line = $line.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) { continue }
        if ($line -match '^CAM_USER="?([^"]*)"?') { $env.CAM_USER = $Matches[1]; continue }
        if ($line -match '^CAM_PASS="?([^"]*)"?') { $env.CAM_PASS = $Matches[1]; continue }
        if ($line -match '^CAM_HOME=\(') { $inHome = $true;  $inAway = $false; continue }
        if ($line -match '^CAM_AWAY=\(') { $inAway = $true;  $inHome = $false; continue }
        if ($inHome -or $inAway) {
            if ($line -eq ")") { $inHome = $false; $inAway = $false; continue }
            $ip = $line -replace '"','' -replace "'",''
            if ($ip -ne "") {
                if ($inHome) { $homeList += $ip } else { $awayList += $ip }
            }
        }
    }
    $env.CAM_HOME = $homeList
    $env.CAM_AWAY = $awayList
    return $env
}

# --------------------------------------------------------------------------------
# checks
# --------------------------------------------------------------------------------
function Test-Ping($ip) {
    try {
        if ($script:IS_WINDOWS) {
            return (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue)
        } else {
            & ping -c 1 -W 2 $ip 2>&1 | Out-Null
            return ($LASTEXITCODE -eq 0)
        }
    } catch { return $false }
}

function Test-TcpPort($ip, $port) {
    try {
        $tcp  = New-Object System.Net.Sockets.TcpClient
        $conn = $tcp.BeginConnect($ip, $port, $null, $null)
        $wait = $conn.AsyncWaitHandle.WaitOne(2000, $false)
        if ($wait) { $tcp.EndConnect($conn); $tcp.Close(); return $true }
        $tcp.Close(); return $false
    } catch { return $false }
}

function Invoke-SSH($ip, $command) {
    if (-not $script:SSH) { return "unknown" }
    try {
        $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "-p", $script:SSH_PORT, "$($script:SSH_USER)@${ip}")
        if ($script:IS_WINDOWS) {
            $out = & $script:SSH @sshOpts $command 2>&1
        } else {
            if (-not $script:SSHPASS) { return "unknown" }
            $out = & $script:SSHPASS -p $script:SSH_PASS $script:SSH @sshOpts $command 2>&1
        }
        return ($out -join "").Trim()
    } catch { return "" }
}

function Test-KioskService($ip) {
    $text = Invoke-SSH $ip "systemctl is-active kiosk.service"
    if ($text -eq "active")   { return "active" }
    if ($text -eq "inactive") { return "inactive" }
    if ($text -eq "failed")   { return "failed" }
    return "unknown"
}

function Get-KioskConfig($ip) {
    $text = Invoke-SSH $ip "cat /home/kcckiosk/kiosk.config 2>/dev/null"
    return $text.Trim()
}

function Set-KioskConfig($ip, $config) {
    $result = Invoke-SSH $ip "echo '$config' > /home/kcckiosk/kiosk.config && sudo sync && sudo reboot"
    # reboot closes the SSH session so any output or error is expected
    return $true
}

# --------------------------------------------------------------------------------
# decode a raw config code (e.g. "HC0102") into a human-readable label
# --------------------------------------------------------------------------------
function ConvertTo-ConfigLabel($config) {
    if ($config -eq "" -or $config.Length -lt 2) { return "Unknown" }

    $rotation = $config.Substring(0, 1)
    $mode     = $config.Substring(1, 1)

    $rotLabel = switch ($rotation) {
        "H" { "Horizontal" }
        "V" { "Vertical" }
        default { "?" }
    }

    switch ($mode) {
        "C" {
            if ($config.Length -ge 6) {
                $bot = [int]$config.Substring(2, 2)
                $top = [int]$config.Substring(4, 2)
                return "$rotLabel · Cameras · Sheets $bot & $top"
            }
        }
        "S" {
            if ($config.Length -ge 4) {
                $sheet = [int]$config.Substring(2, 2)
                return "$rotLabel · Single Camera · Sheet $sheet"
            }
        }
        "K" {
            if ($config.Length -ge 4) {
                $chan = [int]$config.Substring(2, 2)
                $loc  = switch ($chan) { 1 { "Upstairs" } 2 { "Practice Ice" } default { "Channel $chan" } }
                return "$rotLabel · Kiosk · $loc"
            }
        }
    }
    return $config
}

# --------------------------------------------------------------------------------
# fetch camera snapshot as base64
# Returns a base64 string on success, or empty string on failure
# --------------------------------------------------------------------------------
function Get-CameraSnapshot($ip, $user, $pass) {
    try {
        $tmpFile = [System.IO.Path]::GetTempFileName()
        & curl --digest --user "${user}:${pass}" "http://${ip}/axis-cgi/jpg/image.cgi" `
               -o $tmpFile --silent --max-time 5 2>$null
        if (Test-Path $tmpFile) {
            $bytes = [System.IO.File]::ReadAllBytes($tmpFile)
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            if ($bytes.Length -gt 0) {
                return [Convert]::ToBase64String($bytes)
            }
        }
    } catch { }
    return ""
}

# --------------------------------------------------------------------------------
# write self-contained HTML dashboard
# --------------------------------------------------------------------------------
function Write-Dashboard($timestamp, $piResults, $camResults, $camUser, $camPass) {

    # build Pi cards HTML
    $piCards = ""
    foreach ($pi in $piResults) {
        $cardClass   = if (-not $pi.ping) { "offline" } elseif ($pi.service -ne "active") { "degraded" } else { "all-ok" }
        $pingDot     = if ($pi.ping) { '<span class="dot ok"></span>' }  else { '<span class="dot fail"></span>' }
        $sshDot      = if ($pi.ssh)  { '<span class="dot ok"></span>' }  else { '<span class="dot fail"></span>' }
        $svcClass    = switch ($pi.service) { "active" {"active"} "inactive" {"inactive"} "failed" {"failed"} default {"unknown"} }
        $configLabel = if ($pi.config -ne "") { ConvertTo-ConfigLabel $pi.config } else { "" }
        $configHtml  = if ($configLabel -ne "") {
            "<div class=`"pi-config`"><span class=`"pi-config-code`">$($pi.config)</span> $configLabel</div>"
        } else { "" }
        $piCards += @"
        <div class="pi-card $cardClass" onclick="openConfigPanel('$($pi.name)','$($pi.ip)','$($pi.config)')" title="Click to configure">
          <div class="pi-name">$($pi.name)</div>
          <div class="pi-ip">$($pi.ip)</div>
          <div class="pi-checks">
            <div class="check-badge">$pingDot Ping</div>
            <div class="check-badge">$sshDot SSH</div>
            <div class="check-badge"><span class="svc-badge svc-$svcClass">$($pi.service)</span></div>
          </div>
          $configHtml
        </div>
"@
    }

    # build camera grid HTML
    # index camResults by sheet + end
    $bySheet = @{}
    foreach ($c in $camResults) {
        if (-not $bySheet.ContainsKey($c.sheet)) { $bySheet[$c.sheet] = @{} }
        $bySheet[$c.sheet][$c.end] = $c
    }

    # column headers  (sheet numbers 1-12)
    $colHeaders = ""
    for ($s = 1; $s -le 12; $s++) {
        $colHeaders += "      <div class=`"cam-col-header`">$s</div>`n"
    }

    # helper: build one row of 12 camera cells
    function Build-CamRow($endLabel, $bySheet) {
        $row = "    <div class=`"cam-row`">`n"
        $row += "      <div class=`"cam-row-label`">$endLabel</div>`n"
        for ($s = 1; $s -le 12; $s++) {
            $cam = if ($bySheet.ContainsKey($s)) { $bySheet[$s][$endLabel] } else { $null }
            if ($cam) {
                $cls    = if ($cam.up) { "up" } else { "down" }
                $stat   = if ($cam.up) { "UP" } else { "DOWN" }
                $imgTag = if ($cam.snapshot -ne "") {
                    "<div class=`"cam-thumb-wrap`"><img class=`"cam-thumb`" src=`"data:image/jpeg;base64,$($cam.snapshot)`" alt=`"Sheet $s $endLabel`"></div>"
                } else {
                    "<div class=`"cam-thumb-wrap cam-no-image`">No image</div>"
                }
                $row += @"
      <div class="cam-cell $cls">
        <div class="cam-info">
          <span class="cam-ip">$($cam.ip)</span>
          <span class="cam-status $cls">$stat</span>
        </div>
        $imgTag
      </div>
"@
            } else {
                $row += "      <div class=`"cam-cell`"><div class=`"cam-thumb cam-no-image`">—</div></div>`n"
            }
        }
        $row += "    </div>`n"
        return $row
    }

    $awayRow = Build-CamRow "Away" $bySheet
    $homeRow = Build-CamRow "Home" $bySheet

    # summary counts
    $pisTotal  = $piResults.Count
    $pisOk     = ($piResults | Where-Object { $_.ping -and $_.ssh }).Count
    $pisFail   = $pisTotal - $pisOk
    $svcActive = ($piResults | Where-Object { $_.service -eq "active" }).Count
    $camsTotal = $camResults.Count
    $camsUp    = ($camResults | Where-Object { $_.up }).Count
    $camsFail  = $camsTotal - $camsUp

    $piSumClass  = if ($pisFail  -eq 0) { "ok" } else { "fail" }
    $svcSumClass = if ($svcActive -eq $pisTotal) { "ok" } else { "warn" }
    $camSumClass = if ($camsFail  -eq 0) { "ok" } else { "fail" }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta http-equiv="refresh" content="30">
  <title>KCC Pi Kiosk -- Status Dashboard</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { font-family: 'Segoe UI', Arial, sans-serif; background: #0f1923; color: #e0e0e0; min-height: 100vh; padding: 0 0 32px 0; }

    /* ---- header ---- */
    header { background: #1a2a3a; border-bottom: 3px solid #1e5fa8; padding: 16px 28px; display: flex; align-items: center; justify-content: space-between; }
    header h1 { font-size: 1.3rem; font-weight: 600; color: #fff; }
    header h1 span { color: #5b9bd5; }
    .subtitle { font-size: 0.72rem; color: #5a7a9a; margin-top: 3px; }
    .updated { font-size: 0.78rem; color: #7a9ab8; text-align: right; }
    .refreshing { font-size: 0.78rem; color: #5b9bd5; margin-top: 2px; text-align: right; }

    /* ---- section titles ---- */
    .section-title { font-size: 0.7rem; font-weight: 700; letter-spacing: 0.12em; text-transform: uppercase; color: #5b9bd5; padding: 22px 28px 10px; }

    /* ---- summary bar ---- */
    #summary-bar { display: flex; gap: 24px; padding: 14px 28px 0; flex-wrap: wrap; }
    .summary-item { display: flex; align-items: center; gap: 8px; }
    .summary-count { font-size: 1.6rem; font-weight: 700; line-height: 1; }
    .summary-count.ok   { color: #27ae60; }
    .summary-count.warn { color: #e67e22; }
    .summary-count.fail { color: #c0392b; }
    .summary-label { font-size: 0.7rem; color: #7a9ab8; line-height: 1.3; }

    /* ---- Pi grid ---- */
    #pi-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; padding: 0 28px; }
    .pi-card { background: #1a2535; border: 1px solid #253545; border-radius: 6px; padding: 12px 14px; }
    .pi-card.all-ok   { border-left: 3px solid #27ae60; }
    .pi-card.degraded { border-left: 3px solid #e67e22; }
    .pi-card.offline  { border-left: 3px solid #c0392b; }
    .pi-name { font-size: 0.88rem; font-weight: 600; color: #fff; margin-bottom: 2px; }
    .pi-ip   { font-size: 0.72rem; color: #6a8aaa; font-family: 'Consolas', monospace; margin-bottom: 10px; }
    .pi-checks { display: flex; gap: 8px; flex-wrap: wrap; }
    .check-badge { display: flex; align-items: center; gap: 4px; font-size: 0.7rem; color: #aaa; }
    .dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; display: inline-block; }
    .dot.ok   { background: #27ae60; }
    .dot.fail { background: #c0392b; }
    .svc-badge { font-size: 0.65rem; padding: 1px 5px; border-radius: 3px; font-weight: 600; text-transform: uppercase; }
    .svc-active   { background: #1a4a2a; color: #5dca80; }
    .svc-inactive { background: #3a2a10; color: #d4a04a; }
    .svc-failed   { background: #4a1a1a; color: #e07070; }
    .svc-unknown  { background: #2a2a2a; color: #888; }
    .pi-config { margin-top: 8px; font-size: 0.7rem; color: #7a9ab8; line-height: 1.4; }
    .pi-config-code { font-family: 'Consolas', monospace; font-size: 0.7rem; color: #5b9bd5; font-weight: 700; margin-right: 4px; }

    /* ---- Pi card clickable ---- */
    .pi-card { cursor: pointer; transition: border-color 0.15s, box-shadow 0.15s; }
    .pi-card:hover { box-shadow: 0 0 0 2px #2a6ab0; }

    /* ---- config panel ---- */
    #config-overlay {
      display: none;
      position: fixed;
      inset: 0;
      background: rgba(0,0,0,0.45);
      z-index: 100;
    }
    #config-overlay.open { display: block; }

    #config-panel {
      position: fixed;
      top: 0; right: 0;
      width: 360px;
      height: 100vh;
      background: #131f2e;
      border-left: 3px solid #1e5fa8;
      z-index: 101;
      display: flex;
      flex-direction: column;
      transform: translateX(100%);
      transition: transform 0.25s ease;
      overflow-y: auto;
    }
    #config-panel.open { transform: translateX(0); }

    .cp-header {
      background: #1a2a3a;
      padding: 16px 18px;
      display: flex;
      align-items: flex-start;
      justify-content: space-between;
      border-bottom: 1px solid #253545;
      flex-shrink: 0;
    }
    .cp-title { font-size: 1rem; font-weight: 600; color: #fff; }
    .cp-ip    { font-size: 0.72rem; color: #6a8aaa; font-family: 'Consolas', monospace; margin-top: 2px; }
    .cp-close {
      background: none; border: none; color: #7a9ab8; font-size: 1.4rem;
      cursor: pointer; line-height: 1; padding: 0 0 0 12px; flex-shrink: 0;
    }
    .cp-close:hover { color: #fff; }

    .cp-body { padding: 20px 18px; flex: 1; }

    .cp-section { margin-bottom: 20px; }
    .cp-label {
      font-size: 0.65rem; font-weight: 700; letter-spacing: 0.1em;
      text-transform: uppercase; color: #3a6080; margin-bottom: 8px;
    }

    .toggle-group { display: flex; gap: 6px; flex-wrap: wrap; }
    .toggle-btn {
      background: #1a2535; border: 1px solid #2a3a4a; border-radius: 4px;
      color: #7a9ab8; font-size: 0.78rem; font-weight: 600; padding: 6px 14px;
      cursor: pointer; transition: all 0.15s;
    }
    .toggle-btn:hover  { border-color: #2a6ab0; color: #fff; }
    .toggle-btn.active { background: #1e5fa8; border-color: #2a7ad8; color: #fff; }

    .cp-select {
      width: 100%; background: #1a2535; border: 1px solid #2a3a4a;
      border-radius: 4px; color: #e0e0e0; font-size: 0.82rem;
      padding: 7px 10px; appearance: none;
    }
    .cp-select:focus { outline: none; border-color: #2a6ab0; }

    .cp-preview {
      background: #0f1923; border: 1px solid #253545; border-radius: 4px;
      padding: 10px 14px; margin-bottom: 20px; text-align: center;
    }
    .cp-preview-code {
      font-family: 'Consolas', monospace; font-size: 1.4rem;
      font-weight: 700; color: #5b9bd5; display: block;
    }
    .cp-preview-label { font-size: 0.72rem; color: #7a9ab8; margin-top: 4px; }

    .cp-footer { padding: 0 18px 20px; display: flex; gap: 10px; flex-shrink: 0; }
    .cp-apply {
      flex: 1; background: #1e5fa8; border: none; border-radius: 4px;
      color: #fff; font-size: 0.85rem; font-weight: 600; padding: 10px;
      cursor: pointer; transition: background 0.15s;
    }
    .cp-apply:hover    { background: #2a7ad8; }
    .cp-apply:disabled { background: #253545; color: #5a7a9a; cursor: not-allowed; }
    .cp-cancel {
      background: #1a2535; border: 1px solid #2a3a4a; border-radius: 4px;
      color: #7a9ab8; font-size: 0.85rem; padding: 10px 18px;
      cursor: pointer; transition: all 0.15s;
    }
    .cp-cancel:hover { border-color: #2a6ab0; color: #fff; }

    .cp-actions { padding: 0 18px 16px; display: flex; gap: 8px; flex-shrink: 0; }
    .cp-action-btn {
      flex: 1; background: #1a2535; border: 1px solid #2a3a4a; border-radius: 4px;
      color: #7a9ab8; font-size: 0.78rem; font-weight: 600; padding: 8px 10px;
      cursor: pointer; transition: all 0.15s; text-align: center;
    }
    .cp-action-btn:hover    { border-color: #2a6ab0; color: #fff; background: #1e3050; }
    .cp-action-btn:disabled { opacity: 0.4; cursor: not-allowed; }

    .cp-log {
      display: none;
      margin: 0 18px 16px;
      background: #0a1018;
      border: 1px solid #253545;
      border-radius: 4px;
      padding: 10px 12px;
      font-family: 'Consolas', monospace;
      font-size: 0.68rem;
      color: #8ab0c8;
      max-height: 200px;
      overflow-y: auto;
      white-space: pre-wrap;
      word-break: break-all;
      flex-shrink: 0;
    }
    .cp-log.visible { display: block; }

    .cp-message {
      margin: 0 18px 16px; padding: 10px 14px; border-radius: 4px;
      font-size: 0.8rem; display: none;
    }
    .cp-message.error   { background: #4a1a1a; border: 1px solid #c0392b; color: #e07070; display: block; }
    .cp-message.success { background: #1a4a2a; border: 1px solid #27ae60; color: #5dca80; display: block; }

    /* ---- camera grid ---- */
    #camera-section { padding: 0 28px; overflow-x: auto; }

    .cam-grid {
      display: grid;
      grid-template-columns: 48px repeat(12, 1fr);
      gap: 6px;
      min-width: 900px;
    }

    /* column header row */
    .cam-col-header {
      font-size: 0.68rem;
      font-weight: 700;
      color: #3a6080;
      text-align: center;
      padding-bottom: 2px;
      letter-spacing: 0.05em;
    }
    .cam-col-header-spacer { /* empty top-left corner */ }

    /* each data row */
    .cam-row { display: contents; }

    .cam-row-label {
      font-size: 0.68rem;
      font-weight: 700;
      text-transform: uppercase;
      color: #5b9bd5;
      display: flex;
      align-items: flex-start;
      justify-content: flex-end;
      padding-right: 6px;
      padding-top: 6px;
      letter-spacing: 0.05em;
    }

    /* individual camera cell */
    .cam-cell {
      background: #1a2535;
      border: 1px solid #253545;
      border-radius: 5px;
      overflow: hidden;
      display: flex;
      flex-direction: column;
    }
    .cam-cell.up   { border-top: 3px solid #27ae60; }
    .cam-cell.down { border-top: 3px solid #c0392b; }

    .cam-info {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 4px 6px;
      gap: 4px;
    }
    .cam-ip {
      font-size: 0.6rem;
      color: #6a8aaa;
      font-family: 'Consolas', monospace;
      white-space: nowrap;
      overflow: hidden;
      text-overflow: ellipsis;
      flex: 1;
    }
    .cam-status {
      font-size: 0.6rem;
      font-weight: 700;
      text-transform: uppercase;
      flex-shrink: 0;
    }
    .cam-status.up   { color: #27ae60; }
    .cam-status.down { color: #c0392b; }

    /* thumbnail */
    .cam-thumb-wrap {
      width: 100%;
      padding-top: 177.78%;  /* 16/9 inverted = 9/16 = 56.25%, but we want portrait so 16:9 rotated = height is 177.78% of width */
      position: relative;
      overflow: hidden;
    }
    .cam-thumb {
      position: absolute;
      /* image is 16:9 landscape; rotate 90deg CW to make it portrait */
      width: 177.78%;   /* image height becomes cell width: 100% / (9/16) */
      height: 56.25%;   /* image width scaled down to fit: 100% * (9/16) */
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%) rotate(90deg);
      object-fit: cover;
      display: block;
    }
    .cam-no-image {
      background: #111820;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 0.6rem;
      color: #3a5a7a;
      letter-spacing: 0.05em;
      text-transform: uppercase;
    }
  </style>
</head>
<body>
  <header>
    <div>
      <h1>KCC Pi Kiosk <span>Status Dashboard</span></h1>
      <div class="subtitle">Kelowna Curling Club</div>
    </div>
    <div>
      <div class="updated">Updated: $timestamp</div>
      <div class="refreshing">Page auto-refreshes every 30s</div>
    </div>
  </header>

  <div id="summary-bar">
    <div class="summary-item">
      <div class="summary-count $piSumClass">$pisOk/$pisTotal</div>
      <div class="summary-label">Pis<br>online</div>
    </div>
    <div class="summary-item">
      <div class="summary-count $svcSumClass">$svcActive/$pisTotal</div>
      <div class="summary-label">Kiosk service<br>active</div>
    </div>
    <div class="summary-item">
      <div class="summary-count $camSumClass">$camsUp/$camsTotal</div>
      <div class="summary-label">Cameras<br>reachable</div>
    </div>
  </div>

  <div class="section-title">Raspberry Pi Fleet</div>
  <div id="pi-grid">
$piCards
  </div>

  <div class="section-title">Camera Feeds</div>
  <div id="camera-section">
    <div class="cam-grid">
      <!-- column headers -->
      <div class="cam-col-header-spacer"></div>
$colHeaders
      <!-- Away row -->
$awayRow
      <!-- Home row -->
$homeRow
    </div>
  </div>

  <!-- config panel overlay -->
  <div id="config-overlay" onclick="closeConfigPanel()"></div>

  <!-- config panel -->
  <div id="config-panel">
    <div class="cp-header">
      <div>
        <div class="cp-title" id="cp-pi-name">kcc-pi-01</div>
        <div class="cp-ip"   id="cp-pi-ip">10.200.30.11</div>
      </div>
      <button class="cp-close" onclick="closeConfigPanel()">×</button>
    </div>

    <div class="cp-body">
      <!-- rotation -->
      <div class="cp-section">
        <div class="cp-label">Rotation</div>
        <div class="toggle-group" id="cp-rotation">
          <button class="toggle-btn" data-val="H" onclick="setToggle('cp-rotation',this)">H — Horizontal</button>
          <button class="toggle-btn" data-val="V" onclick="setToggle('cp-rotation',this)">V — Vertical</button>
        </div>
      </div>

      <!-- mode -->
      <div class="cp-section">
        <div class="cp-label">Mode</div>
        <div class="toggle-group" id="cp-mode">
          <button class="toggle-btn" data-val="C" onclick="setToggle('cp-mode',this);updateModeFields()">Cameras</button>
          <button class="toggle-btn" data-val="S" onclick="setToggle('cp-mode',this);updateModeFields()">Single</button>
          <button class="toggle-btn" data-val="K" onclick="setToggle('cp-mode',this);updateModeFields()">Kiosk</button>
        </div>
      </div>

      <!-- cameras: sheet pair -->
      <div class="cp-section" id="cp-field-cameras">
        <div class="cp-label">Sheet Pair</div>
        <select class="cp-select" id="cp-pair" onchange="updatePreview()">
          <option value="0102">Sheets 1 &amp; 2</option>
          <option value="0304">Sheets 3 &amp; 4</option>
          <option value="0506">Sheets 5 &amp; 6</option>
          <option value="0708">Sheets 7 &amp; 8</option>
          <option value="0910">Sheets 9 &amp; 10</option>
          <option value="1112">Sheets 11 &amp; 12</option>
        </select>
      </div>

      <!-- single: sheet number -->
      <div class="cp-section" id="cp-field-single" style="display:none">
        <div class="cp-label">Sheet</div>
        <select class="cp-select" id="cp-sheet" onchange="updatePreview()">
          <option value="01">Sheet 1</option>
          <option value="02">Sheet 2</option>
          <option value="03">Sheet 3</option>
          <option value="04">Sheet 4</option>
          <option value="05">Sheet 5</option>
          <option value="06">Sheet 6</option>
          <option value="07">Sheet 7</option>
          <option value="08">Sheet 8</option>
          <option value="09">Sheet 9</option>
          <option value="10">Sheet 10</option>
          <option value="11">Sheet 11</option>
          <option value="12">Sheet 12</option>
        </select>
      </div>

      <!-- kiosk: channel -->
      <div class="cp-section" id="cp-field-kiosk" style="display:none">
        <div class="cp-label">Channel</div>
        <div class="toggle-group" id="cp-kiosk">
          <button class="toggle-btn" data-val="01" onclick="setToggle('cp-kiosk',this)">Upstairs</button>
          <button class="toggle-btn" data-val="02" onclick="setToggle('cp-kiosk',this)">Practice Ice</button>
        </div>
      </div>

      <!-- preview -->
      <div class="cp-preview">
        <span class="cp-preview-code"  id="cp-code">HC0102</span>
        <div  class="cp-preview-label" id="cp-label-text">Horizontal · Cameras · Sheets 1 &amp; 2</div>
      </div>
    </div>

    <div class="cp-message" id="cp-message"></div>

    <div class="cp-actions">
      <button class="cp-action-btn" id="cp-sw-update-btn"  onclick="doSoftwareUpdate()">&#11015; Software Update</button>
      <button class="cp-action-btn" id="cp-sys-update-btn" onclick="doSystemUpdate()">&#9881; System Update</button>
    </div>

    <div class="cp-log" id="cp-log"></div>

    <div class="cp-footer">
      <button class="cp-apply"  id="cp-apply-btn" onclick="applyConfig()">Reboot</button>
      <button class="cp-cancel" onclick="closeConfigPanel()">Cancel</button>
    </div>
  </div>

  <script>
    const API = 'http://localhost:8080';
    let cpIp = '';
    let cpOriginalConfig = '';

    function openConfigPanel(name, ip, currentConfig) {
      cpIp             = ip;
      cpOriginalConfig = currentConfig;
      document.getElementById('cp-pi-name').textContent    = name;
      document.getElementById('cp-pi-ip').textContent      = ip;
      document.getElementById('cp-message').className      = 'cp-message';
      document.getElementById('cp-log').className          = 'cp-log';
      document.getElementById('cp-log').textContent        = '';
      document.getElementById('cp-apply-btn').disabled     = false;
      document.getElementById('cp-apply-btn').textContent  = 'Reboot';
      setActionBtnsDisabled(false);

      // parse current config into controls
      const rot  = currentConfig[0] || 'H';
      const mode = currentConfig[1] || 'C';

      setToggleByVal('cp-rotation', rot);
      setToggleByVal('cp-mode', mode);
      updateModeFields();

      if (mode === 'C' && currentConfig.length >= 6) {
        const pair = currentConfig.substring(2, 6);
        const sel  = document.getElementById('cp-pair');
        for (let o of sel.options) { if (o.value === pair) { sel.value = pair; break; } }
      } else if (mode === 'S' && currentConfig.length >= 4) {
        document.getElementById('cp-sheet').value = currentConfig.substring(2, 4);
      } else if (mode === 'K' && currentConfig.length >= 4) {
        setToggleByVal('cp-kiosk', currentConfig.substring(2, 4));
      }

      updatePreview();
      document.getElementById('config-overlay').classList.add('open');
      document.getElementById('config-panel').classList.add('open');
    }

    function closeConfigPanel() {
      document.getElementById('config-overlay').classList.remove('open');
      document.getElementById('config-panel').classList.remove('open');
    }

    function setToggle(groupId, btn) {
      document.querySelectorAll('#' + groupId + ' .toggle-btn').forEach(b => b.classList.remove('active'));
      btn.classList.add('active');
      updatePreview();
    }

    function setToggleByVal(groupId, val) {
      document.querySelectorAll('#' + groupId + ' .toggle-btn').forEach(b => {
        b.classList.toggle('active', b.dataset.val === val);
      });
    }

    function getToggleVal(groupId) {
      const btn = document.querySelector('#' + groupId + ' .toggle-btn.active');
      return btn ? btn.dataset.val : '';
    }

    function updateModeFields() {
      const mode = getToggleVal('cp-mode');
      document.getElementById('cp-field-cameras').style.display = mode === 'C' ? '' : 'none';
      document.getElementById('cp-field-single').style.display  = mode === 'S' ? '' : 'none';
      document.getElementById('cp-field-kiosk').style.display   = mode === 'K' ? '' : 'none';
      updatePreview();
    }

    function buildConfig() {
      const rot  = getToggleVal('cp-rotation') || 'H';
      const mode = getToggleVal('cp-mode')     || 'C';
      if (mode === 'C') {
        return rot + 'C' + document.getElementById('cp-pair').value;
      } else if (mode === 'S') {
        const s = document.getElementById('cp-sheet').value;
        return rot + 'S' + s + s;
      } else {
        const ch = getToggleVal('cp-kiosk') || '01';
        return rot + 'K' + ch + ch;
      }
    }

    function decodeConfig(cfg) {
      if (!cfg || cfg.length < 2) return '';
      const rot  = cfg[0] === 'H' ? 'Horizontal' : 'Vertical';
      const mode = cfg[1];
      if (mode === 'C' && cfg.length >= 6) {
        return rot + ' · Cameras · Sheets ' + parseInt(cfg.substring(2,4)) + ' & ' + parseInt(cfg.substring(4,6));
      } else if (mode === 'S' && cfg.length >= 4) {
        return rot + ' · Single · Sheet ' + parseInt(cfg.substring(2,4));
      } else if (mode === 'K' && cfg.length >= 4) {
        const loc = cfg.substring(2,4) === '01' ? 'Upstairs' : 'Practice Ice';
        return rot + ' · Kiosk · ' + loc;
      }
      return cfg;
    }

    function updatePreview() {
      const cfg     = buildConfig();
      const changed = cfg !== cpOriginalConfig;
      document.getElementById('cp-code').textContent       = cfg;
      document.getElementById('cp-label-text').textContent = decodeConfig(cfg);
      document.getElementById('cp-apply-btn').textContent  = changed ? 'Apply & Reboot' : 'Reboot';
    }

    function setActionBtnsDisabled(disabled) {
      document.getElementById('cp-sw-update-btn').disabled  = disabled;
      document.getElementById('cp-sys-update-btn').disabled = disabled;
      document.getElementById('cp-apply-btn').disabled      = disabled;
    }

    function showMessage(msg, type) {
      const el = document.getElementById('cp-message');
      el.textContent = msg;
      el.className   = 'cp-message ' + type;
    }

    async function applyConfig() {
      const cfg = buildConfig();
      const btn = document.getElementById('cp-apply-btn');
      document.getElementById('cp-message').className = 'cp-message';
      setActionBtnsDisabled(true);
      btn.textContent = 'Applying…';
      try {
        const resp = await fetch(API + '/set-config', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ip: cpIp, config: cfg })
        });
        const data = await resp.json();
        if (data.success) {
          closeConfigPanel();
        } else {
          showMessage('Error: ' + (data.error || 'Unknown error'), 'error');
          setActionBtnsDisabled(false);
          updatePreview();
        }
      } catch (e) {
        showMessage('Could not reach monitor service (localhost:8080). Is kiosk-monitor2.ps1 running?', 'error');
        setActionBtnsDisabled(false);
        updatePreview();
      }
    }

    async function doSoftwareUpdate() {
      document.getElementById('cp-message').className = 'cp-message';
      document.getElementById('cp-log').className     = 'cp-log';
      setActionBtnsDisabled(true);
      document.getElementById('cp-sw-update-btn').textContent = 'Updating…';
      try {
        const resp = await fetch(API + '/software-update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ip: cpIp })
        });
        const data = await resp.json();
        if (data.success) {
          showMessage('Software updated — Pi is rebooting.', 'success');
        } else {
          showMessage('Error: ' + (data.error || 'Unknown error'), 'error');
        }
      } catch (e) {
        showMessage('Could not reach monitor service (localhost:8080).', 'error');
      }
      document.getElementById('cp-sw-update-btn').textContent = '⬇ Software Update';
      setActionBtnsDisabled(false);
    }

    async function doSystemUpdate() {
      document.getElementById('cp-message').className = 'cp-message';
      const logEl = document.getElementById('cp-log');
      logEl.textContent = '';
      logEl.className   = 'cp-log visible';
      setActionBtnsDisabled(true);
      document.getElementById('cp-sys-update-btn').textContent = 'Updating…';
      try {
        const resp = await fetch(API + '/system-update', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ ip: cpIp })
        });
        const reader  = resp.body.getReader();
        const decoder = new TextDecoder();
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          logEl.textContent += decoder.decode(value);
          logEl.scrollTop    = logEl.scrollHeight;
        }
        showMessage('System update complete.', 'success');
      } catch (e) {
        showMessage('Could not reach monitor service (localhost:8080).', 'error');
      }
      document.getElementById('cp-sys-update-btn').textContent = '⚙ System Update';
      setActionBtnsDisabled(false);
    }
  </script>
</body>
</html>
"@

    $html | Set-Content $HTML_FILE -Encoding UTF8
}

# --------------------------------------------------------------------------------
# poll loop
# --------------------------------------------------------------------------------
function Invoke-Poll($pis, $camEnv) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp] Polling $($pis.Count) Pis and $($camEnv.CAM_HOME.Count + $camEnv.CAM_AWAY.Count) cameras..."

    # poll Pis
    $piResults = @()
    foreach ($pi in $pis) {
        Write-Host "  Pi $($pi.Name) ($($pi.IP))..." -NoNewline
        $ping   = Test-Ping $pi.IP
        $ssh    = if ($ping) { Test-TcpPort $pi.IP $SSH_PORT } else { $false }
        $svc    = if ($ssh)  { Test-KioskService $pi.IP }      else { "unknown" }
        $config = if ($ssh)  { Get-KioskConfig $pi.IP }        else { "" }
        $piResults += @{ name = $pi.Name; ip = $pi.IP; ping = $ping; ssh = $ssh; service = $svc; config = $config }
        Write-Host " ping=$ping ssh=$ssh service=$svc config=$config"
    }

    # poll cameras + fetch snapshots
    $camResults = @()

    for ($i = 0; $i -lt $camEnv.CAM_AWAY.Count; $i++) {
        $ip    = $camEnv.CAM_AWAY[$i]
        $sheet = $i + 1
        $up    = Test-TcpPort $ip $RTSP_PORT
        Write-Host "  Camera Away sheet $sheet ($ip) up=$up" -NoNewline
        $snapshot = ""
        if ($up) {
            $snapshot = Get-CameraSnapshot $ip $camEnv.CAM_USER $camEnv.CAM_PASS
            Write-Host " snapshot=$(if ($snapshot -ne '') { 'ok' } else { 'failed' })"
        } else {
            Write-Host ""
        }
        $camResults += @{ sheet = $sheet; end = "Away"; ip = $ip; up = $up; snapshot = $snapshot }
    }

    for ($i = 0; $i -lt $camEnv.CAM_HOME.Count; $i++) {
        $ip    = $camEnv.CAM_HOME[$i]
        $sheet = $i + 1
        $up    = Test-TcpPort $ip $RTSP_PORT
        Write-Host "  Camera Home sheet $sheet ($ip) up=$up" -NoNewline
        $snapshot = ""
        if ($up) {
            $snapshot = Get-CameraSnapshot $ip $camEnv.CAM_USER $camEnv.CAM_PASS
            Write-Host " snapshot=$(if ($snapshot -ne '') { 'ok' } else { 'failed' })"
        } else {
            Write-Host ""
        }
        $camResults += @{ sheet = $sheet; end = "Home"; ip = $ip; up = $up; snapshot = $snapshot }
    }

    Write-Dashboard $timestamp $piResults $camResults $camEnv.CAM_USER $camEnv.CAM_PASS
    Write-Host "  Written to $HTML_FILE"
    Write-Host ""
}

# --------------------------------------------------------------------------------
# HTTP listener — runs in a background runspace on localhost:8080
# Handles POST /set-config { ip, config }
# --------------------------------------------------------------------------------
function Start-HttpListener {
    $rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
    $rs.Open()
    $rs.SessionStateProxy.SetVariable("HTTP_PORT",  $script:HTTP_PORT)
    $rs.SessionStateProxy.SetVariable("SSH_USER",   $script:SSH_USER)
    $rs.SessionStateProxy.SetVariable("SSH_PASS",   $script:SSH_PASS)
    $rs.SessionStateProxy.SetVariable("SSH_PORT",   $script:SSH_PORT)
    $rs.SessionStateProxy.SetVariable("IS_WINDOWS", $script:IS_WINDOWS)
    $rs.SessionStateProxy.SetVariable("SSH",        $script:SSH)
    $rs.SessionStateProxy.SetVariable("SSHPASS",    $script:SSHPASS)

    $ps = [System.Management.Automation.PowerShell]::Create()
    $ps.Runspace = $rs
    $ps.AddScript({
        function Invoke-SSH-Local($ip, $command) {
            try {
                $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10",
                             "-p", $SSH_PORT, "${SSH_USER}@${ip}")
                if ($IS_WINDOWS) {
                    $out = & $SSH @sshOpts $command 2>&1
                } else {
                    $out = & $SSHPASS -p $SSH_PASS $SSH @sshOpts $command 2>&1
                }
                return ($out -join "").Trim()
            } catch { return "" }
        }

        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://localhost:${HTTP_PORT}/")
        $listener.Start()

        while ($listener.IsListening) {
            try {
                $ctx      = $listener.GetContext()
                $req      = $ctx.Request
                $resp     = $ctx.Response
                $resp.ContentType = "application/json"
                $resp.Headers.Add("Access-Control-Allow-Origin", "*")
                $resp.Headers.Add("Access-Control-Allow-Methods", "POST, OPTIONS")
                $resp.Headers.Add("Access-Control-Allow-Headers", "Content-Type")

                if ($req.HttpMethod -eq "OPTIONS") {
                    $resp.StatusCode = 200
                    $resp.Close()
                    continue
                }

                $body   = New-Object System.IO.StreamReader($req.InputStream)
                $json   = $body.ReadToEnd() | ConvertFrom-Json
                $result = ""

                if ($req.Url.AbsolutePath -eq "/set-config") {
                    $ip     = $json.ip
                    $config = $json.config
                    if ($ip -and $config) {
                        Invoke-SSH-Local $ip "echo '$config' > /home/kcckiosk/kiosk.config && sudo sync && sudo reboot" | Out-Null
                        $result = '{"success":true}'
                    } else {
                        $resp.StatusCode = 400
                        $result = '{"success":false,"error":"Missing ip or config"}'
                    }

                } elseif ($req.Url.AbsolutePath -eq "/software-update") {
                    $ip = $json.ip
                    if ($ip) {
                        $cmd = 'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.service     --no-verbose -O /home/kcckiosk/kiosk.service && ' +
                               'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.run.sh      --no-verbose -O /home/kcckiosk/kiosk.run.sh && ' +
                               'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/kiosk.env         --no-verbose -O /home/kcckiosk/kiosk.env && ' +
                               'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/wifi-watchdog.sh  --no-verbose -O /home/kcckiosk/wifi-watchdog.sh && ' +
                               'wget https://raw.githubusercontent.com/garjones/pi-kiosk/main/unclutter.service --no-verbose -O /home/kcckiosk/unclutter.service && ' +
                               'echo "__DONE__" && sudo reboot'
                        Invoke-SSH-Local $ip $cmd | Out-Null
                        $result = '{"success":true}'
                    } else {
                        $resp.StatusCode = 400
                        $result = '{"success":false,"error":"Missing ip"}'
                    }

                } elseif ($req.Url.AbsolutePath -eq "/system-update") {
                    $ip = $json.ip
                    if ($ip) {
                        # stream output line by line
                        $resp.ContentType = "text/plain; charset=utf-8"
                        $resp.SendChunked = $true
                        $writer = New-Object System.IO.StreamWriter($resp.OutputStream, [System.Text.Encoding]::UTF8)
                        $writer.AutoFlush = $true
                        try {
                            $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=10",
                                         "-p", $SSH_PORT, "${SSH_USER}@${ip}")
                            $cmd = "sudo apt-get update 2>&1 && sudo apt-get upgrade -y 2>&1 && echo '__DONE__'"
                            if ($IS_WINDOWS) {
                                $proc = Start-Process -FilePath $SSH -ArgumentList ($sshOpts + $cmd) -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\sysupdate.txt"
                                $proc.WaitForExit()
                                Get-Content "$env:TEMP\sysupdate.txt" | ForEach-Object { $writer.WriteLine($_) }
                            } else {
                                & $SSHPASS -p $SSH_PASS $SSH @sshOpts $cmd 2>&1 | ForEach-Object {
                                    $writer.WriteLine($_)
                                }
                            }
                        } catch {
                            $writer.WriteLine("ERROR: $_")
                        }
                        $writer.Close()
                        $resp.Close()
                        continue
                    } else {
                        $resp.StatusCode = 400
                        $result = '{"success":false,"error":"Missing ip"}'
                    }

                } else {
                    $resp.StatusCode = 404
                    $result = '{"success":false,"error":"Not found"}'
                }

                $bytes = [System.Text.Encoding]::UTF8.GetBytes($result)
                $resp.ContentLength64 = $bytes.Length
                $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                $resp.Close()
            } catch { }
        }
    }) | Out-Null

    $ps.BeginInvoke() | Out-Null
    Write-Host "  HTTP listener started on http://localhost:${HTTP_PORT}"
    return $ps
}

# --------------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------------
$pis    = Load-Hosts
$camEnv = Load-Env

if ($pis.Count -eq 0) {
    Write-Host "ERROR: No Pis found in $HOSTS_FILE" -ForegroundColor Red
    exit 1
}

Write-Host "=================================================="
Write-Host "  KCC Pi Kiosk Monitor"
Write-Host "  Polling every $POLL_SECS seconds"
Write-Host "  $($pis.Count) Pis, $($camEnv.CAM_HOME.Count + $camEnv.CAM_AWAY.Count) cameras"
Write-Host "  Output: $HTML_FILE"
Write-Host "  Platform: $(if ($IS_WINDOWS) { 'Windows' } else { 'macOS/Linux' })"
Write-Host "  SSH: $(if ($SSH) { $SSH } else { 'NOT FOUND' })"
Write-Host "  curl: $(if ($CURL) { $CURL } else { 'NOT FOUND' })"
if (-not $IS_WINDOWS) {
    Write-Host "  sshpass: $(if ($SSHPASS) { $SSHPASS } else { 'NOT FOUND -- install via: brew install sshpass' })"
}
Write-Host "  Press Ctrl+C to stop"
Write-Host "=================================================="
Write-Host ""

$listenerJob  = Start-HttpListener
$firstPoll    = $true

while ($true) {
    Invoke-Poll $pis $camEnv
    if ($firstPoll) {
        $firstPoll = $false
        if (Test-Path $HTML_FILE) {
            Write-Host "  Opening dashboard in browser..."
            if ($IS_WINDOWS) { Start-Process $HTML_FILE } else { & open $HTML_FILE }
        }
    }
    Start-Sleep -Seconds $POLL_SECS
}
