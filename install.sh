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
info()  { echo -e "${GREEN}[kit]${NC} $1" >&2; }
warn()  { echo -e "${YELLOW}[kit]${NC} $1" >&2; }
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
    # grep -v '^{}' filters out annotated tag dereference lines (e.g. v1.0.0^{})
    version=$(git ls-remote --tags --sort=-v:refname "https://github.com/${REPO}.git" 'v*' 2>/dev/null \
        | grep -v '\^{}' | head -1 | sed 's|.*refs/tags/||')

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

# ── Get base skill names (from new archive) ────────────────────────────────────
# Returns newline-separated skill directory names present in src_dir/.claude/skills/.
# "Base skills" = skills shipped in the new kit version. Anything in backup but
# NOT in this list is considered a user-added custom skill.
get_base_skills() {
    local src_dir="$1"
    local skills_dir="${src_dir}/.claude/skills"

    if [ ! -d "$skills_dir" ]; then
        return 0
    fi

    find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort
}

# ── Parse key=value pairs from restore-function output ─────────────────────────
# Each restore function emits exactly ONE line of "key1=val1 key2=val2 ..." to
# stdout. parse_kv extracts the values in order, one per line, for `read -r`
# consumption. awk's split() with n=split(...) returns the last field (kv[n]),
# so values containing `=` (unlikely but possible) are handled correctly.
# Example: parse_kv "restored=3 collisions=1" → "3\n1\n"
parse_kv() {
    awk '{ for (i = 1; i <= NF; i++) { n = split($i, kv, "="); print kv[n] } }' <<<"$1"
}

# ── Restore user prompts from backup ───────────────────────────────────────────
# Copies files from backup_dir/prompts/ into target_dir/.claude/prompts/.
# Collision: keep new archive file; backup file is restored with -old suffix
# (foo.md → foo-old.md), so the user can compare both versions.
# Output: "restored=N collisions=M" (caller parses).
restore_prompts() {
    local backup_dir="$1"
    local target_dir="$2"
    local backup_prompts="${backup_dir}/prompts"
    local target_prompts="${target_dir}/.claude/prompts"

    local restored=0
    local collisions=0

    if [ ! -d "$backup_prompts" ]; then
        echo "restored=0 collisions=0"
        return 0
    fi

    mkdir -p "$target_prompts"

    local file filename target_file old_file stem
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        target_file="${target_prompts}/${filename}"

        if [ -e "$target_file" ]; then
            if [[ "$filename" == *.md ]]; then
                stem="${filename%.md}"
                old_file="${target_prompts}/${stem}-old.md"
            else
                old_file="${target_prompts}/${filename}.old"
            fi
            cp "$file" "$old_file"
            collisions=$((collisions + 1))
        else
            cp "$file" "$target_file"
            restored=$((restored + 1))
        fi
    done < <(find "$backup_prompts" -mindepth 1 -maxdepth 1 -type f -print0)

    echo "restored=${restored} collisions=${collisions}"
}

# ── Restore non-base (user) skill directories from backup ──────────────────────
# A "custom skill" is a skill directory present in backup but NOT in the new
# archive's .claude/skills/. Such dirs are copied wholesale to the new install.
# Idempotent: if the target already contains the same custom skill (e.g., from
# a prior --update), it is refreshed from backup (overwrite).
# Output: "restored=N".
restore_custom_skills() {
    local backup_dir="$1"
    local src_dir="$2"
    local target_dir="$3"
    local backup_skills="${backup_dir}/skills"
    local target_skills="${target_dir}/.claude/skills"

    local restored=0

    if [ ! -d "$backup_skills" ]; then
        echo "restored=0"
        return 0
    fi

    local base_skills
    base_skills=$(get_base_skills "$src_dir")

    mkdir -p "$target_skills"

    local skill_path skill_name
    while IFS= read -r -d '' skill_path; do
        skill_name=$(basename "$skill_path")

        # `--` separates options from pattern (defensive — skill names never start
        # with `-` in practice, but the guard is free).
        if printf '%s\n' "$base_skills" | grep -Fxq -- "$skill_name"; then
            continue
        fi

        if [ -d "${target_skills}/${skill_name}" ]; then
            # SC2115 guard: ${var:?} aborts if either var is empty, preventing
            # accidental `rm -rf /` if function args ever come in unset.
            rm -rf "${target_skills:?}/${skill_name:?}"
        fi
        cp -r "$skill_path" "${target_skills}/${skill_name}"
        restored=$((restored + 1))
    done < <(find "$backup_skills" -mindepth 1 -maxdepth 1 -type d -print0)

    echo "restored=${restored}"
}

# ── Restore user-created commands/agents from backup ───────────────────────────
# For each of {commands, agents}: copy top-level files and dirs from backup
# that are absent in the new archive. Handles flat .md files (commands/foo.md,
# agents/foo.md) AND nested-dir agents (agents/my-agent/).
# Output: "restored=N" (count of copied items, both files and dirs).
restore_custom_files() {
    local backup_dir="$1"
    local src_dir="$2"
    local target_dir="$3"

    local restored=0
    local subdir backup_subdir src_subdir target_subdir
    local file dir filename dirname

    for subdir in commands agents; do
        backup_subdir="${backup_dir}/${subdir}"
        src_subdir="${src_dir}/.claude/${subdir}"
        target_subdir="${target_dir}/.claude/${subdir}"

        if [ ! -d "$backup_subdir" ]; then
            continue
        fi

        mkdir -p "$target_subdir"

        while IFS= read -r -d '' file; do
            filename=$(basename "$file")
            if [ ! -e "${src_subdir}/${filename}" ]; then
                cp "$file" "${target_subdir}/${filename}"
                restored=$((restored + 1))
            fi
        done < <(find "$backup_subdir" -mindepth 1 -maxdepth 1 -type f -name "*.md" -print0)

        while IFS= read -r -d '' dir; do
            dirname=$(basename "$dir")
            if [ ! -e "${src_subdir}/${dirname}" ]; then
                cp -r "$dir" "${target_subdir}/${dirname}"
                restored=$((restored + 1))
            fi
        done < <(find "$backup_subdir" -mindepth 1 -maxdepth 1 -type d -print0)
    done

    echo "restored=${restored}"
}

# ── Restore .claude/PROJECT-KNOWLEDGE.md from backup ───────────────────────────
# Generated by /project-researcher per-project — the archive never ships this
# file, so no collision handling is needed: copy from backup if present.
# Output: "restored=N" (0 or 1).
restore_project_knowledge() {
    local backup_dir="$1"
    local target_dir="$2"
    local src_file="${backup_dir}/PROJECT-KNOWLEDGE.md"
    local target_file="${target_dir}/.claude/PROJECT-KNOWLEDGE.md"

    if [ ! -f "$src_file" ]; then
        echo "restored=0"
        return 0
    fi

    cp "$src_file" "$target_file"
    echo "restored=1"
}

# ── Merge non-base skills into frontmatter skills: lists ───────────────────────
# For every .md file in target commands/ and agents/ (recursive), if a matching
# backup file exists and contains custom skills in its frontmatter skills: list,
# merge those custom skills into the new file's frontmatter. Base skills (from
# the new archive) take priority and order; custom skills are appended.
# Idempotent: skills already present are not duplicated.
# Soft dep: python3 required for safe YAML manipulation. Missing → warn + skip.
# Output: "merged=N skills_added=K" (N files modified, K total skills added).
#
# NOTE: The PYEOF delimiter and EVERY python line below MUST start at column 0.
# The single-quoted heredoc form <<'PYEOF' preserves all leading whitespace
# verbatim, so any indentation here will be passed to python3 and cause
# IndentationError. Bash continues to parse the heredoc correctly even when
# the body is unindented inside an indented function — this is by design.
merge_frontmatter_skills() {
    local backup_dir="$1"
    local src_dir="$2"
    local target_dir="$3"

    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping frontmatter skills merge"
        echo "merged=0 skills_added=0"
        return 0
    fi

    local base_skills
    base_skills=$(get_base_skills "$src_dir")

    local merged=0
    local skills_added=0
    local subdir target_subdir backup_subdir target_file rel_path backup_file added

    for subdir in commands agents; do
        target_subdir="${target_dir}/.claude/${subdir}"
        backup_subdir="${backup_dir}/${subdir}"

        if [ ! -d "$target_subdir" ] || [ ! -d "$backup_subdir" ]; then
            continue
        fi

        while IFS= read -r -d '' target_file; do
            # Quoted-pattern form forces literal match (avoids glob interpretation
            # if INSTALL_DIR contains [, *, ?).
            rel_path="${target_file#"${target_subdir}/"}"
            backup_file="${backup_subdir}/${rel_path}"

            [ -f "$backup_file" ] || continue

            added=$(python3 - "$target_file" "$backup_file" "$base_skills" <<'PYEOF' 2>/dev/null || echo 0
import re
import sys

target_path = sys.argv[1]
backup_path = sys.argv[2]
base_skills = set(sys.argv[3].split())

# SKILLS_RE: each item line is `  - name` optionally followed by `  # comment`.
# ITEM_RE captures only the skill name; comment portion is non-capturing.
# NOTE: inline comments are PRESERVED during read (regex accepts them) but
# DROPPED on rewrite — the merged skills list is emitted in plain form.
SKILLS_RE = re.compile(
    r'^skills:[ \t]*\n((?:[ \t]+-[ \t]+\S+(?:[ \t]+#[^\n]*)?[ \t]*\n)+)',
    re.MULTILINE,
)
ITEM_RE = re.compile(r'^[ \t]+-[ \t]+(\S+)(?:[ \t]+#[^\n]*)?[ \t]*$', re.MULTILINE)
FM_RE = re.compile(r'^---\n(.*?)\n---\n?(.*)', re.DOTALL)


def parse(text):
    m = FM_RE.match(text)
    if not m:
        return None, None, [], False
    fm, body = m.group(1), m.group(2)
    # FM_RE strips the trailing newline of the last frontmatter line. SKILLS_RE
    # requires each item line to end with \n, so search on (fm + '\n') to ensure
    # the last skills item is captured even when it is the last frontmatter line.
    sm = SKILLS_RE.search(fm + '\n')
    if not sm:
        return fm, body, [], False
    items = ITEM_RE.findall(sm.group(1))
    return fm, body, items, True


with open(backup_path, 'r', encoding='utf-8') as f:
    backup_text = f.read()
_, _, backup_skills, _ = parse(backup_text)
custom = [s for s in backup_skills if s not in base_skills]
if not custom:
    print(0)
    sys.exit(0)

with open(target_path, 'r', encoding='utf-8') as f:
    target_text = f.read()
target_fm, target_body, target_skills, has_block = parse(target_text)
if target_fm is None:
    print(0)
    sys.exit(0)

merged_skills = list(target_skills)
added_count = 0
for s in custom:
    if s not in merged_skills:
        merged_skills.append(s)
        added_count += 1

if added_count == 0:
    print(0)
    sys.exit(0)

new_block = 'skills:\n' + ''.join(f'  - {s}\n' for s in merged_skills)
if has_block:
    # Sub on (target_fm + '\n') for the same reason as parse(): SKILLS_RE
    # requires each item line to end with \n. Strip the synthetic trailing \n
    # afterwards so the assembly below produces a single \n before '---'.
    new_fm = SKILLS_RE.sub(new_block, target_fm + '\n', count=1).rstrip('\n')
else:
    new_fm = target_fm.rstrip('\n') + '\n' + new_block.rstrip('\n')

new_text = '---\n' + new_fm + '\n---\n' + target_body
with open(target_path, 'w', encoding='utf-8') as f:
    f.write(new_text)

print(added_count)
PYEOF
            )

            if [ "${added:-0}" -gt 0 ] 2>/dev/null; then
                merged=$((merged + 1))
                skills_added=$((skills_added + added))
            fi
        done < <(find "$target_subdir" -type f -name "*.md" -print0)
    done

    echo "merged=${merged} skills_added=${skills_added}"
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

    # Download (global so EXIT trap can access it after main() returns)
    info "Downloading Claude Kit ${version}..."
    tmp_dir=$(download_and_extract "$version")
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM
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

    # Restore user data from backup (--update only).
    #
    # Function output invariant (uniformly enforced via parse_kv below):
    #   each restore function echoes EXACTLY ONE line to stdout, formatted as
    #   "key1=val1 key2=val2 ..." (space-separated). Logs go to stderr via
    #   info()/warn() and are excluded from the parsed result.
    local prompts_restored=0 prompts_collisions=0
    local custom_skills_restored=0
    local custom_files_restored=0
    local pk_restored=0
    local fm_files_merged=0 fm_skills_added=0
    local _result

    if [ "$update_mode" = true ] && [ -n "$backup_dir" ]; then
        _result=$(restore_prompts "$backup_dir" "$target_dir") || _result="restored=0 collisions=0"
        read -r prompts_restored prompts_collisions < <(parse_kv "$_result")

        _result=$(restore_custom_skills "$backup_dir" "$src_dir" "$target_dir") || _result="restored=0"
        read -r custom_skills_restored < <(parse_kv "$_result")

        _result=$(restore_custom_files "$backup_dir" "$src_dir" "$target_dir") || _result="restored=0"
        read -r custom_files_restored < <(parse_kv "$_result")

        _result=$(restore_project_knowledge "$backup_dir" "$target_dir") || _result="restored=0"
        read -r pk_restored < <(parse_kv "$_result")

        _result=$(merge_frontmatter_skills "$backup_dir" "$src_dir" "$target_dir") || _result="merged=0 skills_added=0"
        read -r fm_files_merged fm_skills_added < <(parse_kv "$_result")
    fi

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

        info "  prompts restored: ${prompts_restored} (collisions saved as -old: ${prompts_collisions})"
        info "  custom skills restored: ${custom_skills_restored}"
        info "  custom commands/agents restored: ${custom_files_restored}"
        info "  PROJECT-KNOWLEDGE.md restored: ${pk_restored}"
        info "  frontmatter skills merged: ${fm_files_merged} files (${fm_skills_added} skills added)"
    fi

    # Success
    echo ""
    info "${BOLD}Claude Kit ${version} installed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Edit CLAUDE.md — update Language Profile to match your project stack"
    echo "  2. Run /project-researcher — analyze codebase, generate .claude/PROJECT-KNOWLEDGE.md"
    echo "  3. Run /meta-agent onboard — validate configuration"
    echo ""
    echo -e "${BLUE}Optional:${NC}"
    echo "  cp .claude/settings.local.json.example .claude/settings.local.json"
    echo "  # Personal overrides (git-ignored, never overwritten by updates)"
    echo ""
}

# ── Entry point ────────────────────────────────────────────────────────────────
# Sourcing guard: run main only when executed directly, not when sourced.
# Allows tests to source restore functions without triggering the installer.
# ${BASH_SOURCE[0]:-$0}: when piped via `curl | bash -s`, BASH_SOURCE[0] is
# unset/empty and $0 is "bash" — fallback to $0 makes the test pass correctly.
# When sourced, BASH_SOURCE[0] is the script path while $0 is the parent shell.
if [ "${BASH_SOURCE[0]:-$0}" = "$0" ]; then
    main "$@"
fi
