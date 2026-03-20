# ADempiere Package Distribution

## English

### Overview

This repository distributes ADempiere extension packages as GitHub Release assets. Each package is a `.jar` archive containing libraries that can be installed into any ADempiere instance using the provided scripts.

### Prerequisites

- **JDK 11+** installed (`jar` command must be available in PATH)
- **curl** or **wget** (Linux/macOS)
- Internet access to GitHub

### Available Packages

| Package | Description |
|---------|-------------|
| MexicanLocation | Mexican localization — CFDI, fiscal stamps, SAT catalogs |
| Scala-Package-Libs | Scala runtime libraries required by MexicanLocation |

### Quick Install (Linux/macOS)

#### Option 1 — One-liner (bash)

```bash
bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /home/adempiere/Adempiere
```

#### Option 1 — One-liner (fish / zsh / any shell)

```sh
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation /home/adempiere/Adempiere
```

#### Option 2 — Download installer first

```bash
# Download the installer script
curl -sLO https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh
chmod +x install-release.sh

# List available packages
./install-release.sh --list

# Install a single package to your ADempiere directory
./install-release.sh MexicanLocation /home/adempiere/Adempiere

# Install Scala runtime libraries
./install-release.sh Scala-Package-Libs /home/adempiere/Adempiere

# Install all packages at once
./install-release.sh --all /home/adempiere/Adempiere

# Install from a specific release tag
./install-release.sh MexicanLocation /home/adempiere/Adempiere --tag MexicanLocation-v1.1.0

# Skip checksum verification (not recommended)
./install-release.sh MexicanLocation /home/adempiere/Adempiere --skip-verify
```

### Quick Install (Windows PowerShell)

```powershell
# Download the installer script
Invoke-WebRequest -Uri "https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/Install-Release.ps1" -OutFile "Install-Release.ps1"

# List available packages
.\Install-Release.ps1 -List

# Install a single package
.\Install-Release.ps1 -PackageName MexicanLocation -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Install Scala runtime libraries
.\Install-Release.ps1 -PackageName Scala-Package-Libs -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Install all packages at once
.\Install-Release.ps1 -All -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Install from a specific release tag
.\Install-Release.ps1 -PackageName MexicanLocation -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere -Tag MexicanLocation-v1.1.0
```

### What the installer does

1. Downloads the `.jar` archive and `.sha256` checksum file from GitHub Releases
2. Verifies the archive integrity against the SHA256 checksum
3. Extracts the archive to the specified ADempiere installation directory
4. Verifies each extracted file against per-file checksums
5. Cleans up temporary files

### Resulting directory structure

After installation, files are placed under `ADEMPIERE_HOME/packages/`:

```
ADEMPIERE_HOME=/home/adempiere/Adempiere

/home/adempiere/Adempiere/          # ADEMPIERE_HOME
  packages/
    MexicanLocation/
      lib/
        FastInfoset.jar
        batik-all-1.9.jar
        ...
    Scala/                          # extracted from Scala-Package-Libs.jar
      io.github.dotty-cps-async.dotty-cps-async_3-1.1.2.jar
      lib/
        scala3-library_3-3.6.4.jar
        ...
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| `jar: command not found` | Install JDK 11+ and ensure `JAVA_HOME/bin` is in your PATH |
| `curl: command not found` | Install curl: `apt install curl` (Debian/Ubuntu) or `yum install curl` (RHEL/CentOS) |
| Checksum verification failed | Re-download the package — the file may be corrupted |
| Permission denied | Run with `sudo` or ensure write access to the destination directory |

---

## Español

### Descripcion General

Este repositorio distribuye paquetes de extensiones de ADempiere como assets de GitHub Releases. Cada paquete es un archivo `.jar` que contiene las librerias necesarias y puede instalarse en cualquier instancia de ADempiere usando los scripts proporcionados.

### Requisitos Previos

- **JDK 11+** instalado (el comando `jar` debe estar disponible en el PATH)
- **curl** o **wget** (Linux/macOS)
- Acceso a internet para descargar desde GitHub

### Paquetes Disponibles

| Paquete | Descripcion |
|---------|-------------|
| MexicanLocation | Localizacion mexicana — CFDI, timbrado fiscal, catalogos SAT |
| Scala-Package-Libs | Librerias de runtime de Scala requeridas por MexicanLocation |

### Instalacion Rapida (Linux/macOS)

#### Opcion 1 — En una sola linea (bash)

```bash
bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /home/adempiere/Adempiere
```

#### Opcion 1 — En una sola linea (fish / zsh / cualquier shell)

```sh
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation /home/adempiere/Adempiere
```

#### Opcion 2 — Descargar el instalador primero

```bash
# Descargar el script de instalacion
curl -sLO https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh
chmod +x install-release.sh

# Listar paquetes disponibles
./install-release.sh --list

# Instalar un paquete individual en tu directorio de ADempiere
./install-release.sh MexicanLocation /home/adempiere/Adempiere

# Instalar las librerias de Scala
./install-release.sh Scala-Package-Libs /home/adempiere/Adempiere

# Instalar todos los paquetes de una vez
./install-release.sh --all /home/adempiere/Adempiere

# Instalar desde un tag de release especifico
./install-release.sh MexicanLocation /home/adempiere/Adempiere --tag MexicanLocation-v1.1.0

# Omitir la verificacion de checksums (no recomendado)
./install-release.sh MexicanLocation /home/adempiere/Adempiere --skip-verify
```

### Instalacion Rapida (Windows PowerShell)

```powershell
# Descargar el script de instalacion
Invoke-WebRequest -Uri "https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/Install-Release.ps1" -OutFile "Install-Release.ps1"

# Listar paquetes disponibles
.\Install-Release.ps1 -List

# Instalar un paquete individual
.\Install-Release.ps1 -PackageName MexicanLocation -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Instalar las librerias de Scala
.\Install-Release.ps1 -PackageName Scala-Package-Libs -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Instalar todos los paquetes de una vez
.\Install-Release.ps1 -All -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere

# Instalar desde un tag de release especifico
.\Install-Release.ps1 -PackageName MexicanLocation -DestinationPath C:\PROGRA~1\e-Evolution\Adempiere -Tag MexicanLocation-v1.1.0
```

### Que hace el instalador

1. Descarga el archivo `.jar` y el archivo de checksums `.sha256` desde GitHub Releases
2. Verifica la integridad del archivo contra el checksum SHA256
3. Extrae el archivo en el directorio de instalacion de ADempiere especificado
4. Verifica cada archivo extraido contra los checksums individuales
5. Limpia los archivos temporales

### Estructura de directorios resultante

Despues de la instalacion, los archivos se colocan bajo `ADEMPIERE_HOME/packages/`:

```
ADEMPIERE_HOME=/home/adempiere/Adempiere

/home/adempiere/Adempiere/          # ADEMPIERE_HOME
  packages/
    MexicanLocation/
      lib/
        FastInfoset.jar
        batik-all-1.9.jar
        ...
    Scala/                          # extraido desde Scala-Package-Libs.jar
      io.github.dotty-cps-async.dotty-cps-async_3-1.1.2.jar
      lib/
        scala3-library_3-3.6.4.jar
        ...
```

### Solucion de Problemas

| Problema | Solucion |
|----------|----------|
| `jar: command not found` | Instalar JDK 11+ y asegurar que `JAVA_HOME/bin` este en el PATH |
| `curl: command not found` | Instalar curl: `apt install curl` (Debian/Ubuntu) o `yum install curl` (RHEL/CentOS) |
| Fallo en verificacion de checksum | Volver a descargar el paquete — el archivo puede estar corrupto |
| Permiso denegado | Ejecutar con `sudo` o asegurar permisos de escritura en el directorio destino |
