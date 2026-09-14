$ErrorActionPreference = 'Stop'

# Ensure TLS 1.2 is enabled for older PowerShell engines
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "marwanvx/opencode"
$version = "v2.0.4-patch.1"
$installDir = Join-Path $HOME ".opencode\bin"

Write-Host ""
Write-Host "  █▀▀█ █▀▀█ █▀▀█ █▀▀▄ █▀▀▀ █▀▀█ █▀▀█ █▀▀█" -ForegroundColor Cyan
Write-Host "  █░░█ █░░█ █▀▀▀ █░░█ █░░░ █░░█ █░░█ █▀▀▀" -ForegroundColor Cyan
Write-Host "  ▀▀▀▀ █▀▀▀ ▀▀▀▀ ▀  ▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀ ▀▀▀▀" -ForegroundColor DarkCyan
Write-Host "  OpenCode Installer (Patched Edition $version)" -ForegroundColor Gray
Write-Host ""

# Stop any running opencode processes so files aren't locked
Get-Process -Name "opencode" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$zipUrl = "https://github.com/$repo/releases/download/$version/opencode-windows-x64.zip"
$tempZip = Join-Path $env:TEMP "opencode-windows-x64.zip"
$tempExtract = Join-Path $env:TEMP "opencode-extract-$PID"

# Clean up any leftover temp files
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✔ System detected: Windows (x64)" -ForegroundColor Green
Write-Host "⠋ Downloading opencode-windows-x64.zip from GitHub releases..." -ForegroundColor DarkYellow

# Download using curl.exe if available with live progress bar, fallback to Invoke-RestMethod
$downloaded = $false
$curlExe = Get-Command "curl.exe" -ErrorAction SilentlyContinue
if ($curlExe) {
    & $curlExe.Source --fail --location --retry 5 --retry-delay 2 --retry-connrefused -# "$zipUrl" -o "$tempZip"
    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempZip)) {
        $downloaded = $true
    }
}

if (-not $downloaded) {
    $prevProgress = $global:ProgressPreference
    $global:ProgressPreference = 'Continue'
    try {
        Invoke-RestMethod -Uri $zipUrl -OutFile $tempZip
    } finally {
        $global:ProgressPreference = $prevProgress
    }
}

if (-not (Test-Path $tempZip)) {
    throw "Download failed: $tempZip does not exist."
}

Write-Host "✔ Download complete" -ForegroundColor Green
Write-Host "⠋ Unpacking release archive..." -ForegroundColor DarkYellow

$prevProgress = $global:ProgressPreference
$global:ProgressPreference = 'SilentlyContinue'
try {
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
} finally {
    $global:ProgressPreference = $prevProgress
}

$exe = Get-ChildItem -Path $tempExtract -Filter "opencode.exe" -Recurse | Select-Object -First 1
if (-not $exe) {
    throw "Error: opencode.exe not found in extracted archive."
}

Move-Item -Path $exe.FullName -Destination "$installDir\opencode.exe" -Force

# Legacy shim opencode2.cmd
$shimPath = "$installDir\opencode2.cmd"
@"
@echo off
"%~dp0opencode.exe" %*
exit /b %errorlevel%
"@ | Out-File -FilePath $shimPath -Encoding ascii -Force

# Cleanup temp files
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "✔ Installed binary to $installDir\opencode.exe" -ForegroundColor Green
Write-Host "✔ Configured legacy shim (opencode2 -> opencode)" -ForegroundColor Green

# Clean up any conflicting global npm package so it doesn't shadow the executable
$npmCmd = Get-Command "npm.cmd" -ErrorAction SilentlyContinue
if ($npmCmd) {
    try {
        & $npmCmd.Source uninstall -g @opencode/cli 2>$null | Out-Null
    } catch {}
}

# Update User PATH permanently if not already added
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathParts = if ($userPath) { $userPath -split ';' } else { @() }
if ($pathParts -notcontains $installDir) {
    $newPath = if ($userPath) { "$installDir;$userPath" } else { $installDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "✔ Added $installDir to User PATH" -ForegroundColor Green
} else {
    Write-Host "✔ PATH already configured" -ForegroundColor Green
}

# Update current session PATH so opencode is immediately usable
if (($env:Path -split ';') -notcontains $installDir) {
    $env:Path = "$installDir;$env:Path"
}

Write-Host ""
Write-Host "✨ OpenCode $version (Patched Edition) installed successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Active Patches Included:" -ForegroundColor White
Write-Host "   • TUI Startup Crash: Fixes startup exception & model #variant parsing (#48978)" -ForegroundColor Gray
Write-Host "   • Stale Reasoning: Auto-recovers on IP/gateway routing changes (#48908)" -ForegroundColor Gray
Write-Host "   • Merman State: Fixes infinite loop in state transitions (#48898)" -ForegroundColor Gray
Write-Host "   • npm Launcher: Direct runtime binary launcher for npm v12 (#48885)" -ForegroundColor Gray
Write-Host ""
Write-Host "Run: opencode" -ForegroundColor Cyan
Write-Host ""
