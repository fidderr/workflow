#!/bin/bash
# ============================================================
# Setup — installs everything, creates agent + project
# ============================================================
# Prerequisites:
#   cp .env.example .env && nano .env
#
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
WORKSPACE_DIR="$HOME/.openclaw/workspace-$PROJECT_NAME"
ENV_FILE="$WORKFLOW_DIR/.env"

# Check .env
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env not found."
    echo "  cp .env.example .env && nano .env"
    exit 1
fi
source "$ENV_FILE"

echo "============================================"
echo "  Setup: $PROJECT_NAME"
echo "============================================"
echo ""

# ----------------------------------------------------------
# 1. System deps
# ----------------------------------------------------------
echo "[1/6] System dependencies..."
sudo apt-get update -qq
for pkg in git python3 curl unzip ffmpeg xdotool scrot imagemagick xvfb; do
    if ! command -v "$pkg" &> /dev/null && ! dpkg -s "$pkg" &> /dev/null 2>&1; then
        sudo apt-get install -y -qq "$pkg"
    fi
done
echo "  Done."
echo ""

# ----------------------------------------------------------
# 2. Node.js
# ----------------------------------------------------------
echo "[2/6] Node.js..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
fi
echo "  node $(node --version), npm $(npm --version)"
echo ""

# ----------------------------------------------------------
# 3. OpenClaw
# ----------------------------------------------------------
echo "[3/6] OpenClaw..."
if ! command -v openclaw &> /dev/null; then
    npm install -g openclaw
fi
if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
    echo "  Running onboarding wizard..."
    openclaw onboard
else
    echo "  Already configured."
fi
echo ""

# ----------------------------------------------------------
# 4. Kiro CLI
# ----------------------------------------------------------
echo "[4/6] Kiro CLI..."
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

# ----------------------------------------------------------
# 5. Create project (copy template)
# ----------------------------------------------------------
echo "[5/6] Creating project '$PROJECT_NAME'..."
if [ ! -d "$PROJECT_ROOT" ]; then
    mkdir -p "$HOME/projects"
    cp -r "$WORKFLOW_DIR/copy" "$PROJECT_ROOT"
    mkdir -p "$PROJECT_ROOT/src"
    chmod +x "$PROJECT_ROOT/watcher.sh"
    echo "$PROJECT_NAME" > "$PROJECT_ROOT/.agent-name"
    echo "  Created: $PROJECT_ROOT"
else
    echo "  Already exists: $PROJECT_ROOT"
fi
echo ""

# ----------------------------------------------------------
# 6. Create OpenClaw agent
# ----------------------------------------------------------
echo "[6/6] Creating agent '$PROJECT_NAME'..."
mkdir -p "$WORKSPACE_DIR"
cp "$WORKFLOW_DIR/soul.md" "$WORKSPACE_DIR/SOUL.md"
cp "$WORKFLOW_DIR/TOOLS.md" "$WORKSPACE_DIR/TOOLS.md"

if ! openclaw agents list 2>/dev/null | grep -q "$PROJECT_NAME"; then
    openclaw agents add "$PROJECT_NAME" \
        --workspace "$WORKSPACE_DIR" \
        --non-interactive 2>/dev/null || true
    echo "  Agent created."
else
    echo "  Agent already exists. Updated workspace files."
fi
echo ""

# ----------------------------------------------------------
# Done
# ----------------------------------------------------------
echo "============================================"
echo "  Ready"
echo "============================================"
echo ""
echo "  Project: $PROJECT_ROOT"
echo "  Agent:   $PROJECT_NAME"
echo ""
echo "  Next steps:"
echo "    1. Create the spec with OpenClaw: openclaw agent --agent $PROJECT_NAME --local -m 'your project idea'"
echo "    2. Or open dashboard: openclaw dashboard"
echo "    3. When spec is ready, start the watcher: $PROJECT_ROOT/watcher.sh"
echo ""
