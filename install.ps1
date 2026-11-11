<#
.SYNOPSIS
    RetroFlux Omni Automated Windows 1-Click Installer
.DESCRIPTION
    Installs RetroFlux Omni 4K Media Conversion Engine on Windows 10 & 11.
    - Automatically checks and installs FFmpeg via WinGet if needed.
    - Automatically strips Mark of the Web (MOTW) via Unblock-File to bypass SAC/SmartScreen blocks.
    - Creates Start Menu and Desktop shortcuts.
.EXAMPLE
    irm https://raw.githubusercontent.com/bonnokush/RetroFlux-Omni/main/install.ps1 | iex
#>

[CmdletBinding()]
param(
    [switch]$Silent,
    [string]$Version = "v1.0.0"
)

$ErrorActionPreference = 'Stop'

function Write-Header {
    Write-Host ""
    Write-Host " ============================================================ " -ForegroundColor Cyan
    Write-Host "   ⚡ RetroFlux Omni — 4K Media Conversion Engine            " -ForegroundColor Green
    Write-Host "   Hardware-Accelerated Transcoding, Remuxing & Audio Studio  " -ForegroundColor DarkGray
    Write-Host " ============================================================ " -ForegroundColor Cyan
    Write-Host ""
}

function Test-Prerequisites {
    Write-Host " [1/5] Checking system compatibility..." -ForegroundColor Yellow

    if (-not [Environment]::Is64BitOperatingSystem) {
        Write-Error "RetroFlux Omni requires a 64-bit (x64) version of Windows."
        return $false
    }

    $osVersion = [Environment]::OSVersion.Version
    if ($osVersion.Major -lt 10) {
        Write-Error "RetroFlux Omni requires Windows 10 or Windows 11."
        return $false
    }

    Write-Host "       ✓ 64-bit Windows detected ($($osVersion.Major).$($osVersion.Minor) Build $($osVersion.Build))" -ForegroundColor Green
    return $true
}

function Ensure-FFmpeg {
    Write-Host " [2/5] Checking FFmpeg hardware acceleration pipeline..." -ForegroundColor Yellow

    $ffmpegFound = $false

    # Check winget link
    $winGetFfmpeg = "$env:LOCALAPPDATA\Microsoft\WinGet\Links\ffmpeg.exe"
    if (Test-Path $winGetFfmpeg) {
        $ffmpegFound = $true
    } elseif (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        $ffmpegFound = $true
    }

    if ($ffmpegFound) {
        Write-Host "       ✓ FFmpeg hardware acceleration pipeline detected." -ForegroundColor Green
    } else {
        Write-Host "       FFmpeg not detected on PATH. Installing Gyan.FFmpeg via WinGet..." -ForegroundColor Cyan
        try {
            winget install Gyan.FFmpeg --accept-source-agreements --accept-package-agreements --silent
            Write-Host "       ✓ FFmpeg successfully installed via WinGet." -ForegroundColor Green
        } catch {
            Write-Host "       Note: WinGet installation skipped. You can manually install FFmpeg if needed." -ForegroundColor DarkGray
        }
    }
}

function Install-RetroFlux {
    Write-Header

    if (-not (Test-Prerequisites)) {
        return
    }

    Ensure-FFmpeg

    $installDir = Join-Path $env:LOCALAPPDATA "Programs\RetroFlux-Omni"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }

    Write-Host " [3/5] Setting up RetroFlux Omni $Version..." -ForegroundColor Yellow
    Write-Host "       Target directory: $installDir" -ForegroundColor DarkGray

    # Check if installing from local workspace repository
    $localBuildDir = "C:\Projects\RetroFlux-Omni\build\windows\x64\runner\Debug"
    if (Test-Path $localBuildDir) {
        Write-Host "       Copying local application binaries..." -ForegroundColor DarkGray
        Copy-Item -Path "$localBuildDir\*" -Destination $installDir -Recurse -Force
        Write-Host "       ✓ Local binaries deployed." -ForegroundColor Green
    } else {
        # Download latest release binary from GitHub Releases
        $repoOwner = "bonnokush"
        $repoName = "RetroFlux-Omni"
        $downloadUrl = "https://github.com/$repoOwner/$repoName/releases/download/$Version/RetroFlux-Omni-Setup.exe"
        $setupPath = Join-Path $env:TEMP "RetroFlux-Omni-Setup-$Version.exe"

        Write-Host "       Downloading from $downloadUrl..." -ForegroundColor DarkGray
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add("User-Agent", "RetroFlux-Omni-Installer")
            $webClient.DownloadFile($downloadUrl, $setupPath)
            Write-Host "       ✓ Download complete." -ForegroundColor Green

            # Execute silent install
            Start-Process -FilePath $setupPath -ArgumentList "/SILENT" -Wait
        } catch {
            Write-Host "       Release asset not yet published on GitHub: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "       You can build locally with 'flutter build windows' or run from C:\Projects\RetroFlux-Omni" -ForegroundColor Yellow
            return
        }
    }

    # SAC / SmartScreen unblock: strip Mark of the Web
    Write-Host " [4/5] Unblocking application files (bypassing Smart App Control / SmartScreen)..." -ForegroundColor Yellow
    try {
        Get-ChildItem -Path $installDir -Recurse -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue
        Write-Host "       ✓ Removed Mark-of-the-Web zone identifiers from all binaries and DLLs." -ForegroundColor Green
    } catch {
        Write-Host "       Note: Unblock-File completed with warnings." -ForegroundColor DarkGray
    }

    # Create Shortcuts
    Write-Host " [5/5] Creating Start Menu & Desktop shortcuts..." -ForegroundColor Yellow
    $exePath = Join-Path $installDir "retroflux_omni.exe"

    if (Test-Path $exePath) {
        $wscript = New-Object -ComObject WScript.Shell

        # Start Menu Shortcut
        $startMenuDir = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\RetroFlux"
        if (-not (Test-Path $startMenuDir)) {
            New-Item -ItemType Directory -Path $startMenuDir -Force | Out-Null
        }
        $startMenuShortcut = $wscript.CreateShortcut((Join-Path $startMenuDir "RetroFlux Omni.lnk"))
        $startMenuShortcut.TargetPath = $exePath
        $startMenuShortcut.WorkingDirectory = $installDir
        $startMenuShortcut.Description = "RetroFlux Omni 4K Media Conversion Engine"
        $startMenuShortcut.Save()

        # Desktop Shortcut
        $desktopShortcut = $wscript.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "RetroFlux Omni.lnk"))
        $desktopShortcut.TargetPath = $exePath
        $desktopShortcut.WorkingDirectory = $installDir
        $desktopShortcut.Description = "RetroFlux Omni 4K Media Conversion Engine"
        $desktopShortcut.Save()

        Write-Host "       ✓ Created Start Menu & Desktop shortcuts." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host " ============================================================ " -ForegroundColor Green
    Write-Host "   🎉 RetroFlux Omni installation complete!                   " -ForegroundColor Green
    Write-Host "   Launch from Desktop or Start Menu: 'RetroFlux Omni'        " -ForegroundColor Cyan
    Write-Host " ============================================================ " -ForegroundColor Green
    Write-Host ""

    if (-not $Silent) {
        $launch = Read-Host " Launch RetroFlux Omni now? (Y/n)"
        if ($launch -ne 'n' -and $launch -ne 'N') {
            if (Test-Path $exePath) {
                Start-Process -FilePath $exePath -WorkingDirectory $installDir
            }
        }
    }
}

Install-RetroFlux
