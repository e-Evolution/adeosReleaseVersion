<#
.SYNOPSIS
    Install ADempiere package archives to a target directory.
.DESCRIPTION
    Verifies checksums and extracts a .jar archive to the target ADempiere installation.
.PARAMETER PackageJar
    Path to the .jar archive to install.
.PARAMETER DestinationPath
    Target ADempiere installation path. If omitted, prompts interactively.
.PARAMETER SkipVerify
    Skip checksum verification.
.EXAMPLE
    .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar -DestinationPath C:\Adempiere
.EXAMPLE
    .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar
#>

param(
    [Parameter(Position = 0)]
    [string]$PackageJar,

    [Parameter(Position = 1)]
    [string]$DestinationPath,

    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"

# --- Color helpers ---
function Write-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

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
    Write-Host "Usage: .\Install-Package.ps1 -PackageJar <path> [-DestinationPath <path>] [-SkipVerify]"
    Write-Host ""
    Write-Host "  -PackageJar       Path to the .jar archive to install"
    Write-Host "  -DestinationPath  Target ADempiere installation path (default: C:\Adempiere)"
    Write-Host "  -SkipVerify       Skip checksum verification"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Install-Package.ps1 -PackageJar dist\MexicanLocation.jar -DestinationPath C:\Adempiere"
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

# Determine destination
if (-not $DestinationPath) {
    $defaultDest = "C:\Adempiere"
    $input = Read-Host "Enter ADempiere installation path [$defaultDest]"
    $DestinationPath = if ($input) { $input } else { $defaultDest }
}

# Validate/create destination
if (-not (Test-Path $DestinationPath -PathType Container)) {
    $create = Read-Host "Destination '$DestinationPath' does not exist. Create it? [y/N]"
    if ($create -match '^[Yy]$') {
        New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        Write-Success "Created $DestinationPath"
    } else {
        Write-Err "Destination '$DestinationPath' does not exist."
        exit 5
    }
}

$destAbsolute = (Resolve-Path $DestinationPath).Path

# Extract archive
Write-Info "Extracting '$pkgName' to $destAbsolute ..."
Push-Location $destAbsolute
try {
    & jar xf $jarAbsolute
    if ($LASTEXITCODE -ne 0) {
        Write-Err "Extraction failed"
        exit 6
    }
} finally {
    Pop-Location
}

# Count extracted files
$pkgExtractDir = Join-Path $destAbsolute "Adempiere\packages\$pkgName"
$extractedCount = 0
if (Test-Path $pkgExtractDir) {
    $extractedCount = (Get-ChildItem -Path $pkgExtractDir -Filter "*.jar" -Recurse -File).Count
}

# Verify per-file checksums
if (-not $SkipVerify -and (Test-Path $checksumFile)) {
    Write-Info "Verifying extracted file checksums..."
    $verifyFailed = $false

    Get-Content $checksumFile | ForEach-Object {
        $line = $_.Trim()
        if (-not $line) { return }
        # Skip archive-level checksum line
        if ($line -match "dist/") { return }
        if ($line -notmatch "^[a-f0-9]") { return }

        $parts = $line -split '\s+'
        $expectedHash = $parts[0]
        $filePath = $parts[1]
        # Remove leading * if present
        $filePath = $filePath -replace '^\*', ''

        $fullPath = Join-Path $destAbsolute ($filePath.Replace('/', '\'))

        if (Test-Path $fullPath -PathType Leaf) {
            $actualHash = Get-Sha256Hash -FilePath $fullPath
            if ($expectedHash -ne $actualHash) {
                Write-Err "Checksum mismatch: $filePath"
                $verifyFailed = $true
            }
        } else {
            if ($filePath -match "Adempiere/packages/") {
                Write-Warn "File not found: $fullPath"
                $verifyFailed = $true
            }
        }
    }

    if ($verifyFailed) {
        Write-Err "INTEGRITY CHECK FAILED: Some files did not match checksums"
        exit 4
    }
    Write-Success "All file checksums verified"
}

# Clean up META-INF created by jar
$metaInf = Join-Path $destAbsolute "META-INF"
if (Test-Path $metaInf) {
    Remove-Item -Path $metaInf -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Success "Installed '$pkgName' ($extractedCount JARs) -> $destAbsolute\Adempiere\packages\$pkgName\"
