<#
.SYNOPSIS
    Download and install ADempiere packages from GitHub Releases.
.DESCRIPTION
    Downloads package archives and checksums from GitHub Releases, verifies integrity,
    and extracts to ADEMPIERE_HOME. Packages are placed under ADEMPIERE_HOME\packages\<name>\
.PARAMETER PackageName
    Name of the package to install.
.PARAMETER AdempiereHome
    ADEMPIERE_HOME directory. If omitted, prompts interactively.
.PARAMETER Tag
    Release tag (default: latest).
.PARAMETER All
    Install all packages from the release.
.PARAMETER List
    List available packages in the release.
.PARAMETER SkipVerify
    Skip checksum verification.
.EXAMPLE
    .\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
.EXAMPLE
    .\Install-Release.ps1 -List
.EXAMPLE
    .\Install-Release.ps1 -All -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere -Tag MexicanLocation-v1.1.0
#>

param(
    [Parameter(Position = 0)]
    [string]$PackageName,

    [Parameter(Position = 1)]
    [string]$AdempiereHome,

    [string]$Tag = "latest",

    [switch]$All,
    [switch]$List,
    [switch]$SkipVerify
)

$ErrorActionPreference = "Stop"
$Repo = "e-Evolution/adeosReleaseVersion"

# --- Color helpers ---
function Write-Info    { param([string]$Msg) Write-Host "[INFO] $Msg" -ForegroundColor Cyan }
function Write-Success { param([string]$Msg) Write-Host "[OK] $Msg" -ForegroundColor Green }
function Write-Warn    { param([string]$Msg) Write-Host "[WARN] $Msg" -ForegroundColor Yellow }
function Write-Err     { param([string]$Msg) Write-Host "[ERROR] $Msg" -ForegroundColor Red }
function Write-Detail  { param([string]$Msg) Write-Host "  $Msg" -ForegroundColor DarkGray }

# --- Verify jar command ---
function Test-JarCommand {
    try {
        $null = & jar --version 2>&1
    } catch {
        Write-Err "JDK required: 'jar' command not found. Ensure JAVA_HOME/bin is in PATH."
        exit 1
    }
}

# --- Build base URL ---
function Get-BaseUrl {
    param([string]$ReleaseTag)
    if ($ReleaseTag -eq "latest") {
        return "https://github.com/$Repo/releases/latest/download"
    } else {
        return "https://github.com/$Repo/releases/download/$ReleaseTag"
    }
}

# --- Get release info from API ---
function Get-ReleaseInfo {
    param([string]$ReleaseTag)
    $apiUrl = if ($ReleaseTag -eq "latest") {
        "https://api.github.com/repos/$Repo/releases/latest"
    } else {
        "https://api.github.com/repos/$Repo/releases/tags/$ReleaseTag"
    }

    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Headers @{ "User-Agent" = "ADempiere-Installer" }
        return $response
    } catch {
        Write-Err "Failed to fetch release info. Check tag '$ReleaseTag' exists."
        exit 2
    }
}

# --- Download file ---
function Get-RemoteFile {
    param([string]$Url, [string]$OutputPath)
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        $ProgressPreference = 'Continue'
        return $true
    } catch {
        return $false
    }
}

# --- Compute SHA256 ---
function Get-Sha256Hash {
    param([string]$FilePath)
    return (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

# --- List packages ---
function Show-PackageList {
    param([string]$ReleaseTag)

    Write-Info "Fetching available packages (tag: $ReleaseTag)..."
    $release = Get-ReleaseInfo -ReleaseTag $ReleaseTag

    Write-Host ""
    Write-Host "ADempiere Packages - Release $($release.tag_name)" -ForegroundColor White
    Write-Host ("{0,-35} {1}" -f "Package", "Size")
    Write-Host ("{0,-35} {1}" -f ("─" * 35), ("─" * 8))

    $release.assets | Where-Object { $_.name -match '\.jar$' -and $_.name -notmatch '\.sha256$' } | ForEach-Object {
        $name = $_.name -replace '\.jar$', ''
        $sizeMB = [math]::Round($_.size / 1MB, 1)
        Write-Host ("  {0,-33} {1} MB" -f $name, $sizeMB)
    }
    Write-Host ""
}

# --- Install a single package ---
function Install-SinglePackage {
    param(
        [string]$Name,
        [string]$Home,
        [string]$ReleaseTag,
        [bool]$NoVerify
    )

    $baseUrl = Get-BaseUrl -ReleaseTag $ReleaseTag
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "adempiere-install-$Name-$(Get-Random)"
    New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null

    try {
        $jarFile = Join-Path $tmpDir "$Name.jar"
        $shaFile = Join-Path $tmpDir "$Name.jar.sha256"

        # Download JAR
        Write-Info "Downloading $Name.jar ..."
        $downloaded = Get-RemoteFile -Url "$baseUrl/$Name.jar" -OutputPath $jarFile
        if (-not $downloaded) {
            Write-Err "Failed to download '$Name.jar'. Package may not exist in release '$ReleaseTag'."
            return $false
        }

        # Download checksum
        if (-not $NoVerify) {
            Write-Info "Downloading $Name.jar.sha256 ..."
            $shaDownloaded = Get-RemoteFile -Url "$baseUrl/$Name.jar.sha256" -OutputPath $shaFile
            if (-not $shaDownloaded) {
                Write-Warn "Checksum file not available. Skipping verification."
                $NoVerify = $true
            }
        }

        # Verify archive integrity
        if (-not $NoVerify -and (Test-Path $shaFile)) {
            Write-Info "Verifying archive integrity..."
            $archiveLine = Get-Content $shaFile | Where-Object {
                $_ -match "$Name\.jar$" -and $_ -notmatch "\.sha256"
            } | Select-Object -Last 1

            if ($archiveLine) {
                $expectedHash = ($archiveLine -split '\s+')[0]
                $actualHash = Get-Sha256Hash -FilePath $jarFile

                if ($expectedHash -ne $actualHash) {
                    Write-Err "INTEGRITY CHECK FAILED for '$Name.jar'"
                    Write-Err "  Expected: $expectedHash"
                    Write-Err "  Actual:   $actualHash"
                    return $false
                }
                Write-Success "Archive checksum verified"
            }
        }

        # Determine ADEMPIERE_HOME
        if (-not $Home) {
            $defaultHome = "C:\PROGRA~1\e-Evolution\Adempiere"
            $input = Read-Host "Enter ADEMPIERE_HOME path [$defaultHome]"
            $Home = if ($input) { $input } else { $defaultHome }
        }

        # Validate/create ADEMPIERE_HOME
        if (-not (Test-Path $Home -PathType Container)) {
            $create = Read-Host "ADEMPIERE_HOME '$Home' does not exist. Create it? [y/N]"
            if ($create -match '^[Yy]$') {
                New-Item -Path $Home -ItemType Directory -Force | Out-Null
                Write-Success "Created $Home"
            } else {
                Write-Err "ADEMPIERE_HOME '$Home' does not exist."
                return $false
            }
        }

        $homeAbsolute = (Resolve-Path $Home).Path

        # Detect package dir name from checksum paths
        $pkgDirName = $Name
        if (Test-Path $shaFile) {
            $firstPkgLine = Get-Content $shaFile | Where-Object { $_ -match "packages/" } | Select-Object -First 1
            if ($firstPkgLine -match "packages/([^/]+)/") {
                $pkgDirName = $Matches[1]
            }
        }

        # Check if package already exists
        $pkgExtractDir = Join-Path $homeAbsolute "packages\$pkgDirName"
        if (Test-Path $pkgExtractDir) {
            Write-Warn "Package directory already exists: $pkgExtractDir"
            $overwrite = Read-Host "Overwrite existing files? [y/N]"
            if ($overwrite -notmatch '^[Yy]$') {
                Write-Info "Installation of '$Name' cancelled."
                return $false
            }
        }

        # Extract into ADEMPIERE_HOME
        Write-Info "Extracting '$Name' to $homeAbsolute ..."
        Write-Info "  ADEMPIERE_HOME = $homeAbsolute"
        Push-Location $homeAbsolute
        try {
            & jar xf $jarFile
            if ($LASTEXITCODE -ne 0) {
                Write-Err "Extraction failed"
                return $false
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
        if (-not $NoVerify -and (Test-Path $shaFile)) {
            Write-Info "Verifying extracted file checksums..."
            $verifyFailed = $false

            Get-Content $shaFile | ForEach-Object {
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
                return $false
            }
            Write-Success "All file checksums verified"
        }

        # Clean up META-INF
        $metaInf = Join-Path $homeAbsolute "META-INF"
        if (Test-Path $metaInf) {
            Remove-Item -Path $metaInf -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Success "INSTALLATION SUCCESSFUL"
        Write-Info "  Package:        $Name"
        Write-Info "  Files deployed: $($extractedFiles.Count) JARs"
        Write-Info "  ADEMPIERE_HOME: $homeAbsolute"
        Write-Info "  Installed to:   $pkgExtractDir"
        Write-Host "========================================" -ForegroundColor Green
        return $true
    } finally {
        Remove-Item -Path $tmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# --- Main ---
Test-JarCommand

if ($List) {
    Show-PackageList -ReleaseTag $Tag
    exit 0
}

if ($All) {
    if (-not $AdempiereHome) {
        $defaultHome = "C:\PROGRA~1\e-Evolution\Adempiere"
        $input = Read-Host "Enter ADEMPIERE_HOME path [$defaultHome]"
        $AdempiereHome = if ($input) { $input } else { $defaultHome }
    }

    Write-Info "Installing all packages (tag: $Tag) to $AdempiereHome ..."
    $release = Get-ReleaseInfo -ReleaseTag $Tag

    $installed = 0
    $failed = 0

    $release.assets | Where-Object { $_.name -match '\.jar$' -and $_.name -notmatch '\.sha256$' } | ForEach-Object {
        $name = $_.name -replace '\.jar$', ''
        Write-Host ""
        $result = Install-SinglePackage -Name $name -Home $AdempiereHome -ReleaseTag $Tag -NoVerify $SkipVerify.IsPresent
        if ($result) { $installed++ } else { $failed++ }
    }

    Write-Host ""
    Write-Success "Done. Installed $installed packages ($failed failures) -> $AdempiereHome"
} elseif ($PackageName) {
    Install-SinglePackage -Name $PackageName -Home $AdempiereHome -ReleaseTag $Tag -NoVerify $SkipVerify.IsPresent
} else {
    Write-Host "Usage: .\Install-Release.ps1 <-PackageName name | -All | -List> [options]"
    Write-Host ""
    Write-Host "  -PackageName     Package to install"
    Write-Host "  -AdempiereHome   ADEMPIERE_HOME directory (default: C:\PROGRA~1\e-Evolution\Adempiere)"
    Write-Host "                   Packages are extracted to ADEMPIERE_HOME\packages\<name>\"
    Write-Host "  -Tag             Release tag (default: latest)"
    Write-Host "  -All             Install all packages"
    Write-Host "  -List            List available packages"
    Write-Host "  -SkipVerify      Skip checksum verification"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere"
    Write-Host "  .\Install-Release.ps1 -List -Tag MexicanLocation-v1.1.0"
    Write-Host "  .\Install-Release.ps1 -All -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere"
    exit 1
}
