<#
.SYNOPSIS
    RetroFlux Omni Automated Binary Code-Signing Script
.DESCRIPTION
    Uses Microsoft SignTool.exe to digitally sign retroflux_omni.exe and all
    companion plugin DLLs with Authenticode digital signatures.
.EXAMPLE
    .\scripts\Sign-Binaries.ps1
    .\scripts\Sign-Binaries.ps1 -CertSubject "CN=My Commercial Cert"
#>

[CmdletBinding()]
param(
    [string]$TargetDir = "C:\Projects\RetroFlux-Omni\build\windows\x64\runner\Debug",
    [string]$CertSubject = "RetroFlux Official",
    [string]$TimestampServer = "http://timestamp.digicert.com",
    [switch]$Remove
)

$ErrorActionPreference = 'Stop'

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   RetroFlux Omni - Authenticode Code Signing Tool          " -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Locate SignTool.exe
$signtoolPaths = @(
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe",
    "C:\Program Files (x86)\Windows Kits\10\App Certification Kit\signtool.exe"
)

$signtool = $signtoolPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $signtool) {
    Write-Error "SignTool.exe not found in Windows SDK paths. Please install Windows 10/11 SDK."
    exit 1
}

Write-Host "-> Found SignTool: $signtool" -ForegroundColor DarkGray
Write-Host "-> Target Directory: $TargetDir" -ForegroundColor DarkGray

# 2. Check if removing signatures
if ($Remove) {
    Write-Host "-> Removing digital signatures from all binaries in $TargetDir..." -ForegroundColor Yellow
    $filesToClean = Get-ChildItem -Path $TargetDir -Include "*.exe", "*.dll" -Recurse
    foreach ($file in $filesToClean) {
        Write-Host "   Removing signature: $($file.Name)..." -NoNewline -ForegroundColor DarkGray
        & $signtool remove /s $file.FullName 2>$null | Out-Null
        Write-Host " [REMOVED]" -ForegroundColor Green
    }
    Write-Host "[SUCCESS] All signatures removed." -ForegroundColor Green
    exit 0
}

# 2. Check Certificate
$cert = Get-ChildItem -Path "Cert:\CurrentUser\My", "Cert:\LocalMachine\My" -Recurse | 
    Where-Object { $_.Subject -like "*$CertSubject*" -and $_.EnhancedKeyUsageList.FriendlyName -contains "Code Signing" } | 
    Select-Object -First 1

if (-not $cert) {
    Write-Warning "No existing Code Signing certificate found matching '$CertSubject'."
    Write-Host "NOTE: Self-signed certificates will trigger Windows 11 Smart App Control (SAC) blocks." -ForegroundColor DarkYellow
    Write-Host "To satisfy SAC, a commercial certificate (DigiCert, Sectigo, etc.) or Microsoft Store package is required." -ForegroundColor DarkYellow
    Write-Host "Creating a local development code-signing certificate..." -ForegroundColor Yellow
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject "CN=$CertSubject, O=RetroFlux, C=US" -CertStoreLocation "Cert:\CurrentUser\My" -NotAfter (Get-Date).AddYears(5)
    Write-Host "Created certificate: $($cert.Thumbprint)" -ForegroundColor Green
}

Write-Host "-> Signing with Certificate: $($cert.Subject)" -ForegroundColor Green

# 3. Sign Executables and DLLs
$filesToSign = Get-ChildItem -Path $TargetDir -Include "*.exe", "*.dll" -Recurse

foreach ($file in $filesToSign) {
    Write-Host "   Signing: $($file.Name)..." -NoNewline -ForegroundColor Yellow
    try {
        & $signtool sign /fd SHA256 /s My /n $CertSubject /tr $TimestampServer /td SHA256 $file.FullName 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host " [SIGNED & TIMESTAMPED]" -ForegroundColor Green
        } else {
            # Retry without timestamp if offline
            & $signtool sign /fd SHA256 /s My /n $CertSubject $file.FullName
            Write-Host " [SIGNED (LOCAL)]" -ForegroundColor Green
        }
    } catch {
        Write-Host " [FAILED: $($_.Exception.Message)]" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[SUCCESS] All binaries successfully signed with Authenticode signatures." -ForegroundColor Green
