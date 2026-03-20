#!/usr/bin/env bash
#
# install-release.sh — Download and install ADempiere packages from GitHub Releases
#
# Usage:
#   ./install-release.sh <PackageName> [destination] [--tag <tag>] [--skip-verify]
#   ./install-release.sh --list [--tag <tag>]
#   ./install-release.sh --all [destination] [--tag <tag>] [--skip-verify]
#
# One-liner install:
#   bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /opt/Adempiere
#
set -euo pipefail

REPO="e-Evolution/adeosReleaseVersion"

# --- Color output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()    { printf "${CYAN}[INFO]${NC} %s\n" "$1"; }
success() { printf "${GREEN}[OK]${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}[WARN]${NC} %s\n" "$1"; }
error()   { printf "${RED}[ERROR]${NC} %s\n" "$1" >&2; }

# --- Detect download tool ---
detect_download_cmd() {
    if command -v curl &>/dev/null; then
        DOWNLOAD_CMD="curl"
    elif command -v wget &>/dev/null; then
        DOWNLOAD_CMD="wget"
    else
        error "Neither 'curl' nor 'wget' found. Install one to proceed."
        exit 1
    fi
}

# --- Download a file ---
download_file() {
    local url="$1"
    local output="$2"

    if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
        curl -fSL --progress-bar -o "$output" "$url"
    else
        wget -q --show-progress -O "$output" "$url"
    fi
}

# --- Detect SHA256 command ---
detect_sha_cmd() {
    if command -v sha256sum &>/dev/null; then
        SHA_CMD="sha256sum"
    elif command -v shasum &>/dev/null; then
        SHA_CMD="shasum -a 256"
    else
        error "No SHA256 tool found."
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

# --- Build base URL for release assets ---
build_base_url() {
    local tag="$1"
    if [[ "$tag" == "latest" ]]; then
        echo "https://github.com/$REPO/releases/latest/download"
    else
        echo "https://github.com/$REPO/releases/download/$tag"
    fi
}

# --- List available packages in a release ---
list_packages() {
    local tag="$1"

    info "Fetching available packages (tag: $tag)..."

    local api_url
    if [[ "$tag" == "latest" ]]; then
        api_url="https://api.github.com/repos/$REPO/releases/latest"
    else
        api_url="https://api.github.com/repos/$REPO/releases/tags/$tag"
    fi

    local response
    if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
        response=$(curl -fsSL "$api_url") || {
            error "Failed to fetch release info. Check tag '$tag' exists."
            exit 2
        }
    else
        response=$(wget -qO- "$api_url") || {
            error "Failed to fetch release info. Check tag '$tag' exists."
            exit 2
        }
    fi

    local release_tag
    release_tag=$(echo "$response" | grep '"tag_name"' | head -1 | sed 's/.*: *"//;s/".*//')

    printf "\n${BOLD}ADempiere Packages — Release %s${NC}\n" "$release_tag"
    printf "%-35s %s\n" "Package" "Size"
    printf "%-35s %s\n" "-----------------------------------" "--------"

    # Parse asset names that end in .jar (not .sha256)
    echo "$response" | grep '"name"' | sed 's/.*: *"//;s/".*//' | grep '\.jar$' | grep -v '\.sha256' | while read -r asset_name; do
        local pkg_name="${asset_name%.jar}"
        local size
        size=$(echo "$response" | grep -A2 "\"$asset_name\"" | grep '"size"' | head -1 | sed 's/[^0-9]//g')
        local size_mb
        if [[ -n "$size" && "$size" -gt 0 ]]; then
            size_mb=$(echo "scale=1; $size / 1048576" | bc 2>/dev/null || echo "?")
            printf "  %-33s %s MB\n" "$pkg_name" "$size_mb"
        else
            printf "  %-33s\n" "$pkg_name"
        fi
    done

    echo ""
}

# --- Install a single package ---
install_package() {
    local pkg_name="$1"
    local dest_path="$2"
    local tag="$3"
    local skip_verify="$4"

    local base_url
    base_url=$(build_base_url "$tag")

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap "rm -rf '$tmp_dir'" EXIT

    local jar_file="$tmp_dir/${pkg_name}.jar"
    local sha_file="$tmp_dir/${pkg_name}.jar.sha256"

    # Download JAR
    info "Downloading ${pkg_name}.jar ..."
    download_file "$base_url/${pkg_name}.jar" "$jar_file" || {
        error "Failed to download '${pkg_name}.jar'. Package may not exist in release '$tag'."
        return 2
    }

    # Download checksum
    if [[ "$skip_verify" == false ]]; then
        info "Downloading ${pkg_name}.jar.sha256 ..."
        download_file "$base_url/${pkg_name}.jar.sha256" "$sha_file" || {
            warn "Checksum file not available. Skipping verification."
            skip_verify=true
        }
    fi

    # Verify archive integrity
    if [[ "$skip_verify" == false && -f "$sha_file" ]]; then
        info "Verifying archive integrity..."
        local archive_line
        archive_line=$(grep "${pkg_name}.jar$" "$sha_file" | grep -v "\.sha256" | tail -1) || true

        if [[ -n "$archive_line" ]]; then
            local expected_hash actual_hash
            expected_hash=$(echo "$archive_line" | awk '{print $1}')
            actual_hash=$($SHA_CMD "$jar_file" | awk '{print $1}')

            if [[ "$expected_hash" != "$actual_hash" ]]; then
                error "INTEGRITY CHECK FAILED for '${pkg_name}.jar'"
                error "  Expected: $expected_hash"
                error "  Actual:   $actual_hash"
                return 4
            fi
            success "Archive checksum verified"
        fi
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
            return 5
        fi
    fi

    local dest_absolute
    dest_absolute="$(cd "$dest_path" && pwd)"

    # Extract
    info "Extracting '$pkg_name' to $dest_absolute ..."
    cd "$dest_absolute"
    if ! jar xf "$jar_file"; then
        error "Extraction failed"
        return 6
    fi

    # Verify per-file checksums
    if [[ "$skip_verify" == false && -f "$sha_file" ]]; then
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

            local full_path="$dest_absolute/$file_path"

            if [[ -f "$full_path" ]]; then
                local actual_hash
                actual_hash=$($SHA_CMD "$full_path" | awk '{print $1}')
                if [[ "$expected_hash" != "$actual_hash" ]]; then
                    error "Checksum mismatch: $file_path"
                    verify_failed=true
                fi
            elif echo "$file_path" | grep -q "Adempiere/packages/"; then
                warn "File not found: $full_path"
                verify_failed=true
            fi
        done < "$sha_file"

        if [[ "$verify_failed" == true ]]; then
            error "INTEGRITY CHECK FAILED: Some files did not match checksums"
            return 4
        fi
        success "All file checksums verified"
    fi

    # Clean up META-INF
    rm -rf "$dest_absolute/META-INF" 2>/dev/null || true

    local extracted_count
    extracted_count=$(find "$dest_absolute/Adempiere/packages/$pkg_name" -type f -name "*.jar" 2>/dev/null | wc -l | tr -d ' ')

    success "Installed '$pkg_name' ($extracted_count JARs) → $dest_absolute/Adempiere/packages/$pkg_name/"
}

# --- Usage ---
usage() {
    cat <<'USAGE'
Usage: install-release.sh <command> [options]

Commands:
  <PackageName> [dest]   Download and install a package
  --all [dest]           Download and install all packages
  --list                 List available packages in a release

Options:
  --tag <tag>            Release tag (default: latest)
  --skip-verify          Skip checksum verification

Examples:
  ./install-release.sh MexicanLocation /opt/Adempiere
  ./install-release.sh --all /opt/Adempiere --tag v3.9.4-LTS-002
  ./install-release.sh --list
  ./install-release.sh --list --tag v3.9.4-LTS-002

One-liner install (no clone needed):
  bash <(curl -sL https://github.com/e-Evolution/adeosReleaseVersion/releases/latest/download/install-release.sh) MexicanLocation /opt/Adempiere
USAGE
    exit 1
}

# --- Main ---
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    detect_download_cmd
    detect_sha_cmd
    check_jar

    local command=""
    local dest_path=""
    local tag="latest"
    local skip_verify=false
    local positional_args=()

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --list)
                command="list"
                shift
                ;;
            --all)
                command="all"
                shift
                ;;
            --tag)
                tag="$2"
                shift 2
                ;;
            --skip-verify)
                skip_verify=true
                shift
                ;;
            --help|-h)
                usage
                ;;
            *)
                positional_args+=("$1")
                shift
                ;;
        esac
    done

    case "$command" in
        list)
            list_packages "$tag"
            ;;
        all)
            dest_path="${positional_args[0]:-}"

            if [[ -z "$dest_path" ]]; then
                local default_dest="/opt/Adempiere"
                printf "Enter ADempiere installation path [%s]: " "$default_dest"
                read -r dest_path
                dest_path="${dest_path:-$default_dest}"
            fi

            info "Installing all packages (tag: $tag) to $dest_path ..."

            # Get package list from API
            local api_url
            if [[ "$tag" == "latest" ]]; then
                api_url="https://api.github.com/repos/$REPO/releases/latest"
            else
                api_url="https://api.github.com/repos/$REPO/releases/tags/$tag"
            fi

            local response
            if [[ "$DOWNLOAD_CMD" == "curl" ]]; then
                response=$(curl -fsSL "$api_url")
            else
                response=$(wget -qO- "$api_url")
            fi

            local packages
            packages=$(echo "$response" | grep '"name"' | sed 's/.*: *"//;s/".*//' | grep '\.jar$' | grep -v '\.sha256' | sed 's/\.jar$//')

            local installed=0 failed=0
            while IFS= read -r pkg_name; do
                [[ -z "$pkg_name" ]] && continue
                echo ""
                # Use subshell to isolate trap and cd
                (install_package "$pkg_name" "$dest_path" "$tag" "$skip_verify") && {
                    installed=$((installed + 1))
                } || {
                    failed=$((failed + 1))
                }
            done <<< "$packages"

            echo ""
            success "Done. Installed $installed packages ($failed failures) → $dest_path"
            ;;
        *)
            # Single package install
            local pkg_name="${positional_args[0]:-}"
            dest_path="${positional_args[1]:-}"

            if [[ -z "$pkg_name" ]]; then
                usage
            fi

            install_package "$pkg_name" "$dest_path" "$tag" "$skip_verify"
            ;;
    esac
}

main "$@"
