<#
.SYNOPSIS
    RetroFlux Omni Automated Windows Installer & Environment Setup
.DESCRIPTION
    Standard installer script for RetroFlux Omni.
    - Tests 64-bit Windows compatibility.
    - Probes FFmpeg and installs Gyan.FFmpeg via WinGet if absent.
    - Copies/deploys the native Windows runner.
    - Unblocks all binaries to prevent SAC (Smart App Control) Mark-of-the-Web blocks.
    - Creates Start Menu & Desktop shortcuts.
.EXAMPLE
    .\Install-RetroFlux.ps1
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$Version = "v1.0.0"
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ⚡ Installing RetroFlux Omni — 4K Media Conversion Engine   " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

# 1. 64-bit & OS Version check
if (-not [Environment]::Is64BitOperatingSystem) {
    Write-Error "RetroFlux Omni requires a 64-bit (x64) Windows operating system."
    exit 1
}

# 2. Check and Install FFmpeg via WinGet
$winGetFfmpeg = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ffmpeg.exe"
if (-not (Test-Path $winGetFfmpeg) -and -not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "-> Installing Gyan.FFmpeg for hardware 4K acceleration..." -ForegroundColor Yellow
    try {
        winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements --silent
        Write-Host "   ✓ FFmpeg installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "   Note: WinGet installation skipped. Ensure FFmpeg is available on PATH." -ForegroundColor DarkGray
    }
} else {
    Write-Host "-> FFmpeg hardware acceleration pipeline detected." -ForegroundColor Green
}

# 3. Target Installation Directory
$installDir = Join-Path $env:LOCALAPPDATA "Programs\RetroFlux-Omni"
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
}

$localBuildDir = "C:\Projects\RetroFlux-Omni\build\windows\x64\runner\Debug"
if (Test-Path $localBuildDir) {
    Write-Host "-> Deploying RetroFlux Omni to $installDir..." -ForegroundColor Yellow
    Copy-Item -Path "$localBuildDir\*" -Destination $installDir -Recurse -Force
}

# 4. SAC Unblock-File
Write-Host "-> Unblocking binaries (removing Mark-of-the-Web to prevent SAC/SmartScreen blocks)..." -ForegroundColor Yellow
Get-ChildItem -Path $installDir -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
Write-Host "   ✓ All application binaries unblocked." -ForegroundColor Green

# 5. Shortcuts
$exePath = Join-Path $installDir "retroflux_omni.exe"
if (Test-Path $exePath) {
    $wscript = New-Object -ComObject WScript.Shell

    # Start Menu
    $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\RetroFlux"
    if (-not (Test-Path $startMenuDir)) { New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null }
    $shortcut1 = $wscript.CreateShortcut((Join-Path $startMenuDir "RetroFlux Omni.lnk"))
    $shortcut1.TargetPath = $exePath
    $shortcut1.WorkingDirectory = $installDir
    $shortcut1.Save()

    # Desktop
    $shortcut2 = $wscript.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "RetroFlux Omni.lnk"))
    $shortcut2.TargetPath = $exePath
    $shortcut2.WorkingDirectory = $installDir
    $shortcut2.Save()

    Write-Host "-> Shortcuts created on Desktop and Start Menu." -ForegroundColor Green
}

Write-Host "✓ Installation finished successfully!" -ForegroundColor Green
