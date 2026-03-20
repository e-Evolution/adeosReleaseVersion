#!/usr/bin/env bash
#
# install-package.sh — Install ADempiere package archives to a target directory
#
# Usage:
#   ./install-package.sh <package.jar> [destination] [--skip-verify]
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

# --- Detect SHA256 command ---
detect_sha_cmd() {
    if command -v sha256sum &>/dev/null; then
        SHA_CMD="sha256sum"
        SHA_CHECK_CMD="sha256sum -c"
    elif command -v shasum &>/dev/null; then
        SHA_CMD="shasum -a 256"
        SHA_CHECK_CMD="shasum -a 256 -c"
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
    echo "Usage: $0 <package.jar> [destination] [--skip-verify]"
    echo ""
    echo "  package.jar    Path to the .jar archive to install"
    echo "  destination    Target ADempiere installation path (default: /opt/Adempiere)"
    echo "  --skip-verify  Skip checksum verification"
    echo ""
    echo "Examples:"
    echo "  $0 dist/MexicanLocation.jar /opt/Adempiere"
    echo "  $0 dist/MexicanLocation.jar                    # interactive prompt"
    echo "  $0 dist/MexicanLocation.jar /opt/Adempiere --skip-verify"
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
    local dest_path=""
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
                elif [[ -z "$dest_path" ]]; then
                    dest_path="$arg"
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

    # Determine destination
    if [[ -z "$dest_path" ]]; then
        local default_dest="/opt/Adempiere"
        printf "Enter ADempiere installation path [%s]: " "$default_dest"
        read -r dest_path
        dest_path="${dest_path:-$default_dest}"
    fi

    # Validate/create destination
    if [[ ! -d "$dest_path" ]]; then
        printf "Destination '%s' does not exist. Create it? [y/N]: " "$dest_path"
        read -r create_dir
        if [[ "$create_dir" =~ ^[Yy]$ ]]; then
            mkdir -p "$dest_path"
            success "Created $dest_path"
        else
            error "Destination '$dest_path' does not exist."
            exit 5
        fi
    fi

    # Get absolute path to destination
    local dest_absolute
    dest_absolute="$(cd "$dest_path" && pwd)"

    # Extract archive
    info "Extracting '$pkg_name' to $dest_absolute ..."
    cd "$dest_absolute"
    if ! jar xf "$jar_absolute"; then
        error "Extraction failed"
        exit 6
    fi

    # Count extracted files
    local extracted_count
    extracted_count=$(find "$dest_absolute/Adempiere/packages/$pkg_name" -type f -name "*.jar" 2>/dev/null | wc -l | tr -d ' ')

    # Verify per-file checksums of extracted files
    if [[ "$skip_verify" == false && -f "$checksum_file" ]]; then
        info "Verifying extracted file checksums..."
        local verify_failed=false

        # Read per-file checksums (exclude the archive-level line)
        while IFS= read -r line; do
            # Skip empty lines and the archive-level checksum
            [[ -z "$line" ]] && continue
            echo "$line" | grep -q "dist/" && continue
            echo "$line" | grep -q "^[a-f0-9]" || continue

            local expected_hash file_path
            expected_hash=$(echo "$line" | awk '{print $1}')
            file_path=$(echo "$line" | awk '{print $2}')

            # Remove leading * if present (binary mode indicator)
            file_path="${file_path#\*}"

            local full_path="$dest_absolute/$file_path"

            if [[ -f "$full_path" ]]; then
                local actual_hash
                actual_hash=$($SHA_CMD "$full_path" | awk '{print $1}')
                if [[ "$expected_hash" != "$actual_hash" ]]; then
                    error "Checksum mismatch: $file_path"
                    verify_failed=true
                fi
            else
                # File path in checksum might be the archive-level entry
                if ! echo "$file_path" | grep -q "\.jar$"; then
                    continue
                fi
                # Only warn if it's a package file, not the archive itself
                if echo "$file_path" | grep -q "Adempiere/packages/"; then
                    warn "File not found: $full_path"
                    verify_failed=true
                fi
            fi
        done < "$checksum_file"

        if [[ "$verify_failed" == true ]]; then
            error "INTEGRITY CHECK FAILED: Some files did not match checksums"
            exit 4
        fi
        success "All file checksums verified"
    fi

    # Clean up META-INF created by jar
    rm -rf "$dest_absolute/META-INF" 2>/dev/null || true

    echo ""
    success "Installed '$pkg_name' ($extracted_count JARs) → $dest_absolute/Adempiere/packages/$pkg_name/"
}

main "$@"
