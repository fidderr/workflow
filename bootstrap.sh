#!/bin/bash
# ============================================================
# Bootstrap a new project from the workflow template
# ============================================================
# Usage:
#   ./bootstrap.sh my-cool-app
#   ./bootstrap.sh my-cool-app /custom/path/to/projects
#
# This will:
#   1. Create a new project folder
#   2. Copy all workflow templates, orchestrator scripts, and steering files
#   3. Initialize STATUS.json with the project name
#   4. Optionally start the orchestrator watcher
# ============================================================

set -e

PROJECT_NAME="$1"
PROJECTS_DIR="${2:-$HOME/projects}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="$SCRIPT_DIR/workflow-template"
PROJECT_ROOT="$PROJECTS_DIR/$PROJECT_NAME"

# Validate
if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: ./bootstrap.sh <project-name> [projects-dir]"
    echo "  Default projects dir: \$HOME/projects"
    exit 1
fi

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "ERROR: Template directory not found: $TEMPLATE_DIR"
    exit 1
fi

if [ -d "$PROJECT_ROOT" ]; then
    echo "ERROR: Project already exists: $PROJECT_ROOT"
    exit 1
fi

# Create project from template
echo "Creating project: $PROJECT_NAME"
echo "Location: $PROJECT_ROOT"
echo ""

mkdir -p "$PROJECTS_DIR"
cp -r "$TEMPLATE_DIR" "$PROJECT_ROOT"

# Initialize STATUS.json with project info
STATUS_FILE="$PROJECT_ROOT/specs/STATUS.json"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Update STATUS.json using a temp file (no jq dependency)
python3 -c "
import json, sys
with open('$STATUS_FILE', 'r') as f:
    s = json.load(f)
s['project'] = '$PROJECT_NAME'
s['projectRoot'] = '$PROJECT_ROOT'
s['lastUpdatedAt'] = '$TIMESTAMP'
s['lastUpdatedBy'] = 'bootstrap'
s['message'] = 'Project $PROJECT_NAME created. Waiting for spec.'
with open('$STATUS_FILE', 'w') as f:
    json.dump(s, f, indent=2)
"

# Create src directory
mkdir -p "$PROJECT_ROOT/src"

# Make scripts executable
chmod +x "$PROJECT_ROOT/orchestrator/watcher.sh"
chmod +x "$PROJECT_ROOT/orchestrator/update-status.sh"

echo "Project created successfully."
echo ""
echo "Structure:"
echo "  $PROJECT_ROOT/"
echo "  ├── .kiro/steering/    (Kiro instructions)"
echo "  ├── orchestrator/      (watcher + status scripts)"
echo "  ├── specs/             (templates, active specs, QA reports)"
echo "  └── src/               (your code goes here)"
echo ""
echo "Next steps:"
echo "  1. Create a spec in specs/active/ using the template"
echo "  2. Update status: $PROJECT_ROOT/orchestrator/update-status.sh ready-for-kiro openclaw \"Spec ready\""
echo "  3. Start the watcher: $PROJECT_ROOT/orchestrator/watcher.sh"
echo ""

# Start watcher if --start-watcher flag is passed
for arg in "$@"; do
    if [ "$arg" = "--start-watcher" ]; then
        echo "Starting orchestrator watcher in background..."
        nohup "$PROJECT_ROOT/orchestrator/watcher.sh" > /dev/null 2>&1 &
        echo "Watcher started (PID: $!)"
        break
    fi
done
