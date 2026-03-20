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

# Determine ADEMPIERE_HOME
if (-not $AdempiereHome) {
    $defaultHome = "C:\PROGRA~1\e-Evolution\Adempiere"
    $input = Read-Host "Enter ADEMPIERE_HOME path [$defaultHome]"
    $AdempiereHome = if ($input) { $input } else { $defaultHome }
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

# Check if package already exists and confirm overwrite
$pkgExtractDir = Join-Path $homeAbsolute "packages\$pkgDirName"
if (Test-Path $pkgExtractDir) {
    Write-Warn "Package directory already exists: $pkgExtractDir"
    $overwrite = Read-Host "Overwrite existing files? [y/N]"
    if ($overwrite -notmatch '^[Yy]$') {
        Write-Info "Installation cancelled."
        exit 0
    }
}

# Extract archive into ADEMPIERE_HOME
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

# List extracted files
$extractedFiles = @()
if (Test-Path $pkgExtractDir) {
    $extractedFiles = Get-ChildItem -Path $pkgExtractDir -Filter "*.jar" -Recurse -File
}

Write-Info "Deployed files:"
foreach ($file in $extractedFiles) {
    $relPath = $file.FullName.Substring($homeAbsolute.Length + 1)
    Write-Detail $relPath
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
Write-Info "  Files deployed: $($extractedFiles.Count) JARs"
Write-Info "  ADEMPIERE_HOME: $homeAbsolute"
Write-Info "  Installed to:   $pkgExtractDir"
Write-Host "========================================" -ForegroundColor Green
