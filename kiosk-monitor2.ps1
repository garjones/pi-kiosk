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
#    - pi-hosts.txt -- Pi IP addresses and hostnames
#    - kiosk.env    -- camera credentials and IPs
#
#  Version 3.2
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

# detect platform and locate SSH tools
$IS_WINDOWS = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows

function Find-Tool($name) {
    $inPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}

$SSH     = Find-Tool "ssh"
$SSHPASS = Find-Tool "sshpass"   # macOS/Linux only; install via: brew install sshpass

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
        if ($IS_WINDOWS) {
            return (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue)
        } else {
            $result = & ping -c 1 -W 2 $ip 2>&1
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
    if (-not $SSH) { return "unknown" }
    try {
        $sshOpts = @("-o", "StrictHostKeyChecking=no", "-o", "ConnectTimeout=5", "-p", $SSH_PORT, "${SSH_USER}@${ip}")
        if ($IS_WINDOWS) {
            # Windows: use ssh directly (password auth via SSH key or Windows OpenSSH)
            $out = & $SSH @sshOpts $command 2>&1
        } else {
            # macOS/Linux: use sshpass for password auth
            if (-not $SSHPASS) { return "unknown" }
            $out = & $SSHPASS -p $SSH_PASS $SSH @sshOpts $command 2>&1
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
        $url     = "http://${ip}/axis-cgi/jpg/image.cgi"
        $cred    = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${user}:${pass}"))
        $tmpFile = [System.IO.Path]::GetTempFileName()
        $resp    = Invoke-WebRequest -Uri $url `
                       -Headers @{ Authorization = "Basic $cred" } `
                       -TimeoutSec 5 `
                       -OutFile $tmpFile `
                       -PassThru `
                       -ErrorAction Stop
        if ($resp.StatusCode -eq 200 -and (Test-Path $tmpFile)) {
            $bytes = [System.IO.File]::ReadAllBytes($tmpFile)
            Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
            if ($bytes.Length -gt 0) {
                return [Convert]::ToBase64String($bytes)
            }
        }
        Remove-Item $tmpFile -Force -ErrorAction SilentlyContinue
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
        <div class="pi-card $cardClass">
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
                    "<img class=`"cam-thumb`" src=`"data:image/jpeg;base64,$($cam.snapshot)`" alt=`"Sheet $s $endLabel`">"
                } else {
                    "<div class=`"cam-thumb cam-no-image`">No image</div>"
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
    .cam-thumb {
      width: 100%;
      aspect-ratio: 16/9;
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
if (-not $IS_WINDOWS) {
    Write-Host "  sshpass: $(if ($SSHPASS) { $SSHPASS } else { 'NOT FOUND -- install via: brew install sshpass' })"
}
Write-Host "  Press Ctrl+C to stop"
Write-Host "=================================================="
Write-Host ""

while ($true) {
    Invoke-Poll $pis $camEnv
    Start-Sleep -Seconds $POLL_SECS
}
