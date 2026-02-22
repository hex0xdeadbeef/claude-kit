#!/bin/bash
# Sync .claude/ and .beads/ to personal GitHub repository
# Usage: ./sync-to-github.sh [commit message]
#
# Setup:
# 1. Create private GitHub repo (e.g., my-project-claude-config)
# 2. Edit GITHUB_REPO, BACKUP_DIR, PROJECT_DIR below
# 3. Run: chmod +x sync-to-github.sh
# 4. Run: ./sync-to-github.sh "Initial sync"

set -e

# ============================================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================================
GITHUB_REPO="https://github.com/hex0xdeadbeef/claude-kit.git"
BACKUP_DIR="$HOME/.claude-sync/claude-kit"
PROJECT_DIR="/Users/dmitriym/Desktop/claude-go-kit"
SYNC_BRANCH="sync/initial"
# ============================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Syncing Claude artifacts to GitHub...${NC}"

# Validate configuration
if [[ "$GITHUB_REPO" == *"YOUR_USERNAME"* ]]; then
    echo -e "${RED}ERROR: Edit GITHUB_REPO in this script first${NC}"
    exit 1
fi

if [[ "$PROJECT_DIR" == "/path/to/your/project" ]]; then
    echo -e "${RED}ERROR: Edit PROJECT_DIR in this script first${NC}"
    exit 1
fi

# Create backup directory if not exists
mkdir -p "$BACKUP_DIR"

# Initialize git if needed
if [ ! -d "$BACKUP_DIR/.git" ]; then
    echo -e "${YELLOW}Initializing repository...${NC}"
    cd "$BACKUP_DIR"
    git init
    git remote add origin "$GITHUB_REPO" 2>/dev/null || git remote set-url origin "$GITHUB_REPO"
    git checkout -b "$SYNC_BRANCH" 2>/dev/null || git checkout "$SYNC_BRANCH"
fi

# Sync .claude/ files
echo -e "${YELLOW}Copying .claude/ files...${NC}"
rsync -av --delete \
    --exclude='.git' \
    --exclude='*.log' \
    --exclude='node_modules' \
    --exclude='__pycache__' \
    "$PROJECT_DIR/.claude/" "$BACKUP_DIR/.claude/"

# Sync .beads/ if exists
if [ -d "$PROJECT_DIR/.beads" ]; then
    echo -e "${YELLOW}Copying .beads/ files...${NC}"
    rsync -av --delete \
        --exclude='.git' \
        --exclude='*.db-wal' \
        --exclude='*.db-shm' \
        --exclude='daemon.pid' \
        --exclude='daemon.lock' \
        "$PROJECT_DIR/.beads/" "$BACKUP_DIR/.beads/"
fi

# Commit and push
cd "$BACKUP_DIR"
# Force-add .claude/ because global gitignore may exclude it
git add -f .claude/ 2>/dev/null || true
[ -d ".beads" ] && git add -f .beads/ 2>/dev/null || true
git add -A

# Commit message
MSG="${1:-Auto-sync $(date '+%Y-%m-%d %H:%M')}"

if git status --porcelain | grep -q .; then
    git commit -m "$MSG"
    git push -u origin "$SYNC_BRANCH"
    echo -e "${GREEN}Synced to GitHub!${NC}"
else
    echo -e "${GREEN}No changes to sync${NC}"
fi

echo -e "${GREEN}Backup location: $BACKUP_DIR${NC}"
echo -e "${GREEN}GitHub: $GITHUB_REPO${NC}"
