#!/bin/bash
# ============================================================
# Watcher — runs agents in turns, handles all file management
# ============================================================
# Usage: ./watcher.sh
#
# How it works:
#   1. Reads archive/worker.md to know whose turn it is
#   2. Finds the newest ticket in archive/ and gives it to that worker
#   3. Worker reads it, does the work, writes ticket.md
#   4. Worker exits → watcher archives ticket.md with timestamp
#   5. Updates worker.md to the next worker
#   6. Repeat until done.md exists
# ============================================================

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
LOG_FILE="$PROJECT_ROOT/watcher.log"
WORKER_FILE="$PROJECT_ROOT/archive/worker.md"
MAX_RETRIES=3
RETRY_DELAY=60

# Read agent name
if [ -f "$PROJECT_ROOT/.agent-name" ]; then
    OPENCLAW_AGENT=$(cat "$PROJECT_ROOT/.agent-name")
else
    echo "ERROR: No .agent-name file in $PROJECT_ROOT"
    exit 1
fi

# Open in its own terminal if possible
if [ -z "$WATCHER_IN_TERMINAL" ]; then
    export WATCHER_IN_TERMINAL=1
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal --title="Watcher: $PROJECT_NAME" -- bash -c "\"$0\"; exec bash" 2>/dev/null
        exit 0
    fi
fi

log() {
    local ts=$(date '+%H:%M:%S')
    echo "[$ts] $1"
    echo "[$ts] [$PROJECT_NAME] $1" >> "$LOG_FILE"
}

get_worker() {
    if [ -f "$WORKER_FILE" ]; then
        cat "$WORKER_FILE" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]'
    else
        echo "openclaw"
    fi
}

set_worker() {
    echo "$1" > "$WORKER_FILE"
    log "Next worker: $1"
}

get_latest_ticket() {
    ls -t "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | head -1
}

archive_ticket() {
    local from="$1"
    if [ -f "$PROJECT_ROOT/ticket.md" ]; then
        local ts=$(date '+%Y%m%d-%H%M%S')
        local dest="$PROJECT_ROOT/archive/ticket-${ts}_FROM_${from}.md"
        mv "$PROJECT_ROOT/ticket.md" "$dest"
        log "Archived: $dest"
        echo "$dest"
    fi
}

run_kiro() {
    local ticket="$1"
    local round=$(ls "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | wc -l)
    round=$((round + 1))
    log "Running Kiro (round $round)..."
    local content=$(cat "$ticket")
    local run_log="$PROJECT_ROOT/.last-run.log"
    # Include SPEC.md on first round
    local spec_content=""
    if [ "$round" -le 2 ] && [ -f "$PROJECT_ROOT/SPEC.md" ]; then
        spec_content="

--- SPEC.md ---
$(cat "$PROJECT_ROOT/SPEC.md")
--- END SPEC ---"
    fi
    (cd "$PROJECT_ROOT" && kiro-cli chat --no-interactive --trust-all-tools \
        "Round $round. Here is your ticket. Do what it says. When done, write ticket.md (see templates/ticket.md for format) with what you did and how to test it.
$spec_content
--- TICKET ---
$content
--- END TICKET ---") \
        2>&1 | tee "$run_log" | while read -r line; do log "[kiro] $line"; done
    log "Kiro exited."
}

run_openclaw() {
    local ticket="$1"
    local round=$(ls "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | wc -l)
    round=$((round + 1))
    log "Running OpenClaw (round $round)..."
    local content=$(cat "$ticket")
    local run_log="$PROJECT_ROOT/.last-run.log"
    # Find openclaw binary
    local OC_BIN=$(command -v openclaw 2>/dev/null || echo "$HOME/.npm-global/bin/openclaw")
    if [ ! -x "$OC_BIN" ]; then
        log "ERROR: openclaw not found. Install it or check PATH."
        return 1
    fi
    "$OC_BIN" agent --agent "$OPENCLAW_AGENT" --local --verbose on -m \
        "Round $round. Here is your ticket from Kiro. Test what was built. If issues, write ticket.md (see templates/ticket.md for format) with what to fix. If all good, create done.md (see templates/done.md for format).

--- TICKET ---
$content
--- END TICKET ---" \
        2>&1 | tee "$run_log" | while read -r line; do log "[openclaw] $line"; done
    log "OpenClaw exited."
}

run_with_retry() {
    local fn="$1"
    local ticket="$2"
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        $fn "$ticket"
        # Success if agent wrote ticket.md or done.md (and ticket isn't empty)
        if [ -f "$PROJECT_ROOT/done.md" ]; then
            return 0
        fi
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ -s "$PROJECT_ROOT/ticket.md" ]; then
            return 0
        fi
        # Remove empty ticket.md if it exists
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ ! -s "$PROJECT_ROOT/ticket.md" ]; then
            rm -f "$PROJECT_ROOT/ticket.md"
            log "Empty ticket.md removed."
        fi
        # Failsafe: if agent didn't write ticket.md, dump its logs as the ticket
        if [ ! -f "$PROJECT_ROOT/ticket.md" ] && [ -f "$PROJECT_ROOT/.last-run.log" ]; then
            log "Agent didn't write ticket.md. Creating from run logs..."
            echo "# Auto-generated ticket (agent failed to write one)" > "$PROJECT_ROOT/ticket.md"
            echo "" >> "$PROJECT_ROOT/ticket.md"
            echo "## Agent output (last run):" >> "$PROJECT_ROOT/ticket.md"
            echo '```' >> "$PROJECT_ROOT/ticket.md"
            tail -100 "$PROJECT_ROOT/.last-run.log" >> "$PROJECT_ROOT/ticket.md"
            echo '```' >> "$PROJECT_ROOT/ticket.md"
            return 0
        fi
        if [ $attempt -lt $MAX_RETRIES ]; then
            log "No output after attempt $attempt/$MAX_RETRIES. Retrying in ${RETRY_DELAY}s..."
            sleep "$RETRY_DELAY"
        else
            log "Failed after $MAX_RETRIES attempts. Watcher stopping."
            log "Restart: $PROJECT_ROOT/watcher.sh"
            exit 1
        fi
        attempt=$((attempt + 1))
    done
}

# ----------------------------------------------------------
# Main loop
# ----------------------------------------------------------
log "========================================="
log "Watcher started: $PROJECT_NAME"
log "Agent: $OPENCLAW_AGENT"
log "========================================="

# Check SPEC.md exists
if [ ! -f "$PROJECT_ROOT/SPEC.md" ]; then
    log "ERROR: No SPEC.md found in $PROJECT_ROOT"
    log "Create the spec first with OpenClaw, then start the watcher."
    exit 1
fi

# Archive any leftover ticket.md from a previous run
if [ -f "$PROJECT_ROOT/ticket.md" ]; then
    PREV_WORKER=$(get_worker)
    LEFTOVER_FROM="UNKNOWN"
    if [ "$PREV_WORKER" = "kiro" ]; then
        LEFTOVER_FROM="CLAW"
    elif [ "$PREV_WORKER" = "openclaw" ]; then
        LEFTOVER_FROM="KIRO"
    fi
    log "Found leftover ticket.md — archiving before starting."
    archive_ticket "$LEFTOVER_FROM"
fi

while true; do
    # Check if done
    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        exit 0
    fi

    WORKER=$(get_worker)

    if [ "$WORKER" = "done" ]; then
        log "Project already done."
        exit 0
    fi

    # Find the latest ticket to give to the worker
    TICKET=$(get_latest_ticket)

    # First run: no tickets yet, trigger OpenClaw to create the first one from SPEC.md
    if [ -z "$TICKET" ] && [ "$WORKER" = "openclaw" ]; then
        log "No tickets yet. Triggering OpenClaw to create first ticket from SPEC.md..."
        local OC_BIN=$(command -v openclaw 2>/dev/null || echo "$HOME/.npm-global/bin/openclaw")
        "$OC_BIN" agent --agent "$OPENCLAW_AGENT" --local --verbose on -m \
            "Read SPEC.md in ~/projects/$PROJECT_NAME and write ticket.md with implementation instructions for Kiro." \
            2>&1 | while read -r line; do log "[openclaw] $line"; done
        log "OpenClaw exited."
        if [ -f "$PROJECT_ROOT/ticket.md" ]; then
            archive_ticket "CLAW"
            set_worker "kiro"
        fi
        continue
    fi

    if [ -z "$TICKET" ]; then
        log "No ticket found. Waiting..."
        sleep 10
        continue
    fi

    log "Turn: $WORKER | Ticket: $TICKET"

    case "$WORKER" in
        "kiro")
            run_with_retry run_kiro "$TICKET"
            ;;
        "openclaw")
            run_with_retry run_openclaw "$TICKET"
            ;;
    esac

    # Check if done
    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        exit 0
    fi

    # Archive the new ticket and switch worker
    if [ -f "$PROJECT_ROOT/ticket.md" ]; then
        if [ "$WORKER" = "kiro" ]; then
            archive_ticket "KIRO"
            set_worker "openclaw"
        else
            archive_ticket "CLAW"
            set_worker "kiro"
        fi
    else
        log "WARNING: Worker exited without writing ticket.md or done.md"
    fi
done
