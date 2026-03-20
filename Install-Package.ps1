<#
.SYNOPSIS
    Install ADempiere package archives to ADEMPIERE_HOME.
.DESCRIPTION
    Verifies checksums and extracts a .jar archive to the target ADempiere installation.
    Packages are extracted to ADEMPIERE_HOME\packages\<name>\
.PARAMETER PackageJar
    Path to the .jar archive to install.
.PARAMETER AdempiereHome
    ADEMPIERE_HOME directory. If omitted, prompts interactively.
.PARAMETER SkipVerify
    Skip checksum verification.
.EXAMPLE
    .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
.EXAMPLE
    .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar
#>

param(
    [Parameter(Position = 0)]
    [string]$PackageJar,

    [Parameter(Position = 1)]
    [string]$AdempiereHome,

    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# --- Color helpers ---
function Write-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Detail  { param([string]$Msg) Write-Host "  $Msg" -ForegroundColor DarkGray }

# --- Post-installation steps ---
function Invoke-PostInstallSteps {
    param([string]$HomePath)

    $serviceName = "Adempiere Server Service"
    $hasService = $false
    if (Get-Command Get-Service -ErrorAction SilentlyContinue) {
        $hasService = [bool](Get-Service -Name $serviceName -ErrorAction SilentlyContinue)
    }

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Info "POST-INSTALLATION STEPS"
    if ($hasService) {
        Write-Info "  Mode: Windows Service ($serviceName)"
    } else {
        Write-Info "  Mode: Script-based (service not found)"
    }
    Write-Host "========================================" -ForegroundColor Cyan

    # Step 1: Stop server
    Write-Host ""
    Write-Info "Step 1/3: Stop ADempiere Server"
    if ($hasService) {
        Write-Info "  Service: $serviceName"
        $runStop = Read-Host "  Run this step? [Y/n]"
        if ($runStop -notmatch '^[Nn]$') {
            try {
                Stop-Service -Name $serviceName -Force
                (Get-Service -Name $serviceName).WaitForStatus('Stopped', '00:01:00')
                Write-Success "Service '$serviceName' stopped"
            } catch {
                Write-Warn "Failed to stop service: $_"
            }
        } else {
            Write-Info "  Skipped"
        }
    } else {
        $stopScript = Join-Path $HomePath "utils\RUN_Server2Stop.bat"
        if (Test-Path $stopScript) {
            Write-Info "  Command: $stopScript"
            $runStop = Read-Host "  Run this step? [Y/n]"
            if ($runStop -notmatch '^[Nn]$') {
                try {
                    Push-Location (Split-Path $stopScript)
                    & cmd /c (Split-Path $stopScript -Leaf)
                    Write-Success "Server stop executed"
                } catch {
                    Write-Warn "Server stop returned error: $_"
                } finally {
                    Pop-Location
                }
            } else {
                Write-Info "  Skipped"
            }
        } else {
            Write-Warn "  Script not found: $stopScript (skipping)"
        }
    }

    # Step 2: Silent setup
    $setupScript = Join-Path $HomePath "RUN_silentsetup.bat"
    Write-Host ""
    Write-Info "Step 2/3: Run Silent Setup (deploy changes)"
    if (Test-Path $setupScript) {
        Write-Info "  Command: $setupScript"
        $runSetup = Read-Host "  Run this step? [Y/n]"
        if ($runSetup -notmatch '^[Nn]$') {
            try {
                Push-Location (Split-Path $setupScript)
                & cmd /c (Split-Path $setupScript -Leaf)
                Write-Success "Silent setup executed"
            } catch {
                Write-Warn "Silent setup returned error: $_"
            } finally {
                Pop-Location
            }
        } else {
            Write-Info "  Skipped"
        }
    } else {
        Write-Warn "  Script not found: $setupScript (skipping)"
    }

    # Step 3: Start server
    Write-Host ""
    Write-Info "Step 3/3: Start ADempiere Server"
    if ($hasService) {
        Write-Info "  Service: $serviceName"
        $runStart = Read-Host "  Run this step? [Y/n]"
        if ($runStart -notmatch '^[Nn]$') {
            try {
                Start-Service -Name $serviceName
                (Get-Service -Name $serviceName).WaitForStatus('Running', '00:02:00')
                Write-Success "Service '$serviceName' started"
            } catch {
                Write-Warn "Failed to start service: $_"
            }
        } else {
            Write-Info "  Skipped"
        }
    } else {
        $startScript = Join-Path $HomePath "utils\RUN_Server2.bat"
        if (Test-Path $startScript) {
            Write-Info "  Command: $startScript"
            $runStart = Read-Host "  Run this step? [Y/n]"
            if ($runStart -notmatch '^[Nn]$') {
                try {
                    Push-Location (Split-Path $startScript)
                    & cmd /c (Split-Path $startScript -Leaf)
                    Write-Success "Server start executed"
                } catch {
                    Write-Warn "Server start returned error: $_"
                } finally {
                    Pop-Location
                }
            } else {
                Write-Info "  Skipped"
            }
        } else {
            Write-Warn "  Script not found: $startScript (skipping)"
        }
    }
}

# --- Compute SHA256 hash ---
function Get-Sha256Hash {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

# --- Verify jar command ---
function Test-JarCommand {
    try {
        $null = & jar --version 2>&1
    } catch {
        Write-Err "JDK required: 'jar' command not found. Ensure JAVA_HOME/bin is in PATH."
        exit 1
    }
}

# --- Main ---
if (-not $PackageJar) {
    Write-Host "Usage: .\Install-Package.ps1 -PackageJar <path> [-AdempiereHome <path>] [-SkipVerify]"
    Write-Host ""
    Write-Host "  -PackageJar     Path to the .jar archive to install"
    Write-Host "  -AdempiereHome  ADEMPIERE_HOME directory (default: C:\PROGRA~1\e-Evolution\Adempiere)"
    Write-Host "                  Packages are extracted to ADEMPIERE_HOME\packages\<name>\"
    Write-Host "  -SkipVerify     Skip checksum verification"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere"
    Write-Host "  .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar"
    exit 1
}

Test-JarCommand

# Validate jar file exists
if (-not (Test-Path $PackageJar -PathType Leaf)) {
    Write-Err "Archive '$PackageJar' not found"
    exit 2
}

# Get absolute path
$jarAbsolute = (Resolve-Path $PackageJar).Path
$jarDir = Split-Path -Parent $jarAbsolute
$pkgName = [System.IO.Path]::GetFileNameWithoutExtension($jarAbsolute)
$checksumFile = Join-Path $jarDir "$pkgName.jar.sha256"

# Verify archive-level checksum
if (-not $SkipVerify) {
    if (Test-Path $checksumFile) {
        Write-Info "Verifying archive integrity..."

        $archiveLine = Get-Content $checksumFile | Where-Object {
            $_ -match "$pkgName\.jar$" -and $_ -notmatch "\.sha256"
        } | Select-Object -Last 1

        if ($archiveLine) {
            $expectedHash = ($archiveLine -split '\s+')[0]
            $actualHash = Get-Sha256Hash -FilePath $jarAbsolute

            if ($expectedHash -ne $actualHash) {
                Write-Err "INTEGRITY CHECK FAILED for '$pkgName.jar'"
                Write-Err "  Expected: $expectedHash"
                Write-Err "  Actual:   $actualHash"
                exit 4
            }
            Write-Success "Archive checksum verified"
        } else {
            Write-Warn "No archive-level checksum found in $checksumFile"
        }
    } else {
        Write-Warn "Checksum file not found: $checksumFile (skipping verification)"
    }
} else {
    Write-Info "Skipping checksum verification (-SkipVerify)"
}

# Determine ADEMPIERE_HOME: parameter > env var > interactive prompt
if (-not $AdempiereHome) {
    if ($env:ADEMPIERE_HOME) {
        $AdempiereHome = $env:ADEMPIERE_HOME
        Write-Info "Using ADEMPIERE_HOME from environment: $AdempiereHome"
    } else {
        $defaultHome = "C:\PROGRA~1\e-Evolution\Adempiere"
        Write-Warn "ADEMPIERE_HOME environment variable is not set."
        $input = Read-Host "Enter ADEMPIERE_HOME path [$defaultHome]"
        $AdempiereHome = if ($input) { $input } else { $defaultHome }
    }
}

# Validate/create ADEMPIERE_HOME
if (-not (Test-Path $AdempiereHome -PathType Container)) {
    $create = Read-Host "ADEMPIERE_HOME '$AdempiereHome' does not exist. Create it? [y/N]"
    if ($create -match '^[Yy]$') {
        New-Item -Path $AdempiereHome -ItemType Directory -Force | Out-Null
        Write-Success "Created $AdempiereHome"
    } else {
        Write-Err "ADEMPIERE_HOME '$AdempiereHome' does not exist."
        exit 5
    }
}

$homeAbsolute = (Resolve-Path $AdempiereHome).Path

# Detect package dir name from checksum paths
$pkgDirName = $pkgName
if (Test-Path $checksumFile) {
    $firstPkgLine = Get-Content $checksumFile | Where-Object { $_ -match "packages/" } | Select-Object -First 1
    if ($firstPkgLine -match "packages/([^/]+)/") {
        $pkgDirName = $Matches[1]
    }
}

# Check if package already exists
$pkgExtractDir = Join-Path $homeAbsolute "packages\$pkgDirName"
$isOverwrite = Test-Path $pkgExtractDir

# List files that will be installed (before extraction)
Write-Host ""
if ($isOverwrite) {
    Write-Warn "Package '$pkgDirName' already exists in $homeAbsolute"
    Write-Info "The following files will be OVERWRITTEN:"
} else {
    Write-Info "The following files will be installed in ${homeAbsolute}:"
}

$jarContents = & jar tf $jarAbsolute | Where-Object { $_ -match '\.jar$' } | Sort-Object
$fileCount = $jarContents.Count
foreach ($entry in $jarContents) {
    Write-Detail $entry
}
Write-Info "Total: $fileCount JARs"
Write-Host ""

# Single confirmation per package
if ($isOverwrite) {
    $confirm = Read-Host "Overwrite and install '$pkgName'? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Info "Installation of '$pkgName' cancelled."
        exit 0
    }
} else {
    $confirm = Read-Host "Proceed with installation of '$pkgName'? [Y/n]"
    if ($confirm -match '^[Nn]$') {
        Write-Info "Installation of '$pkgName' cancelled."
        exit 0
    }
}

# Extract archive into ADEMPIERE_HOME
Write-Host ""
Write-Info "Extracting '$pkgName' to $homeAbsolute ..."
Write-Info "  ADEMPIERE_HOME = $homeAbsolute"
Push-Location $homeAbsolute
try {
    & jar xf $jarAbsolute
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Extraction failed"
        exit 6
    }
} finally {
    Pop-Location
}

# Verify per-file checksums
if (-not $SkipVerify -and (Test-Path $checksumFile)) {
    Write-Info "Verifying extracted file checksums..."
    $verifyFailed = $false

    Get-Content $checksumFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        if ($line -match "dist/") { return }
        if ($line -notmatch "^[a-f0-9]") { return }

        $parts = $line -split '\s+'
        $expectedHash = $parts[0]
        $filePath = $parts[1] -replace '^\*', ''
        $fullPath = Join-Path $homeAbsolute ($filePath.Replace('/', '\'))

        if (Test-Path $fullPath -PathType Leaf) {
            $actualHash = Get-Sha256Hash -FilePath $fullPath
            if ($expectedHash -ne $actualHash) {
                Write-Err "Checksum mismatch: $filePath"
                $verifyFailed = $true
            }
        } elseif ($filePath -match "packages/") {
            Write-Warn "File not found: $fullPath"
            $verifyFailed = $true
        }
    }

    if ($verifyFailed) {
        Write-Err "INTEGRITY CHECK FAILED: Some files did not match checksums"
        exit 4
    }
    Write-Success "All file checksums verified"
}

# Clean up META-INF created by jar
$metaInf = Join-Path $homeAbsolute "META-INF"
if (Test-Path $metaInf) {
    Remove-Item -Path $metaInf -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Success "INSTALLATION SUCCESSFUL"
Write-Info "  Package:        $pkgName"
Write-Info "  Files deployed: $fileCount JARs"
Write-Info "  ADEMPIERE_HOME: $homeAbsolute"
Write-Info "  Installed to:   $pkgExtractDir"
Write-Host "========================================" -ForegroundColor Green

Invoke-PostInstallSteps -HomePath $homeAbsolute
