#!/usr/bin/env pwsh
# --------------------------------------------------------------------------------
#  kiosk-monitor.ps1
# --------------------------------------------------------------------------------
#  KCC Pi Kiosk — Background Monitor
#
#  Polls all Raspberry Pis and cameras every 30 seconds and writes status.json
#  to the same folder as this script. Open kiosk-monitor.html in a browser to
#  view the live dashboard.
#
#  Run this script once — it loops indefinitely until closed.
#
#  Requirements:
#    - PowerShell 5.1 or later
#    - plink.exe (PuTTY) — for kiosk service checks
#    - pi-hosts.txt — Pi IP addresses and hostnames
#    - kiosk.env    — camera credentials and IPs
#
#  Version 1.1
# --------------------------------------------------------------------------------
#  (C) Copyright Gareth Jones - gareth@gareth.com
# --------------------------------------------------------------------------------

$SCRIPT_DIR  = Split-Path -Parent $MyInvocation.MyCommand.Path
$HOSTS_FILE  = Join-Path $SCRIPT_DIR "pi-hosts.txt"
$ENV_FILE    = Join-Path $SCRIPT_DIR "kiosk.env"
$STATUS_FILE = Join-Path $SCRIPT_DIR "status.json"
$SSH_USER    = "kcckiosk"
$SSH_PASS    = "kcc12345"
$SSH_PORT    = 22
$RTSP_PORT   = 554
$POLL_SECS   = 30

# locate plink
function Find-Tool($name) {
    $local = Join-Path $SCRIPT_DIR $name
    if (Test-Path $local) { return $local }
    $inPath = Get-Command $name -ErrorAction SilentlyContinue
    if ($inPath) { return $inPath.Source }
    return $null
}
$PLINK = Find-Tool "plink.exe"

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
    return (Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue)
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

function Test-KioskService($ip) {
    if (-not $PLINK) { return "unknown" }
    try {
        $out = & $PLINK -ssh -pw $SSH_PASS -batch -P $SSH_PORT "${SSH_USER}@${ip}" `
               "systemctl is-active kiosk.service" 2>&1
        $text = ($out -join "").Trim()
        if ($text -eq "active")   { return "active" }
        if ($text -eq "inactive") { return "inactive" }
        if ($text -eq "failed")   { return "failed" }
        return "unknown"
    } catch { return "unknown" }
}

# --------------------------------------------------------------------------------
# poll loop
# --------------------------------------------------------------------------------
function Invoke-Poll($pis, $camEnv) {
    $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    Write-Host "[$timestamp] Polling $($pis.Count) Pis and $($camEnv.CAM_HOME.Count + $camEnv.CAM_AWAY.Count) cameras..."

    # --- poll Pis ---
    $piResults = @()
    foreach ($pi in $pis) {
        Write-Host "  Pi $($pi.Name) ($($pi.IP))..." -NoNewline
        $ping = Test-Ping     $pi.IP
        $ssh  = if ($ping) { Test-TcpPort $pi.IP $SSH_PORT } else { $false }
        $svc  = if ($ssh)  { Test-KioskService $pi.IP }      else { "unknown" }
        $piResults += @{
            name    = $pi.Name
            ip      = $pi.IP
            ping    = $ping
            ssh     = $ssh
            service = $svc
        }
        Write-Host " ping=$ping ssh=$ssh service=$svc"
    }

    # --- poll cameras ---
    $camResults = @()
    for ($i = 0; $i -lt $camEnv.CAM_AWAY.Count; $i++) {
        $ip    = $camEnv.CAM_AWAY[$i]
        $sheet = $i + 1
        $up    = Test-TcpPort $ip $RTSP_PORT
        Write-Host "  Camera Away sheet $sheet ($ip) up=$up"
        $camResults += @{ sheet = $sheet; end = "Away"; ip = $ip; up = $up }
    }
    for ($i = 0; $i -lt $camEnv.CAM_HOME.Count; $i++) {
        $ip    = $camEnv.CAM_HOME[$i]
        $sheet = $i + 1
        $up    = Test-TcpPort $ip $RTSP_PORT
        Write-Host "  Camera Home sheet $sheet ($ip) up=$up"
        $camResults += @{ sheet = $sheet; end = "Home"; ip = $ip; up = $up }
    }

    # --- write status.json ---
    $status = @{
        updated  = $timestamp
        pis      = $piResults
        cameras  = $camResults
    }
    $status | ConvertTo-Json -Depth 5 | Set-Content $STATUS_FILE -Encoding UTF8
    Write-Host "  Written to $STATUS_FILE"
    Write-Host ""
}

# --------------------------------------------------------------------------------
# built-in HTTP server — serves status.json and kiosk-monitor.html on port 8080
# runs in a background thread so the polling loop is not blocked
# --------------------------------------------------------------------------------
function Start-HttpServer($port) {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:${port}/")
    $listener.Start()
    Write-Host "  HTTP server started — open http://localhost:${port}/kiosk-monitor.html"

    $scriptDir = $SCRIPT_DIR  # capture for use inside thread

    $thread = [System.Threading.Thread]::new({
        param($l, $dir)
        while ($l.IsListening) {
            try {
                $ctx  = $l.GetContext()
                $req  = $ctx.Request
                $resp = $ctx.Response

                $path = $req.Url.LocalPath.TrimStart('/')
                if ($path -eq "" -or $path -eq "/") { $path = "kiosk-monitor.html" }

                $file = Join-Path $dir $path

                if (Test-Path $file) {
                    $mime = switch ([System.IO.Path]::GetExtension($file)) {
                        ".html" { "text/html" }
                        ".json" { "application/json" }
                        default { "text/plain" }
                    }
                    $bytes = [System.IO.File]::ReadAllBytes($file)
                    $resp.ContentType     = $mime
                    $resp.ContentLength64 = $bytes.Length
                    $resp.Headers.Add("Access-Control-Allow-Origin", "*")
                    $resp.OutputStream.Write($bytes, 0, $bytes.Length)
                } else {
                    $resp.StatusCode = 404
                }
                $resp.OutputStream.Close()
            } catch {}
        }
    })
    $thread.IsBackground = $true
    $thread.Start($listener, $scriptDir)
    return $listener
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
Write-Host "  Output: $STATUS_FILE"
Write-Host "  Press Ctrl+C to stop"
Write-Host "=================================================="
Write-Host ""

$server = Start-HttpServer 8080
Write-Host ""

while ($true) {
    Invoke-Poll $pis $camEnv
    Start-Sleep -Seconds $POLL_SECS
}