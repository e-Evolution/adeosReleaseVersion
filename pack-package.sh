#!/usr/bin/env bash
#
# pack-package.sh — Pack ADempiere packages into distributable .jar archives
#
# Usage:
#   ./pack-package.sh <PackageName>    Pack a single package
#   ./pack-package.sh --all            Pack all packages
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGES_DIR="$SCRIPT_DIR/Adempiere/packages"
DIST_DIR="$SCRIPT_DIR/dist"

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
    echo "Usage: $0 <PackageName|--all>"
    echo ""
    echo "  PackageName    Name of package under Adempiere/packages/"
    echo "  --all          Pack all packages"
    echo ""
    echo "Examples:"
    echo "  $0 MexicanLocation"
    echo "  $0 --all"
    exit 1
}

# --- Map directory name to distribution name ---
dist_name() {
    local dir_name="$1"
    case "$dir_name" in
        Scala) echo "Scala-Package-Libs" ;;
        *)     echo "$dir_name" ;;
    esac
}

# --- Pack a single package ---
pack_package() {
    local pkg_name="$1"
    local pkg_dir="$PACKAGES_DIR/$pkg_name"

    # Validate package directory exists
    if [[ ! -d "$pkg_dir" ]]; then
        error "Package '$pkg_name' not found under Adempiere/packages/"
        return 2
    fi

    # Find all JAR files in the package (any depth)
    local jar_count
    jar_count=$(find "$pkg_dir" -name "*.jar" -type f | wc -l | tr -d ' ')

    if [[ "$jar_count" -eq 0 ]]; then
        warn "Package '$pkg_name' has no JAR files, skipping"
        return 3
    fi

    local output_name
    output_name=$(dist_name "$pkg_name")

    info "Packing '$pkg_name' as '$output_name' ($jar_count JARs)..."

    # Create dist directory
    mkdir -p "$DIST_DIR"

    local archive="$DIST_DIR/${output_name}.jar"
    local checksum_file="$DIST_DIR/${output_name}.jar.sha256"
    local relative_path="packages/${pkg_name}"

    # Clean .DS_Store files before archiving
    find "$pkg_dir" -name ".DS_Store" -type f -delete 2>/dev/null || true

    # Generate per-file SHA256 checksums (relative to Adempiere/ base)
    cd "$SCRIPT_DIR/Adempiere"
    > "$checksum_file"

    while IFS= read -r -d '' file; do
        local rel_file="${file#$SCRIPT_DIR/Adempiere/}"
        $SHA_CMD "$rel_file" >> "$checksum_file"
    done < <(find "$relative_path" -type f -name "*.jar" -print0 | sort -z)

    # Create archive with jar command from Adempiere/ base
    # Internal paths: packages/<name>/lib/...
    rm -f "$archive"
    jar cf "$archive" "$relative_path/"

    # Append archive-level checksum
    $SHA_CMD "$archive" >> "$checksum_file"

    # Summary
    local archive_size
    archive_size=$(du -h "$archive" | cut -f1 | tr -d ' ')

    success "Packed '$pkg_name' → $archive ($archive_size, $jar_count JARs)"
}

# --- Main ---
main() {
    if [[ $# -eq 0 ]]; then
        usage
    fi

    check_jar
    detect_sha_cmd

    if [[ "$1" == "--all" ]]; then
        info "Packing all packages..."
        local failed=0
        local packed=0

        for pkg_dir in "$PACKAGES_DIR"/*/; do
            local pkg_name
            pkg_name=$(basename "$pkg_dir")
            pack_package "$pkg_name" || {
                local rc=$?
                if [[ $rc -eq 3 ]]; then
                    continue  # Skip empty packages
                fi
                failed=$((failed + 1))
            }
            packed=$((packed + 1))
        done

        echo ""
        success "Done. Packed $packed packages ($failed failures) → dist/"
    else
        pack_package "$1"
    fi
}

main "$@"
