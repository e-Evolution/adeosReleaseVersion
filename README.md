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

### ADEMPIERE_HOME

The installer resolves the installation directory in this order:

1. **CLI argument** — path passed directly to the script
2. **`ADEMPIERE_HOME` environment variable** — if set, used automatically
3. **Interactive prompt** — if neither is available, the script asks for the path

Set the environment variable to avoid passing the path every time:

```bash
# Linux/macOS — add to ~/.bashrc, ~/.zshrc, or ~/.config/fish/config.fish
export ADEMPIERE_HOME=/home/adempiere/Adempiere
```

```powershell
# Windows PowerShell — set system environment variable
[Environment]::SetEnvironmentVariable("ADEMPIERE_HOME", "C:\PROGRA~1\e-Evolution\Adempiere", "User")
```

### Quick Install (Linux/macOS)

#### Option 1 — One-liner (bash)

```bash
bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /home/adempiere/Adempiere
```

#### Option 1 — One-liner (fish / zsh / any shell)

```sh
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation /home/adempiere/Adempiere
```

#### Option 2 — Using ADEMPIERE_HOME environment variable

```bash
# If ADEMPIERE_HOME is set, no need to pass the path
export ADEMPIERE_HOME=/home/adempiere/Adempiere

curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- Scala-Package-Libs
```

#### Option 3 — Download installer first

```bash
# Download the installer script
curl -sLO https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh
chmod +x install-release.sh

# List available packages
./install-release.sh --list

# Install with explicit path
./install-release.sh MexicanLocation /home/adempiere/Adempiere

# Or rely on ADEMPIERE_HOME env var
export ADEMPIERE_HOME=/home/adempiere/Adempiere
./install-release.sh MexicanLocation
./install-release.sh Scala-Package-Libs

# Install all packages at once
./install-release.sh --all /home/adempiere/Adempiere

# Install from a specific release tag
./install-release.sh MexicanLocation /home/adempiere/Adempiere --tag MexicanLocation-v1.1.0

# Skip checksum verification (not recommended)
./install-release.sh MexicanLocation /home/adempiere/Adempiere --skip-verify
```

### Quick Install (Windows PowerShell)

#### Step 1 — Download the installer

```powershell
Invoke-WebRequest -Uri "https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/Install-Release.ps1" -OutFile "Install-Release.ps1"
```

#### Step 2 — List available packages

```powershell
.\Install-Release.ps1 -List
```

#### Step 3 — Install packages

```powershell
# Install MexicanLocation
.\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere

# Install Scala runtime libraries
.\Install-Release.ps1 -PackageName Scala-Package-Libs -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
```

#### Step 4 (optional) — Install all packages at once

```powershell
.\Install-Release.ps1 -All -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
```

#### Additional options

```powershell
# Use ADEMPIERE_HOME env var instead of passing -AdempiereHome
$env:ADEMPIERE_HOME = "C:\PROGRA~1\e-Evolution\Adempiere"
.\Install-Release.ps1 -PackageName MexicanLocation

# Install from a specific release tag
.\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere -Tag MexicanLocation-v1.1.0
```

### What the installer does

1. Downloads the `.jar` archive and `.sha256` checksum file from GitHub Releases
2. Verifies the archive integrity against the SHA256 checksum
3. Checks if the package already exists and asks to confirm overwrite
4. Extracts the archive to `ADEMPIERE_HOME/packages/<name>/`
5. Displays a detailed log of all deployed JAR files
6. Verifies each extracted file against per-file checksums
7. Shows an `INSTALLATION SUCCESSFUL` summary with package details

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
| `ADEMPIERE_HOME is not set` | Set the environment variable or pass the path as a CLI argument |

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

### ADEMPIERE_HOME

El instalador resuelve el directorio de instalacion en este orden:

1. **Argumento CLI** — path pasado directamente al script
2. **Variable de ambiente `ADEMPIERE_HOME`** — si esta definida, se usa automaticamente
3. **Prompt interactivo** — si ninguno esta disponible, el script pregunta el path

Configura la variable de ambiente para no tener que pasar el path cada vez:

```bash
# Linux/macOS — agregar a ~/.bashrc, ~/.zshrc, o ~/.config/fish/config.fish
export ADEMPIERE_HOME=/home/adempiere/Adempiere
```

```powershell
# Windows PowerShell — definir variable de ambiente del sistema
[Environment]::SetEnvironmentVariable("ADEMPIERE_HOME", "C:\PROGRA~1\e-Evolution\Adempiere", "User")
```

### Instalacion Rapida (Linux/macOS)

#### Opcion 1 — En una sola linea (bash)

```bash
bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /home/adempiere/Adempiere
```

#### Opcion 1 — En una sola linea (fish / zsh / cualquier shell)

```sh
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation /home/adempiere/Adempiere
```

#### Opcion 2 — Usando la variable de ambiente ADEMPIERE_HOME

```bash
# Si ADEMPIERE_HOME esta definida, no es necesario pasar el path
export ADEMPIERE_HOME=/home/adempiere/Adempiere

curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- MexicanLocation
curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh | bash -s -- Scala-Package-Libs
```

#### Opcion 3 — Descargar el instalador primero

```bash
# Descargar el script de instalacion
curl -sLO https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh
chmod +x install-release.sh

# Listar paquetes disponibles
./install-release.sh --list

# Instalar con path explicito
./install-release.sh MexicanLocation /home/adempiere/Adempiere

# O usar la variable de ambiente ADEMPIERE_HOME
export ADEMPIERE_HOME=/home/adempiere/Adempiere
./install-release.sh MexicanLocation
./install-release.sh Scala-Package-Libs

# Instalar todos los paquetes de una vez
./install-release.sh --all /home/adempiere/Adempiere

# Instalar desde un tag de release especifico
./install-release.sh MexicanLocation /home/adempiere/Adempiere --tag MexicanLocation-v1.1.0

# Omitir la verificacion de checksums (no recomendado)
./install-release.sh MexicanLocation /home/adempiere/Adempiere --skip-verify
```

### Instalacion Rapida (Windows PowerShell)

#### Paso 1 — Descargar el instalador

```powershell
Invoke-WebRequest -Uri "https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/Install-Release.ps1" -OutFile "Install-Release.ps1"
```

#### Paso 2 — Listar paquetes disponibles

```powershell
.\Install-Release.ps1 -List
```

#### Paso 3 — Instalar paquetes

```powershell
# Instalar MexicanLocation
.\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere

# Instalar librerias de Scala
.\Install-Release.ps1 -PackageName Scala-Package-Libs -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
```

#### Paso 4 (opcional) — Instalar todos los paquetes de una vez

```powershell
.\Install-Release.ps1 -All -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere
```

#### Opciones adicionales

```powershell
# Usar ADEMPIERE_HOME env var en lugar de pasar -AdempiereHome
$env:ADEMPIERE_HOME = "C:\PROGRA~1\e-Evolution\Adempiere"
.\Install-Release.ps1 -PackageName MexicanLocation

# Instalar desde un tag de release especifico
.\Install-Release.ps1 -PackageName MexicanLocation -AdempiereHome C:\PROGRA~1\e-Evolution\Adempiere -Tag MexicanLocation-v1.1.0
```

### Que hace el instalador

1. Descarga el archivo `.jar` y el archivo de checksums `.sha256` desde GitHub Releases
2. Verifica la integridad del archivo contra el checksum SHA256
3. Verifica si el paquete ya existe y pide confirmacion para sobrescribir
4. Extrae el archivo en `ADEMPIERE_HOME/packages/<nombre>/`
5. Muestra un log detallado de todos los archivos JAR desplegados
6. Verifica cada archivo extraido contra los checksums individuales
7. Muestra un resumen `INSTALLATION SUCCESSFUL` con los detalles del paquete

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
| `ADEMPIERE_HOME is not set` | Definir la variable de ambiente o pasar el path como argumento CLI |
