#!/bin/bash
# ============================================================
# Agent Orchestrator - Watches STATUS.json for handoffs
# Auto-detects project root from its own location
# ============================================================
# Usage: ./orchestrator/watcher.sh <agent-name>
# Or background: nohup ./orchestrator/watcher.sh <agent-name> &
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
STATUS_FILE="$PROJECT_ROOT/specs/STATUS.json"
LOG_FILE="$PROJECT_ROOT/orchestrator/orchestrator.log"
POLL_INTERVAL=10
MAX_RETRIES=3
RETRY_DELAY=60

OPENCLAW_AGENT="$1"
if [ -z "$OPENCLAW_AGENT" ]; then
    # Try to read from .agent-name in the project root
    if [ -f "$PROJECT_ROOT/.agent-name" ]; then
        OPENCLAW_AGENT=$(cat "$PROJECT_ROOT/.agent-name")
    else
        echo "Usage: ./orchestrator/watcher.sh <agent-name>"
        echo "  Or create a .agent-name file in the project root."
        exit 1
    fi
fi

# If not already in a dedicated terminal, open one
if [ -z "$WATCHER_IN_TERMINAL" ]; then
    export WATCHER_IN_TERMINAL=1
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal --title="Watcher: $PROJECT_NAME" -- bash -c "\"$0\" \"$OPENCLAW_AGENT\"; exec bash" 2>/dev/null
        exit 0
    elif command -v xterm &> /dev/null; then
        xterm -title "Watcher: $PROJECT_NAME" -e "\"$0\" \"$OPENCLAW_AGENT\"" &
        exit 0
    fi
    # No GUI terminal available — continue in current terminal
fi

# ------------------------------------------------------------
# CONFIGURE THESE: How to trigger each agent
# ------------------------------------------------------------
KIRO_COMMAND="kiro-cli"
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
        (cd "$PROJECT_ROOT" && $KIRO_COMMAND chat --no-interactive --trust-all-tools "$KIRO_MESSAGE") 2>&1 | while read -r line; do
            log "[kiro] $line"
        done
        log "Kiro process completed."
        return 0
    else
        log "ERROR: '$KIRO_COMMAND' not found. Configure KIRO_COMMAND in watcher.sh"
        return 1
    fi
}

trigger_openclaw() {
    log "Triggering OpenClaw..."
    if [ -z "$OPENCLAW_AGENT" ]; then
        log "ERROR: OPENCLAW_AGENT not set."
        return 1
    fi
    if command -v "$OPENCLAW_COMMAND" &> /dev/null; then
        $OPENCLAW_COMMAND agent --agent "$OPENCLAW_AGENT" -m "$OPENCLAW_MESSAGE" 2>&1 | while read -r line; do
            log "[openclaw] $line"
        done
        log "OpenClaw process completed."
        return 0
    else
        log "ERROR: '$OPENCLAW_COMMAND' not found. Configure OPENCLAW_COMMAND in watcher.sh"
        return 1
    fi
}

# Run a trigger function with retries if the phase doesn't change after
run_with_retry() {
    local trigger_fn="$1"
    local expected_phase="$2"
    local attempt=1

    while [ $attempt -le $MAX_RETRIES ]; do
        $trigger_fn

        # Check if the phase changed (meaning the agent did its job)
        sleep 5
        local current_phase=$(get_phase)
        if [ "$current_phase" != "$expected_phase" ]; then
            log "Phase changed to '$current_phase' — agent completed successfully."
            return 0
        fi

        if [ $attempt -lt $MAX_RETRIES ]; then
            log "Phase still '$expected_phase' after attempt $attempt/$MAX_RETRIES. Retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        else
            log "Phase still '$expected_phase' after $MAX_RETRIES attempts. Watcher stopping."
            log "To restart: $PROJECT_ROOT/orchestrator/watcher.sh"
            log "Then re-trigger: $PROJECT_ROOT/orchestrator/update-status.sh $expected_phase kiro \"Retry\""
            exit 1
        fi
        attempt=$((attempt + 1))
    done
    return 1
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
                run_with_retry trigger_kiro "ready-for-kiro"
                ;;
            "ready-for-qa")
                run_with_retry trigger_openclaw "ready-for-qa"
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

        # Re-read phase after trigger (it may have changed during retries)
        LAST_PHASE=$(get_phase)
    fi

    sleep "$POLL_INTERVAL"
done
