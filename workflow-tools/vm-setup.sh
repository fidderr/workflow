#!/bin/bash
# ============================================================
# One-time setup script for the Hyper-V VM (Ubuntu 24)
# Run this after cloning the repo on the VM
# ============================================================
# Usage:
#   git clone <your-repo-url> ~/workflow
#   cd ~/workflow
#   chmod +x vm-setup.sh
#   ./vm-setup.sh
# ============================================================

set -e

echo "=== Kiro + OpenClaw VM Setup ==="
echo ""

# Check prerequisites
echo "Checking prerequisites..."

if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt-get update && sudo apt-get install -y git
fi

if ! command -v python3 &> /dev/null; then
    echo "Installing python3..."
    sudo apt-get update && sudo apt-get install -y python3
fi

echo "  git: $(git --version)"
echo "  python3: $(python3 --version)"
echo ""

# Make all scripts executable
echo "Setting permissions..."
chmod +x bootstrap.sh
find workflow-template/orchestrator -name "*.sh" -exec chmod +x {} \;
echo ""

# Create projects directory
echo "Creating /home/$(whoami)/projects/ ..."
mkdir -p ~/projects
echo ""

# Configure git for the workflow (so agents can commit)
echo "Configuring git defaults for this repo..."
git config --local user.name "workflow-bot"
git config --local user.email "bot@local"
echo ""

echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Create your first project:  ./bootstrap.sh my-project"
echo "  2. Give OpenClaw the soul.md:   cat openclaw/soul.md"
echo "  3. Start building!"
