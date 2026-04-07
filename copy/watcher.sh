#!/bin/bash
# ============================================================
# Watcher — alternates between coder and qa agents (both Kiro CLI)
# ============================================================
# Usage: ./watcher.sh
# ============================================================

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
LOG_FILE="$PROJECT_ROOT/watcher.log"
WORKER_FILE="$PROJECT_ROOT/archive/worker.md"
MAX_RETRIES=3
RETRY_DELAY=60

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
        echo "coder"
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
    fi
}

run_coder() {
    local ticket="$1"
    local round=$(ls "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | wc -l)
    round=$((round + 1))
    log "Running Coder (round $round)..."
    local content=$(cat "$ticket")
    local run_log="$PROJECT_ROOT/.last-run.log"
    local spec_content=""
    if [ "$round" -le 2 ] && [ -f "$PROJECT_ROOT/SPEC.md" ]; then
        spec_content="

--- SPEC.md ---
$(cat "$PROJECT_ROOT/SPEC.md")
--- END SPEC ---"
    fi
    (cd "$PROJECT_ROOT" && kiro-cli chat --no-interactive --trust-all-tools --agent coder \
        "Round $round. Here is your ticket. Do what it says. When done, write ticket.md (see templates/ticket.md for format).
$spec_content
--- TICKET ---
$content
--- END TICKET ---") \
        2>&1 | tee "$run_log" | while read -r line; do log "[coder] $line"; done
    log "Coder exited."
}

run_qa() {
    local ticket="$1"
    local round=$(ls "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | wc -l)
    round=$((round + 1))
    log "Running QA (round $round)..."
    local content=$(cat "$ticket")
    local run_log="$PROJECT_ROOT/.last-run.log"
    (cd "$PROJECT_ROOT" && kiro-cli chat --no-interactive --trust-all-tools --agent qa \
        "Round $round. Here is your ticket from the coder. Test what was built. If issues, write ticket.md with what to fix. If all good, create done.md (see templates/done.md).

--- TICKET ---
$content
--- END TICKET ---") \
        2>&1 | tee "$run_log" | while read -r line; do log "[qa] $line"; done
    log "QA exited."
}

run_with_retry() {
    local fn="$1"
    local ticket="$2"
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        $fn "$ticket"
        if [ -f "$PROJECT_ROOT/done.md" ]; then
            return 0
        fi
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ -s "$PROJECT_ROOT/ticket.md" ]; then
            return 0
        fi
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ ! -s "$PROJECT_ROOT/ticket.md" ]; then
            rm -f "$PROJECT_ROOT/ticket.md"
            log "Empty ticket.md removed."
        fi
        # Failsafe: dump logs as ticket if agent didn't write one
        if [ ! -f "$PROJECT_ROOT/ticket.md" ] && [ -f "$PROJECT_ROOT/.last-run.log" ]; then
            log "Agent didn't write ticket.md. Creating from logs..."
            echo "# Auto-generated ticket (agent failed to write one)" > "$PROJECT_ROOT/ticket.md"
            echo "" >> "$PROJECT_ROOT/ticket.md"
            echo "## Agent output:" >> "$PROJECT_ROOT/ticket.md"
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
# Main
# ----------------------------------------------------------
log "========================================="
log "Watcher started: $PROJECT_NAME"
log "========================================="

# Check SPEC.md
if [ ! -f "$PROJECT_ROOT/SPEC.md" ]; then
    log "ERROR: No SPEC.md found. Create the spec first."
    exit 1
fi

# Archive leftover ticket.md
if [ -f "$PROJECT_ROOT/ticket.md" ]; then
    PREV_WORKER=$(get_worker)
    if [ "$PREV_WORKER" = "coder" ]; then
        archive_ticket "QA"
    else
        archive_ticket "CODER"
    fi
fi

while true; do
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

    TICKET=$(get_latest_ticket)

    # First run: no tickets yet, create initial ticket for coder from SPEC.md
    if [ -z "$TICKET" ] && [ "$WORKER" = "coder" ]; then
        log "No tickets yet. Creating initial ticket from SPEC.md..."
        echo "# Initial Ticket" > "$PROJECT_ROOT/ticket.md"
        echo "" >> "$PROJECT_ROOT/ticket.md"
        echo "Read SPEC.md and implement everything. Write ticket.md when done." >> "$PROJECT_ROOT/ticket.md"
        archive_ticket "WATCHER"
        TICKET=$(get_latest_ticket)
    fi

    if [ -z "$TICKET" ]; then
        log "No ticket found. Waiting..."
        sleep 10
        continue
    fi

    log "Turn: $WORKER | Ticket: $(basename $TICKET)"

    case "$WORKER" in
        "coder")
            run_with_retry run_coder "$TICKET"
            ;;
        "qa")
            run_with_retry run_qa "$TICKET"
            ;;
    esac

    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        exit 0
    fi

    if [ -f "$PROJECT_ROOT/ticket.md" ]; then
        if [ "$WORKER" = "coder" ]; then
            archive_ticket "CODER"
            set_worker "qa"
        else
            archive_ticket "QA"
            set_worker "coder"
        fi
    else
        log "WARNING: Worker exited without ticket.md or done.md"
    fi
done
