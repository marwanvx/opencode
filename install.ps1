$ErrorActionPreference = 'Stop'
$repo = "marwanvx/opencode"
$version = "v2.0.3-patch.1"
$installDir = "$HOME\.opencode\bin"

Write-Host "==> Installing OpenCode ($version) for Windows x64..." -ForegroundColor Cyan

if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$zipUrl = "https://github.com/$repo/releases/download/$version/opencode-windows-x64.zip"
$tempZip = Join-Path $env:TEMP "opencode-windows-x64.zip"
$tempExtract = Join-Path $env:TEMP "opencode-extract"

Invoke-WebRequest -Uri $zipUrl -OutFile $tempZip
Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
Move-Item -Path "$tempExtract\opencode.exe" -Destination "$installDir\opencode.exe" -Force

Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$installDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$installDir;$userPath", "User")
    $env:Path = "$installDir;$env:Path"
    Write-Host "==> Added $installDir to User PATH" -ForegroundColor Green
}

Write-Host ""
Write-Host "✅ OpenCode $version installed successfully to $installDir\opencode.exe" -ForegroundColor Green
Write-Host "Run: opencode" -ForegroundColor Cyan
