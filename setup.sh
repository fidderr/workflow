#!/bin/bash
# ============================================================
# Full Setup — Kiro + OpenClaw Workflow
# ============================================================
# Run this once on a fresh Ubuntu VM after cloning the repo.
# It installs everything, creates the OpenClaw agent, sets up
# Kiro CLI, and optionally bootstraps your first project.
#
# Usage:
#   git clone <your-repo-url> ~/workflow
#   cd ~/workflow
#   chmod +x setup.sh
#   ./setup.sh my-agent           # Full install + create agent "my-agent"
#   ./setup.sh another-agent      # Create another agent (skips already-installed deps)
#
# After setup:
#   1. Fill in ~/workflow/credentials.md with your actual values
#   2. Open the OpenClaw TUI:
#      openclaw tui --session <agent-name>
#   3. Give the agent your spec — done.
# ============================================================

set -e

WORKFLOW_DIR="$(cd "$(dirname "$0")" && pwd)"
AGENT_NAME="$1"
if [ -z "$AGENT_NAME" ]; then
    echo "Usage: ./setup.sh <agent-name>"
    echo "  Example: ./setup.sh my-agent"
    exit 1
fi
WORKSPACE_DIR="$HOME/.openclaw/workspace-$AGENT_NAME"

echo "============================================"
echo "  Kiro + OpenClaw Workflow — Full Setup"
echo "============================================"
echo ""
echo "Workflow dir: $WORKFLOW_DIR"
echo ""

# ----------------------------------------------------------
# 1. System dependencies
# ----------------------------------------------------------
echo "[1/8] Installing system dependencies..."

sudo apt-get update -qq

# Core tools
for pkg in git python3 curl unzip ffmpeg; do
    if ! command -v "$pkg" &> /dev/null; then
        echo "  Installing $pkg..."
        sudo apt-get install -y -qq "$pkg"
    fi
done

# UI testing tools (computer use)
for pkg in xdotool scrot imagemagick xvfb; do
    if ! dpkg -s "$pkg" &> /dev/null 2>&1; then
        echo "  Installing $pkg..."
        sudo apt-get install -y -qq "$pkg"
    fi
done

echo "  Done."
echo ""

# ----------------------------------------------------------
# 2. Node.js
# ----------------------------------------------------------
echo "[2/8] Checking Node.js..."

if ! command -v node &> /dev/null; then
    echo "  Installing Node.js LTS..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y -qq nodejs
fi

echo "  node: $(node --version)"
echo "  npm: $(npm --version)"
echo ""

# ----------------------------------------------------------
# 3. OpenClaw
# ----------------------------------------------------------
echo "[3/8] Setting up OpenClaw..."

if ! command -v openclaw &> /dev/null; then
    echo "  Installing OpenClaw..."
    npm install -g openclaw
fi

echo "  openclaw: $(openclaw --version 2>/dev/null || echo 'installed')"

# Run setup if not configured yet
if [ ! -f "$HOME/.openclaw/openclaw.json" ]; then
    echo ""
    echo "  OpenClaw needs initial configuration (API key, model provider)."
    echo "  Running openclaw setup..."
    echo ""
    openclaw setup
fi

echo ""

# ----------------------------------------------------------
# 4. Kiro CLI
# ----------------------------------------------------------
echo "[4/8] Setting up Kiro CLI..."

if ! command -v kiro-cli &> /dev/null; then
    echo "  Downloading Kiro CLI..."
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        wget -q https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.deb -O /tmp/kiro-cli.deb
    elif [ "$ARCH" = "aarch64" ]; then
        wget -q https://desktop-release.q.us-east-1.amazonaws.com/latest/kiro-cli.deb -O /tmp/kiro-cli.deb
    fi
    echo "  Installing Kiro CLI..."
    sudo dpkg -i /tmp/kiro-cli.deb || sudo apt-get install -f -y -qq
    rm -f /tmp/kiro-cli.deb
fi

echo "  kiro-cli: $(kiro-cli --version 2>/dev/null || echo 'installed')"

# Login if not authenticated
if ! kiro-cli whoami &> /dev/null; then
    echo ""
    echo "  Kiro CLI needs authentication."
    echo "  Running kiro-cli login..."
    echo ""
    kiro-cli login --use-device-flow
fi

echo ""

# ----------------------------------------------------------
# 5. Create OpenClaw agent with workspace
# ----------------------------------------------------------
echo "[5/8] Creating OpenClaw '$AGENT_NAME' agent..."

mkdir -p "$WORKSPACE_DIR"

# Copy soul.md and tools to workspace
cp "$WORKFLOW_DIR/openclaw/soul.md" "$WORKSPACE_DIR/SOUL.md"
cp "$WORKFLOW_DIR/TOOLS.md" "$WORKSPACE_DIR/TOOLS.md"

# Create AGENTS.md for the workflow agent
cat > "$WORKSPACE_DIR/AGENTS.md" << 'AGENTS_EOF'
# Agent Rules

## Primary Role
You are a Project Manager and QA tester. Follow the instructions in SOUL.md exactly.

## Tools
Refer to TOOLS.md for all available tools and commands.

## Key Rules
- Never modify source code directly — that's Kiro's job
- Always use the templates in specs/templates/
- Always check specs/STATUS.json first when starting work
- Communicate with Kiro through files in specs/ only
- Contact the Admin via WhatsApp only for project completion or last-resort roadblocks
AGENTS_EOF

# Register the agent with OpenClaw (skip if already exists)
if ! openclaw agents list 2>/dev/null | grep -q "$AGENT_NAME"; then
    openclaw agents add "$AGENT_NAME" \
        --workspace "$WORKSPACE_DIR" \
        --non-interactive 2>/dev/null || true
    echo "  Agent '$AGENT_NAME' created with workspace: $WORKSPACE_DIR"
else
    echo "  Agent '$AGENT_NAME' already exists. Updating workspace files..."
fi

echo ""

# ----------------------------------------------------------
# 6. Set up credentials
# ----------------------------------------------------------
echo "[6/8] Setting up credentials..."

CREDS_FILE="$WORKFLOW_DIR/credentials.md"
if [ ! -f "$CREDS_FILE" ]; then
    cp "$WORKFLOW_DIR/credentials.example.md" "$CREDS_FILE"
    echo "  Created credentials.md from template."
    echo "  >>> IMPORTANT: Edit $CREDS_FILE with your actual values! <<<"
else
    echo "  credentials.md already exists."
fi

echo ""

# ----------------------------------------------------------
# 7. Playwright skill
# ----------------------------------------------------------
echo "[7/8] Setting up Playwright..."

PLAYWRIGHT_DIR="$HOME/.openclaw/tools/playwright-skill"
if [ ! -d "$PLAYWRIGHT_DIR" ]; then
    mkdir -p "$PLAYWRIGHT_DIR"
    echo "  Created $PLAYWRIGHT_DIR/"
    echo "  Note: Install the playwright-skill files, then run:"
    echo "    cd $PLAYWRIGHT_DIR && npm run setup"
else
    echo "  Playwright skill directory exists."
fi

echo ""

# ----------------------------------------------------------
# 8. Git config + permissions
# ----------------------------------------------------------
echo "[8/8] Final setup..."

# Make scripts executable
chmod +x "$WORKFLOW_DIR/bootstrap.sh"
find "$WORKFLOW_DIR/workflow-template/orchestrator" -name "*.sh" -exec chmod +x {} \;

# Create projects directory
mkdir -p "$HOME/projects"

# Git config for workflow commits
git config --local user.name "workflow-bot" 2>/dev/null || true
git config --local user.email "bot@local" 2>/dev/null || true

echo "  Done."
echo ""

# ----------------------------------------------------------
# Summary
# ----------------------------------------------------------
echo "============================================"
echo "  Setup Complete"
echo "============================================"
echo ""
echo "  OpenClaw agent: $AGENT_NAME"
echo "  Workspace:      $WORKSPACE_DIR"
echo "  Credentials:    $CREDS_FILE"
echo "  Projects dir:   $HOME/projects"
echo ""
echo "  Next steps:"
echo "    1. Edit credentials.md with your actual values"
echo "    2. Open the agent in OpenClaw TUI:"
echo "       openclaw tui --session $AGENT_NAME"
echo "    3. Give it your idea or spec — it handles the rest"
echo ""
