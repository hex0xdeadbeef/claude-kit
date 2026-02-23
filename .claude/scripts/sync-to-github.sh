#!/bin/bash
# Sync .claude/ and .beads/ to personal GitHub repository
# Usage: ./sync-to-github.sh [commit message]
#
# Setup:
# 1. Create private GitHub repo and set it as origin in your project
# 2. Edit PROJECT_DIR and SYNC_BRANCH below
# 3. Run: chmod +x sync-to-github.sh
# 4. Run: ./sync-to-github.sh "Initial sync"

set -e

# ============================================================
# CONFIGURATION - EDIT THESE VALUES
# ============================================================
PROJECT_DIR="/Users/dmitriym/Desktop/claude-go-kit"
SYNC_BRANCH="sync/initial"
# ============================================================

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Syncing Claude artifacts to GitHub...${NC}"

if [[ "$PROJECT_DIR" == "/path/to/your/project" ]]; then
    echo -e "${RED}ERROR: Edit PROJECT_DIR in this script first${NC}"
    exit 1
fi

cd "$PROJECT_DIR"

# Verify git repo and remote
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}ERROR: $PROJECT_DIR is not a git repository${NC}"
    exit 1
fi

GITHUB_REPO=$(git remote get-url origin 2>/dev/null || echo "")
if [ -z "$GITHUB_REPO" ]; then
    echo -e "${RED}ERROR: No 'origin' remote configured${NC}"
    exit 1
fi

# Force-add .claude/ (global gitignore may exclude it)
git add -f .claude/ 2>/dev/null || true

# Add .beads/ if exists
if [ -d ".beads" ]; then
    git add -f .beads/ 2>/dev/null || true
fi

# Commit message
MSG="${1:-Auto-sync $(date '+%Y-%m-%d %H:%M')}"

if git status --porcelain | grep -q .; then
    git commit -m "$MSG"
fi

# Rebase on top of remote to handle diverged history, then push
UNPUSHED=$(git log "origin/$SYNC_BRANCH..HEAD" --oneline 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNPUSHED" -gt 0 ]; then
    git pull --rebase origin "$SYNC_BRANCH" 2>/dev/null || true
    git push -u origin "$SYNC_BRANCH"
    echo -e "${GREEN}Synced to GitHub!${NC}"
else
    echo -e "${GREEN}No changes to sync${NC}"
fi

echo -e "${GREEN}Project: $PROJECT_DIR${NC}"
echo -e "${GREEN}GitHub: $GITHUB_REPO${NC}"
