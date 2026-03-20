<#
.SYNOPSIS
    Pack ADempiere packages into distributable .jar archives.
.DESCRIPTION
    Creates a .jar archive and SHA256 checksum file for ADempiere packages.
.PARAMETER PackageName
    Name of the package under Adempiere\packages\
.PARAMETER All
    Pack all packages.
.EXAMPLE
    .\Pack-Package.ps1 -PackageName MexicanLocation
.EXAMPLE
    .\Pack-Package.ps1 -All
#>

param(
    [Parameter(Position = 0)]
    [string]$PackageName,

    [switch]$All
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackagesDir = Join-Path $ScriptDir "Adempiere\packages"
$DistDir = Join-Path $ScriptDir "dist"

# --- Color helpers ---
function Write-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }

# --- Verify jar command ---
function Test-JarCommand {
    try {
        $null = & jar --version 2>&1
    } catch {
        Write-Err "JDK required: 'jar' command not found. Ensure JAVA_HOME/bin is in PATH."
        exit 1
    }
}

# --- Compute SHA256 in GNU coreutils format ---
function Get-Sha256Line {
    param([string]$FilePath, [string]$RelativePath)
    $hash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
    # GNU coreutils format: hash  filename (two spaces)
    return "$hash  $RelativePath"
}

# --- Pack a single package ---
function Invoke-PackPackage {
    param([string]$Name)

    $pkgDir = Join-Path $PackagesDir $Name

    if (-not (Test-Path $pkgDir -PathType Container)) {
        Write-Err "Package '$Name' not found under Adempiere\packages\"
        return 2
    }

    # Find all JAR files
    $jarFiles = Get-ChildItem -Path $pkgDir -Filter "*.jar" -Recurse -File
    $jarCount = $jarFiles.Count

    if ($jarCount -eq 0) {
        Write-Warn "Package '$Name' has no JAR files, skipping"
        return 3
    }

    Write-Info "Packing '$Name' ($jarCount JARs)..."

    # Create dist directory
    if (-not (Test-Path $DistDir)) {
        New-Item -Path $DistDir -ItemType Directory -Force | Out-Null
    }

    $archive = Join-Path $DistDir "$Name.jar"
    $checksumFile = Join-Path $DistDir "$Name.jar.sha256"
    $relativePath = "Adempiere/packages/$Name"

    # Clean .DS_Store files
    Get-ChildItem -Path $pkgDir -Filter ".DS_Store" -Recurse -Force -File -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    # Generate per-file SHA256 checksums
    Push-Location $ScriptDir
    try {
        $checksumLines = @()
        $jarFiles = Get-ChildItem -Path $relativePath -Filter "*.jar" -Recurse -File | Sort-Object FullName

        foreach ($file in $jarFiles) {
            $relFile = $file.FullName.Substring($ScriptDir.Length + 1).Replace('\', '/')
            $checksumLines += Get-Sha256Line -FilePath $file.FullName -RelativePath $relFile
        }

        # Remove existing archive
        if (Test-Path $archive) { Remove-Item $archive -Force }

        # Create archive with jar command
        & jar cf $archive "$relativePath/"
        if ($LASTEXITCODE -ne 0) {
            Write-Err "Failed to create archive for '$Name'"
            return 6
        }

        # Append archive-level checksum
        $archiveRelPath = "dist/$Name.jar"
        $checksumLines += Get-Sha256Line -FilePath $archive -RelativePath $archiveRelPath

        # Write checksum file
        $checksumLines | Out-File -FilePath $checksumFile -Encoding utf8 -Force
    } finally {
        Pop-Location
    }

    # Summary
    $archiveSize = (Get-Item $archive).Length
    $archiveSizeMB = [math]::Round($archiveSize / 1MB, 1)
    $sizeStr = if ($archiveSizeMB -ge 1) { "${archiveSizeMB}M" } else { "$([math]::Round($archiveSize / 1KB, 0))K" }

    Write-Success "Packed '$Name': $archive ($sizeStr, $jarCount JARs)"
    return 0
}

# --- Main ---
Test-JarCommand

if ($All) {
    Write-Info "Packing all packages..."
    $failed = 0
    $packed = 0

    Get-ChildItem -Path $PackagesDir -Directory | ForEach-Object {
        $result = Invoke-PackPackage -Name $_.Name
        if ($result -eq 3) {
            # Skip empty packages
        } elseif ($result -ne 0 -and $null -ne $result) {
            $failed++
        }
        $packed++
    }

    Write-Host ""
    Write-Success "Done. Packed $packed packages ($failed failures) -> dist/"
} elseif ($PackageName) {
    Invoke-PackPackage -Name $PackageName
} else {
    Write-Host "Usage: .\Pack-Package.ps1 -PackageName <name> | -All"
    Write-Host ""
    Write-Host "  -PackageName    Name of package under Adempiere\packages\"
    Write-Host "  -All            Pack all packages"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Pack-Package.ps1 -PackageName MexicanLocation"
    Write-Host "  .\Pack-Package.ps1 -All"
    exit 1
}
