#!/usr/bin/env bash
#
# install-package.sh — Install ADempiere package archives to ADEMPIERE_HOME
#
# Usage:
#   ./install-package.sh <package.jar> [ADEMPIERE_HOME] [--skip-verify]
#
set -euo pipefail

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()    { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# --- Read from terminal (works with curl | bash) ---
prompt_user() {
    local prompt_msg="$1"
    local answer
    printf "%s" "$prompt_msg" > /dev/tty
    read -r answer < /dev/tty
    echo "$answer"
}

# --- Detect SHA256 command ---
detect_sha_cmd() {
    if command -v sha256sum &>/dev/null; then
        SHA_CMD="sha256sum"
    elif command -v shasum &>/dev/null; then
        SHA_CMD="shasum -a 256"
    else
        error "No SHA256 tool found. Install coreutils or use macOS default shasum."
        exit 1
    fi
}

# --- Verify jar command ---
check_jar() {
    if ! command -v jar &>/dev/null; then
        error "JDK required: 'jar' command not found. Ensure JAVA_HOME/bin is in PATH."
        exit 1
    fi
}

# --- Usage ---
usage() {
    echo "Usage: $0 <package.jar> [ADEMPIERE_HOME] [--skip-verify]"
    echo ""
    echo "  package.jar     Path to the .jar archive to install"
    echo "  ADEMPIERE_HOME  ADempiere installation directory (default: /home/adempiere/Adempiere)"
    echo "                  Packages are extracted to ADEMPIERE_HOME/packages/<name>/"
    echo "  --skip-verify   Skip checksum verification"
    echo ""
    echo "Examples:"
    echo "  $0 dist/MexicanLocation.jar /home/adempiere/Adempiere"
    echo "  $0 dist/MexicanLocation.jar                    # interactive prompt"
    echo "  $0 dist/MexicanLocation.jar /home/adempiere/Adempiere --skip-verify"
    exit 1
}

# --- Main ---
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    check_jar
    detect_sha_cmd

    local package_jar=""
    local adempiere_home=""
    local skip_verify=false

    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            --skip-verify)
                skip_verify=true
                ;;
            *)
                if [[ -z "$package_jar" ]]; then
                    package_jar="$arg"
                elif [[ -z "$adempiere_home" ]]; then
                    adempiere_home="$arg"
                fi
                ;;
        esac
    done

    # Validate jar file exists
    if [[ ! -f "$package_jar" ]]; then
        error "Archive '$package_jar' not found"
        exit 2
    fi

    # Get absolute path to jar
    local jar_absolute
    jar_absolute="$(cd "$(dirname "$package_jar")" && pwd)/$(basename "$package_jar")"

    # Extract package name from jar filename
    local pkg_name
    pkg_name=$(basename "$package_jar" .jar)

    # Locate checksum file
    local jar_dir
    jar_dir="$(dirname "$jar_absolute")"
    local checksum_file="$jar_dir/${pkg_name}.jar.sha256"

    # Verify archive-level checksum
    if [[ "$skip_verify" == false ]]; then
        if [[ -f "$checksum_file" ]]; then
            info "Verifying archive integrity..."
            local archive_line
            archive_line=$(grep "${pkg_name}.jar$" "$checksum_file" | grep -v "\.sha256" | tail -1) || true

            if [[ -n "$archive_line" ]]; then
                local expected_hash
                expected_hash=$(echo "$archive_line" | awk '{print $1}')
                local actual_hash
                actual_hash=$($SHA_CMD "$jar_absolute" | awk '{print $1}')

                if [[ "$expected_hash" != "$actual_hash" ]]; then
                    error "INTEGRITY CHECK FAILED for '$pkg_name.jar'"
                    error "  Expected: $expected_hash"
                    error "  Actual:   $actual_hash"
                    exit 4
                fi
                success "Archive checksum verified"
            else
                warn "No archive-level checksum found in $checksum_file"
            fi
        else
            warn "Checksum file not found: $checksum_file (skipping verification)"
        fi
    else
        info "Skipping checksum verification (--skip-verify)"
    fi

    # Determine ADEMPIERE_HOME: argument > env var > interactive prompt
    if [[ -z "$adempiere_home" ]]; then
        if [[ -n "${ADEMPIERE_HOME:-}" ]]; then
            adempiere_home="$ADEMPIERE_HOME"
            info "Using ADEMPIERE_HOME from environment: $adempiere_home"
        else
            local default_home="/home/adempiere/Adempiere"
            warn "ADEMPIERE_HOME environment variable is not set."
            adempiere_home=$(prompt_user "Enter ADEMPIERE_HOME path [$default_home]: ")
            adempiere_home="${adempiere_home:-$default_home}"
        fi
    fi

    # Validate/create destination
    if [[ ! -d "$adempiere_home" ]]; then
        local create_dir
        create_dir=$(prompt_user "ADEMPIERE_HOME '$adempiere_home' does not exist. Create it? [y/N]: ")
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$adempiere_home"
            success "Created $adempiere_home"
        else
            error "ADEMPIERE_HOME '$adempiere_home' does not exist."
            exit 5
        fi
    fi

    # Get absolute path
    local home_absolute
    home_absolute="$(cd "$adempiere_home" && pwd)"

    # Detect actual package dir name from checksum paths
    local pkg_dir_name
    pkg_dir_name=$(grep "packages/" "$checksum_file" 2>/dev/null | head -1 | sed 's|.*packages/\([^/]*\)/.*|\1|') || true
    pkg_dir_name="${pkg_dir_name:-$pkg_name}"

    local pkg_extract_dir="$home_absolute/packages/$pkg_dir_name"
    local is_overwrite=false
    if [[ -d "$pkg_extract_dir" ]]; then
        is_overwrite=true
    fi

    # List files that will be installed (before extraction)
    echo ""
    if [[ "$is_overwrite" == true ]]; then
        warn "Package '$pkg_dir_name' already exists in $home_absolute"
        info "The following files will be OVERWRITTEN:"
    else
        info "The following files will be installed in $home_absolute:"
    fi

    jar tf "$jar_absolute" | grep '\.jar$' | sort | while read -r f; do
        printf "  %s\n" "$f"
    done
    local file_count
    file_count=$(jar tf "$jar_absolute" | grep -c '\.jar$')
    info "Total: $file_count JARs"
    echo ""

    # Single confirmation per package
    local confirm
    if [[ "$is_overwrite" == true ]]; then
        confirm=$(prompt_user "Overwrite and install '$pkg_name'? [y/N]: ")
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            info "Installation of '$pkg_name' cancelled."
            exit 0
        fi
    else
        confirm=$(prompt_user "Proceed with installation of '$pkg_name'? [Y/n]: ")
        if [[ "$confirm" =~ ^[Nn]$ ]]; then
            info "Installation of '$pkg_name' cancelled."
            exit 0
        fi
    fi

    # Extract archive into ADEMPIERE_HOME
    echo ""
    info "Extracting '$pkg_name' to $home_absolute ..."
    info "  ADEMPIERE_HOME = $home_absolute"
    cd "$home_absolute"
    if ! jar xf "$jar_absolute"; then
        error "Extraction failed"
        exit 6
    fi

    # Verify per-file checksums of extracted files
    if [[ "$skip_verify" == false && -f "$checksum_file" ]]; then
        info "Verifying extracted file checksums..."
        local verify_failed=false

        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            echo "$line" | grep -q "dist/" && continue
            echo "$line" | grep -q "^[a-f0-9]" || continue

            local expected_hash file_path
            expected_hash=$(echo "$line" | awk '{print $1}')
            file_path=$(echo "$line" | awk '{print $2}')
            file_path="${file_path#\*}"

            local full_path="$home_absolute/$file_path"

            if [[ -f "$full_path" ]]; then
                local actual_hash
                actual_hash=$($SHA_CMD "$full_path" | awk '{print $1}')
                if [[ "$expected_hash" != "$actual_hash" ]]; then
                    error "Checksum mismatch: $file_path"
                    verify_failed=true
                fi
            elif echo "$file_path" | grep -q "packages/"; then
                warn "File not found: $full_path"
                verify_failed=true
            fi
        done < "$checksum_file"

        if [[ "$verify_failed" == true ]]; then
            error "INTEGRITY CHECK FAILED: Some files did not match checksums"
            exit 4
        fi
        success "All file checksums verified"
    fi

    # Clean up META-INF created by jar
    rm -rf "$home_absolute/META-INF" 2>/dev/null || true

    echo ""
    echo "========================================"
    success "INSTALLATION SUCCESSFUL"
    info "  Package:        $pkg_name"
    info "  Files deployed: $file_count JARs"
    info "  ADEMPIERE_HOME: $home_absolute"
    info "  Installed to:   $pkg_extract_dir"
    echo "========================================"
}

main "$@"
