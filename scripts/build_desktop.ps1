# Build Rust DOH Proxy for Desktop (Windows)
# Usage: .\scripts\build_desktop.ps1 [-Debug]

param(
    [switch]$Debug
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$RustDir = Join-Path $ProjectRoot "core/doh_proxy"

if ($Debug) {
    $BuildType = "debug"
    $CargoFlag = ""
} else {
    $BuildType = "release"
    $CargoFlag = "--release"
}

Write-Host "=== Building Rust DOH Proxy for Windows ($BuildType) ===" -ForegroundColor Cyan

# Build
Push-Location $RustDir
try {
    if ($Debug) {
        cargo build
    } else {
        cargo build --release
    }
} finally {
    Pop-Location
}

$exePath = Join-Path $RustDir "target\$BuildType\doh_proxy_bin.exe"

if (Test-Path $exePath) {
    $size = (Get-Item $exePath).Length / 1MB
    Write-Host ""
    Write-Host "=== Build complete! ===" -ForegroundColor Green
    Write-Host "Executable: $exePath"
    Write-Host "Size: $([math]::Round($size, 2)) MB"
} else {
    Write-Host "Build failed: $exePath not found" -ForegroundColor Red
    exit 1
}
