#!/bin/bash
# ============================================================
# Setup v2 — installs Kiro CLI, creates project from v2 template
# ============================================================
# Usage:
#   ./setup.sh my-project
# ============================================================

set -e

WORKFLOW_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="$1"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./setup.sh <project-name>"
    exit 1
fi

PROJECT_ROOT="$HOME/projects/$PROJECT_NAME"

echo "============================================"
echo "  Setup v2: $PROJECT_NAME"
echo "============================================"
echo ""

# 1. System deps
echo "[1/3] System dependencies..."
sudo apt-get update -qq
for pkg in git python3 curl unzip ffmpeg xdotool scrot imagemagick; do
    if ! command -v "$pkg" &> /dev/null && ! dpkg -s "$pkg" &> /dev/null 2>&1; then
        sudo apt-get install -y -qq "$pkg"
    fi
done
echo "  Done."
echo ""

# 2. Kiro CLI
echo "[2/3] Kiro CLI..."
if ! command -v kiro-cli &> /dev/null; then
    wget -q https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.deb -O /tmp/kiro-cli.deb
    sudo dpkg -i /tmp/kiro-cli.deb || sudo apt-get install -f -y -qq
    rm -f /tmp/kiro-cli.deb
fi
if ! kiro-cli whoami &> /dev/null; then
    kiro-cli login --use-device-flow
fi
echo "  kiro-cli $(kiro-cli --version 2>/dev/null || echo 'installed')"
echo ""

# 3. Create project
echo "[3/3] Creating project '$PROJECT_NAME'..."
if [ ! -d "$PROJECT_ROOT" ]; then
    mkdir -p "$HOME/projects"
    # Copy from template directory
    mkdir -p "$PROJECT_ROOT"
    cp -r "$WORKFLOW_DIR/copy/.kiro" "$PROJECT_ROOT/"
    cp -r "$WORKFLOW_DIR/copy/archive" "$PROJECT_ROOT/"
    cp -r "$WORKFLOW_DIR/copy/templates" "$PROJECT_ROOT/"
    cp -r "$WORKFLOW_DIR/copy/reports" "$PROJECT_ROOT/"
    cp -r "$WORKFLOW_DIR/copy/src" "$PROJECT_ROOT/"
    cp "$WORKFLOW_DIR/copy/watcher.sh" "$PROJECT_ROOT/"
    cp "$WORKFLOW_DIR/copy/kill-watcher.sh" "$PROJECT_ROOT/"
    chmod +x "$PROJECT_ROOT/watcher.sh" "$PROJECT_ROOT/kill-watcher.sh"
    echo "  Created: $PROJECT_ROOT"
else
    echo "  Already exists: $PROJECT_ROOT"
fi
echo ""

echo "============================================"
echo "  Ready"
echo "============================================"
echo ""
echo "  Project: $PROJECT_ROOT"
echo ""
echo "  Pipeline: coder → code-verifier → backend-tester"
echo "            → frontend-tester → visual-qa → functional-qa"
echo "            → project-lead"
echo ""
echo "  Next steps:"
echo "    1. Write SPEC.md in $PROJECT_ROOT"
echo "       (or use: kiro-cli --agent spec-writer)"
echo "    2. Start: $PROJECT_ROOT/watcher.sh"
echo "    3. Watch it build."
echo ""
