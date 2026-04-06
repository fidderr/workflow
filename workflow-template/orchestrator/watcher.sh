#!/bin/bash
# ============================================================
# Agent Orchestrator - Watches STATUS.json for handoffs
# Auto-detects project root from its own location
# ============================================================
# Usage: ./orchestrator/watcher.sh
# Or background: nohup ./orchestrator/watcher.sh &
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
STATUS_FILE="$PROJECT_ROOT/specs/STATUS.json"
LOG_FILE="$PROJECT_ROOT/orchestrator/orchestrator.log"
POLL_INTERVAL=10

# ------------------------------------------------------------
# CONFIGURE THESE: How to trigger each agent
# ------------------------------------------------------------
KIRO_COMMAND="kiro"
KIRO_MESSAGE="A new task is ready. Read specs/STATUS.json in project '$PROJECT_NAME' at '$PROJECT_ROOT'. Fix all blockers first, then bugs, then visual issues. When done, update STATUS.json and create a handoff."

OPENCLAW_COMMAND="openclaw"
OPENCLAW_MESSAGE="Kiro finished implementation for project '$PROJECT_NAME' at '$PROJECT_ROOT'. Read the handoff, set up a dev build, test everything, create a QA report, and update STATUS.json."

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------

log() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local entry="[$timestamp] [$PROJECT_NAME] $1"
    echo "$entry"
    echo "$entry" >> "$LOG_FILE"
}

get_phase() {
    if [ ! -f "$STATUS_FILE" ]; then
        log "ERROR: $STATUS_FILE not found"
        echo ""
        return
    fi
    python3 -c "import json; print(json.load(open('$STATUS_FILE'))['currentPhase'])"
}

trigger_kiro() {
    log "Triggering Kiro..."
    if command -v "$KIRO_COMMAND" &> /dev/null; then
        $KIRO_COMMAND --message "$KIRO_MESSAGE" --cwd "$PROJECT_ROOT" 2>&1 | while read -r line; do
            log "[kiro] $line"
        done
        log "Kiro process completed."
    else
        log "ERROR: '$KIRO_COMMAND' not found. Configure KIRO_COMMAND in watcher.sh"
    fi
}

trigger_openclaw() {
    log "Triggering OpenClaw..."
    if command -v "$OPENCLAW_COMMAND" &> /dev/null; then
        $OPENCLAW_COMMAND --message "$OPENCLAW_MESSAGE" 2>&1 | while read -r line; do
            log "[openclaw] $line"
        done
        log "OpenClaw process completed."
    else
        log "ERROR: '$OPENCLAW_COMMAND' not found. Configure OPENCLAW_COMMAND in watcher.sh"
    fi
}

# ------------------------------------------------------------
# Main loop
# ------------------------------------------------------------

log "========================================="
log "Orchestrator started for: $PROJECT_NAME"
log "Project root: $PROJECT_ROOT"
log "Watching: $STATUS_FILE"
log "Poll interval: ${POLL_INTERVAL}s"
log "========================================="

LAST_PHASE=""

while true; do
    PHASE=$(get_phase)

    if [ -n "$PHASE" ] && [ "$PHASE" != "$LAST_PHASE" ]; then
        log "Phase change: $LAST_PHASE -> $PHASE"

        case "$PHASE" in
            "ready-for-kiro")
                trigger_kiro
                ;;
            "ready-for-qa")
                trigger_openclaw
                ;;
            "done")
                log "PROJECT COMPLETE. Orchestrator stopping."
                exit 0
                ;;
            "idle")
                log "Idle. Waiting for spec."
                ;;
            *)
                log "Phase '$PHASE' - waiting."
                ;;
        esac

        LAST_PHASE="$PHASE"
    fi

    sleep "$POLL_INTERVAL"
done
