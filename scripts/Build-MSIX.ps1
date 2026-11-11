<#
.SYNOPSIS
    RetroFlux Omni Automated MSIX Packaging Script
.DESCRIPTION
    Builds and packages RetroFlux Omni as a modern Windows MSIX package.
    - Sideload MSIX: For distribution via GitHub Releases, websites, or direct file sharing.
    - Microsoft Store MSIX: Prepared for instant drag-and-drop submission to Microsoft Partner Center.
.EXAMPLE
    .\scripts\Build-MSIX.ps1
    .\scripts\Build-MSIX.ps1 -Store
    .\scripts\Build-MSIX.ps1 -Install
#>

[CmdletBinding()]
param(
    [switch]$Store,
    [switch]$Install,
    [switch]$DebugBuild,
    [string]$Version = "1.0.0.0"
)

$ErrorActionPreference = 'Stop'
$projectRoot = "C:\Projects\RetroFlux-Omni"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   RetroFlux Omni - MSIX Package Generator                  " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

Set-Location $projectRoot

# 1. Check or build Flutter bundle
if ($DebugBuild) {
    Write-Host "-> Packaging DEBUG build..." -ForegroundColor Yellow
    $modeFlag = "--debug"
} else {
    Write-Host "-> Packaging RELEASE build..." -ForegroundColor Yellow
    $modeFlag = "--release"
}

# 2. Build MSIX command arguments
$msixArgs = @("run", "msix:create", $modeFlag)

if ($Store) {
    Write-Host "-> Target: Microsoft Store Package (Store-ready submission)" -ForegroundColor Green
    $msixArgs += "--store"
} else {
    Write-Host "-> Target: Standalone / Sideload Package" -ForegroundColor Green
    $msixArgs += "--install-certificate"
    $msixArgs += "false"
}

# If version specified
if ($Version) {
    $msixArgs += "--version"
    $msixArgs += $Version
}

Write-Host "-> Executing: dart $($msixArgs -join ' ')..." -ForegroundColor DarkGray
& dart @msixArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to generate MSIX package."
    exit $LASTEXITCODE
}

# Locate output MSIX file
$searchDirs = @(
    "$projectRoot\build\windows\runner\Release",
    "$projectRoot\build\windows\x64\runner\Release",
    "$projectRoot\build\windows\runner\Debug",
    "$projectRoot\build\windows\x64\runner\Debug"
)

$msixFile = $null
foreach ($dir in $searchDirs) {
    $candidate = Join-Path $dir "retroflux_omni.msix"
    if (Test-Path $candidate) {
        $msixFile = $candidate
        break
    }
}

if ($msixFile) {
    $fileInfo = Get-Item $msixFile
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host " [SUCCESS] MSIX Package created successfully!" -ForegroundColor Green
    Write-Host " Path: $($fileInfo.FullName)" -ForegroundColor Cyan
    Write-Host " Size: $([Math]::Round($fileInfo.Length / 1MB, 2)) MB" -ForegroundColor DarkGray
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""

    if ($Install) {
        Write-Host "-> Installing MSIX on local system via Add-AppxPackage..." -ForegroundColor Yellow
        try {
            Add-AppxPackage -Path $fileInfo.FullName -ForceApplicationShutdown
            Write-Host "   [OK] RetroFlux Omni installed as a native Windows MSIX app!" -ForegroundColor Green
        } catch {
            Write-Warning "Could not install MSIX package directly: $($_.Exception.Message)"
            Write-Host "Tip: To install manually, double-click the .msix file or enable Developer Mode in Windows Settings." -ForegroundColor Yellow
        }
    }
} else {
    Write-Warning "MSIX packaging completed, but output file could not be located in standard build folders."
}
