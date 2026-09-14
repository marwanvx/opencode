$ErrorActionPreference = 'Stop'

# Ensure TLS 1.2 is enabled for older PowerShell engines
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

$repo = "marwanvx/opencode"
$version = "v2.0.3-patch.1"
$installDir = Join-Path $HOME ".opencode\bin"

Write-Host "==> Installing OpenCode ($version) for Windows x64..." -ForegroundColor Cyan

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

Write-Host "==> Downloading $zipUrl..." -ForegroundColor Gray

# Download using curl.exe if available (built into Windows 10/11), fallback to Invoke-RestMethod
$downloaded = $false
$curlExe = Get-Command "curl.exe" -ErrorAction SilentlyContinue
if ($curlExe) {
    & $curlExe.Source -fsSL "$zipUrl" -o "$tempZip"
    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempZip)) {
        $downloaded = $true
    }
}

if (-not $downloaded) {
    Invoke-RestMethod -Uri $zipUrl -OutFile $tempZip
}

if (-not (Test-Path $tempZip)) {
    throw "Download failed: $tempZip does not exist."
}

Write-Host "==> Extracting binary..." -ForegroundColor Gray
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

# Cleanup temp files
Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

# Update User PATH permanently if not already added
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$pathParts = if ($userPath) { $userPath -split ';' } else { @() }
if ($pathParts -notcontains $installDir) {
    $newPath = if ($userPath) { "$installDir;$userPath" } else { $installDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "==> Added $installDir to User PATH" -ForegroundColor Green
}

# Update current session PATH so opencode is immediately usable
if (($env:Path -split ';') -notcontains $installDir) {
    $env:Path = "$installDir;$env:Path"
}

Write-Host ""
Write-Host "✅ OpenCode $version installed successfully to $installDir\opencode.exe" -ForegroundColor Green
Write-Host "✅ Active Fixes:" -ForegroundColor White
Write-Host "   • TUI startup crash & model #variant parsing (#48978)" -ForegroundColor Gray
Write-Host "   • Stale encrypted reasoning recovery & replay durability (#48908)" -ForegroundColor Gray
Write-Host "   • Merman state transition infinite loop fix (#48898)" -ForegroundColor Gray
Write-Host "   • Standalone runtime launcher for npm v12 (#48885)" -ForegroundColor Gray
Write-Host ""
Write-Host "Run: opencode" -ForegroundColor Cyan
