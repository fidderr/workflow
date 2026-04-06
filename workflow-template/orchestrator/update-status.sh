#!/bin/bash
# ============================================================
# Updates STATUS.json for the current project
# Auto-detects project root from its own location
# ============================================================
# Usage:
#   ./orchestrator/update-status.sh <phase> <agent> <message> [round] [specfile]
#
# Examples:
#   ./orchestrator/update-status.sh ready-for-qa kiro "Round 1 done" 1
#   ./orchestrator/update-status.sh ready-for-kiro openclaw "QA done, 3 blockers" 2
#   ./orchestrator/update-status.sh done openclaw "All tests passed"
# ============================================================

set -e

PHASE="$1"
AGENT="$2"
MESSAGE="$3"
ROUND="${4:--1}"
SPEC_FILE="${5:-}"

# Auto-detect project root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STATUS_FILE="$PROJECT_ROOT/specs/STATUS.json"

# Validate
VALID_PHASES="idle ready-for-kiro implementation ready-for-qa qa done"
VALID_AGENTS="admin kiro openclaw orchestrator"

if [ -z "$PHASE" ] || [ -z "$AGENT" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: ./update-status.sh <phase> <agent> <message> [round] [specfile]"
    echo "Phases: $VALID_PHASES"
    echo "Agents: $VALID_AGENTS"
    exit 1
fi

if ! echo "$VALID_PHASES" | grep -qw "$PHASE"; then
    echo "ERROR: Invalid phase '$PHASE'. Valid: $VALID_PHASES"
    exit 1
fi

if ! echo "$VALID_AGENTS" | grep -qw "$AGENT"; then
    echo "ERROR: Invalid agent '$AGENT'. Valid: $VALID_AGENTS"
    exit 1
fi

if [ ! -f "$STATUS_FILE" ]; then
    echo "ERROR: STATUS.json not found at: $STATUS_FILE"
    exit 1
fi

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

python3 -c "
import json
with open('$STATUS_FILE', 'r') as f:
    s = json.load(f)

# Save current state to history
s['history'].append({
    'phase': s['currentPhase'],
    'assignedTo': s['assignedTo'],
    'message': s['message'],
    'timestamp': s['lastUpdatedAt'],
    'updatedBy': s['lastUpdatedBy']
})

s['currentPhase'] = '$PHASE'
s['assignedTo'] = '$AGENT'
s['message'] = '''$MESSAGE'''
s['lastUpdatedBy'] = '$AGENT'
s['lastUpdatedAt'] = '$TIMESTAMP'

round_val = $ROUND
if round_val >= 0:
    s['round'] = round_val

spec = '$SPEC_FILE'
if spec:
    s['specFile'] = spec

with open('$STATUS_FILE', 'w') as f:
    json.dump(s, f, indent=2)
"

echo "Status updated in: $STATUS_FILE"
echo "  Phase: $PHASE"
echo "  Assigned to: $AGENT"
echo "  Message: $MESSAGE"
