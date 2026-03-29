#!/usr/bin/env bash
# Claude Kit Installer
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/hex0xdeadbeef/claude-kit/main/install.sh | bash
#   KIT_VERSION=v1.0.0 bash install.sh    # specific version
#   bash install.sh --update               # update existing installation
#
# Environment:
#   KIT_VERSION   — install specific version (default: latest)
#   INSTALL_DIR   — target directory (default: current directory)

set -euo pipefail

# ── Configuration ──────────────────────────────────────────────────────────────
REPO="hex0xdeadbeef/claude-kit"
KIT_VERSION="${KIT_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-.}"

# ── Colors (only when writing to a terminal) ───────────────────────────────────
if [ -t 1 ]; then
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' BOLD='' NC=''
fi

# ── Logging ────────────────────────────────────────────────────────────────────
info()  { echo -e "${GREEN}[kit]${NC} $1"; }
warn()  { echo -e "${YELLOW}[kit]${NC} $1"; }
error() { echo -e "${RED}[kit]${NC} $1" >&2; }

# ── Usage ──────────────────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Claude Kit Installer

Usage:
  curl -sL https://raw.githubusercontent.com/${REPO}/main/install.sh | bash
  bash install.sh [--update] [--help]

Options:
  --update    Update existing installation (creates backup first)
  --help      Show this help

Environment:
  KIT_VERSION=v1.0.0    Install specific version (default: latest)
  INSTALL_DIR=/path     Install to specific directory (default: .)
EOF
}

# ── HTTP fetch (curl or wget) ──────────────────────────────────────────────────
fetch() {
    local url="$1"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url"
    elif command -v wget &>/dev/null; then
        wget -qO- "$url"
    else
        error "Neither curl nor wget found. Please install one."
        exit 1
    fi
}

# ── Resolve version ────────────────────────────────────────────────────────────
resolve_version() {
    if [ "$KIT_VERSION" != "latest" ]; then
        echo "$KIT_VERSION"
        return
    fi

    # Try GitHub API first
    local api_response
    api_response=$(fetch "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || echo "")

    local version
    version=$(echo "$api_response" | grep '"tag_name"' | head -1 | sed -E 's/.*"([^"]+)".*/\1/')

    if [ -n "$version" ]; then
        echo "$version"
        return
    fi

    # Fallback: git ls-remote (no API rate limit)
    version=$(git ls-remote --tags --sort=-v:refname "https://github.com/${REPO}.git" 'v*' 2>/dev/null \
        | head -1 | sed 's|.*refs/tags/||')

    if [ -n "$version" ]; then
        echo "$version"
        return
    fi

    error "Could not determine latest version."
    error "Set KIT_VERSION explicitly: KIT_VERSION=v1.0.0 bash install.sh"
    exit 1
}

# ── Download and extract ───────────────────────────────────────────────────────
download_and_extract() {
    local version="$1"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    local tarball_url="https://github.com/${REPO}/releases/download/${version}/claude-kit-${version}.tar.gz"

    info "Downloading Claude Kit ${version}..."

    if ! fetch "$tarball_url" | tar xz -C "$tmp_dir" 2>/dev/null; then
        rm -rf "$tmp_dir"
        error "Download failed. Check that version ${version} exists:"
        error "  https://github.com/${REPO}/releases"
        exit 1
    fi

    echo "$tmp_dir"
}

# ── Backup existing installation ───────────────────────────────────────────────
backup_existing() {
    local target_dir="$1"
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_dir="${target_dir}/.claude.backup.${timestamp}"

    cp -r "${target_dir}/.claude" "$backup_dir"
    info "Backup created: ${backup_dir}/"
    echo "$backup_dir"
}

# ── Merge .gitignore ───────────────────────────────────────────────────────────
merge_gitignore() {
    local kit_gitignore="$1"
    local target_dir="$2"
    local target_gitignore="${target_dir}/.gitignore"

    if [ ! -f "$kit_gitignore" ]; then
        return
    fi

    local start_marker="# --- Claude Kit (managed by install.sh -- do not edit this section) ---"
    local end_marker="# --- End Claude Kit ---"

    if [ ! -f "$target_gitignore" ]; then
        # No existing .gitignore — create with markers
        {
            echo "$start_marker"
            cat "$kit_gitignore"
            echo "$end_marker"
        } > "$target_gitignore"
        info "Created .gitignore with kit patterns"
        return
    fi

    # Remove existing kit section if present (cross-platform: awk + tmp file, no sed -i)
    if grep -qF "$start_marker" "$target_gitignore"; then
        local tmp_file
        tmp_file=$(mktemp)
        awk -v start="$start_marker" -v end="$end_marker" '
            $0 == start { skip=1; next }
            $0 == end   { skip=0; next }
            !skip
        ' "$target_gitignore" > "$tmp_file"
        mv "$tmp_file" "$target_gitignore"
    fi

    # Append updated kit section
    {
        echo ""
        echo "$start_marker"
        cat "$kit_gitignore"
        echo "$end_marker"
    } >> "$target_gitignore"

    info "Merged .gitignore (kit patterns updated)"
}

# ── Write version file ─────────────────────────────────────────────────────────
write_version() {
    local version="$1"
    local target_dir="$2"

    cat > "${target_dir}/.claude/.kit-version" <<EOF
version: ${version}
source: https://github.com/${REPO}
installed_at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
EOF
}

# ── Main ───────────────────────────────────────────────────────────────────────
main() {
    local update_mode=false

    for arg in "$@"; do
        case "$arg" in
            --update) update_mode=true ;;
            --help|-h) usage; exit 0 ;;
            *) warn "Unknown argument: $arg" ;;
        esac
    done

    local target_dir="$INSTALL_DIR"
    target_dir=$(cd "$target_dir" && pwd)

    # Check existing installation
    if [ -f "${target_dir}/.claude/.kit-version" ]; then
        local current_version
        current_version=$(grep '^version:' "${target_dir}/.claude/.kit-version" | awk '{print $2}')

        if [ "$update_mode" = false ]; then
            warn "Claude Kit ${current_version} already installed in ${target_dir}"
            warn "Run with --update to upgrade: bash install.sh --update"
            exit 0
        fi
    fi

    # Resolve version
    local version
    version=$(resolve_version)
    info "Version: ${version}"

    # Download
    local tmp_dir
    tmp_dir=$(download_and_extract "$version")
    local src_dir="${tmp_dir}/claude-kit-${version}"

    if [ ! -d "$src_dir" ]; then
        # Handle case where archive root dir has a different name
        src_dir=$(find "$tmp_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
    fi

    if [ ! -d "${src_dir}/.claude" ]; then
        rm -rf "$tmp_dir"
        error "Invalid archive: .claude/ directory not found"
        exit 1
    fi

    # Backup before update (REVISE: declare backup_dir before conditional to satisfy shellcheck)
    local backup_dir=""
    if [ "$update_mode" = true ] && [ -d "${target_dir}/.claude" ]; then
        backup_dir=$(backup_existing "$target_dir")
    fi

    # Install .claude/
    info "Installing .claude/ ..."
    if [ -d "${target_dir}/.claude" ]; then
        # Preserve settings.local.json across update
        local saved_local_settings=""
        if [ -f "${target_dir}/.claude/settings.local.json" ]; then
            saved_local_settings=$(mktemp)
            cp "${target_dir}/.claude/settings.local.json" "$saved_local_settings"
        fi

        rm -rf "${target_dir}/.claude"
        cp -r "${src_dir}/.claude" "${target_dir}/.claude"

        # Restore settings.local.json
        if [ -n "$saved_local_settings" ]; then
            cp "$saved_local_settings" "${target_dir}/.claude/settings.local.json"
            rm -f "$saved_local_settings"
            info "Preserved settings.local.json"
        fi
    else
        cp -r "${src_dir}/.claude" "${target_dir}/.claude"
    fi

    # Install CLAUDE.md
    cp "${src_dir}/CLAUDE.md" "${target_dir}/CLAUDE.md"
    info "Installed CLAUDE.md"

    # Merge .gitignore
    merge_gitignore "${src_dir}/.gitignore" "$target_dir"

    # Write version
    write_version "$version" "$target_dir"

    # Ensure runtime directories exist
    mkdir -p "${target_dir}/.claude/workflow-state"
    mkdir -p "${target_dir}/.claude/prompts"

    # Cleanup
    rm -rf "$tmp_dir"

    # Diff-summary for updates (spec HIGH-risk mitigation: show what changed in settings.json)
    if [ "$update_mode" = true ] && [ -n "$backup_dir" ]; then
        echo ""
        info "Update summary:"
        local settings_diff
        settings_diff=$(diff "${backup_dir}/settings.json" \
            "${target_dir}/.claude/settings.json" 2>/dev/null || true)

        if [ -z "$settings_diff" ]; then
            info "  settings.json — no changes"
        else
            warn "  settings.json changed. Your previous version is at:"
            warn "    ${backup_dir}/settings.json"
            echo ""
            echo "--- Previous    +++ New (first 20 lines of diff) ---"
            echo "$settings_diff" | head -20
        fi
    fi

    # Success
    echo ""
    info "${BOLD}Claude Kit ${version} installed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Edit CLAUDE.md — update Language Profile to match your project stack"
    echo "  2. Run /project-researcher — analyze codebase, generate PROJECT-KNOWLEDGE.md"
    echo "  3. Run /meta-agent onboard — validate configuration"
    echo ""
    echo -e "${BLUE}Optional:${NC}"
    echo "  cp .claude/settings.local.json.example .claude/settings.local.json"
    echo "  # Personal overrides (git-ignored, never overwritten by updates)"
    echo ""
}

main "$@"
