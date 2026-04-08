#!/bin/bash
# ============================================================
# Watcher v2 — pipeline: coder → code-verifier → backend-tester
#   → frontend-tester → visual-qa → functional-qa → project-lead
# ============================================================

export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
LOG_FILE="$PROJECT_ROOT/watcher.log"
WORKER_FILE="$PROJECT_ROOT/archive/worker.md"
REPORTS_DIR="$PROJECT_ROOT/reports"
MAX_RETRIES=3
RETRY_DELAY=60
STALL_TIMEOUT=180
MAX_WATCHDOG_FAILS=3

# Pipeline order (after code-verifier)
QA_AGENTS=("backend-tester" "frontend-tester" "visual-qa" "functional-qa" "project-lead")

# Open in its own terminal if possible
if [ -z "$WATCHER_IN_TERMINAL" ]; then
    export WATCHER_IN_TERMINAL=1
    if command -v gnome-terminal &> /dev/null; then
        gnome-terminal --title="Watcher: $PROJECT_NAME" -- bash -c "\"$0\"; exec bash" 2>/dev/null
        exit 0
    fi
fi

# Save PID for kill-watcher.sh
echo $$ > "$PROJECT_ROOT/.watcher.pid"

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

get_round() {
    ls "$PROJECT_ROOT/archive"/ticket-*.md 2>/dev/null | wc -l
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

clean_reports() {
    rm -f "$REPORTS_DIR"/*.md
    log "Cleared reports directory."
}

start_watchdog() {
    local pid="$1"
    (
        local watchdog_fails=0
        while kill -0 "$pid" 2>/dev/null; do
            local last_mod=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
            sleep 60
            local new_mod=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
            if [ "$last_mod" = "$new_mod" ]; then
                local stale_seconds=$(( $(date +%s) - new_mod ))
                if [ "$stale_seconds" -ge "$STALL_TIMEOUT" ]; then
                    watchdog_fails=$((watchdog_fails + 1))
                    log "WATCHDOG: No activity for ${STALL_TIMEOUT}s. Attempt $watchdog_fails/$MAX_WATCHDOG_FAILS..."

                    if [ "$watchdog_fails" -ge "$MAX_WATCHDOG_FAILS" ]; then
                        log "WATCHDOG: $MAX_WATCHDOG_FAILS failed attempts. Killing agent."
                        kill "$pid" 2>/dev/null
                        log "WATCHDOG: Agent killed. Watcher will retry or move on."
                        exit 1
                    fi

                    log "WATCHDOG: Spawning watchdog agent..."
                    gnome-terminal --title="Watchdog: $PROJECT_NAME" -- bash -c "cd $PROJECT_ROOT && kiro-cli chat --no-interactive --trust-all-tools --agent watchdog 'An agent in $PROJECT_ROOT has been stuck for 3+ minutes. Check watcher.log and .last-run.log, fix the blockage, and exit.'; exec bash" 2>/dev/null

                    sleep 60

                    local after_fix_mod=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
                    if [ "$after_fix_mod" != "$new_mod" ]; then
                        log "WATCHDOG: Unstick successful. Resetting."
                        watchdog_fails=0
                    fi
                fi
            else
                watchdog_fails=0
            fi
        done
    ) &
    echo $!
}

run_agent() {
    local agent_name="$1"
    local prompt="$2"
    local round=$(get_round)
    round=$((round + 1))
    local run_log="$PROJECT_ROOT/.last-run.log"

    log "Running $agent_name (round $round)..."

    (cd "$PROJECT_ROOT" && kiro-cli chat --no-interactive --trust-all-tools --agent "$agent_name" "$prompt") \
        2>&1 | tee "$run_log" | while read -r line; do log "[$agent_name] $line"; done &
    local agent_pid=$!
    local watchdog_pid=$(start_watchdog $agent_pid)
    wait $agent_pid 2>/dev/null
    local exit_code=$?
    kill $watchdog_pid 2>/dev/null
    log "$agent_name exited (code: $exit_code)."
    return $exit_code
}

run_coder() {
    local ticket="$1"
    local round=$(get_round)
    round=$((round + 1))
    local content=$(cat "$ticket")
    local spec_content=""

    # Include SPEC.md in first 2 rounds
    if [ "$round" -le 2 ] && [ -f "$PROJECT_ROOT/SPEC.md" ]; then
        spec_content="

--- SPEC.md ---
$(cat "$PROJECT_ROOT/SPEC.md")
--- END SPEC ---"
    fi

    run_agent "coder" "Round $round. Here is your ticket. Do what it says. When done, write ticket.md (see templates/ticket.md for format).
$spec_content
--- TICKET ---
$content
--- END TICKET ---"
}

run_code_verifier() {
    local coder_ticket="$1"
    local round=$(get_round)
    round=$((round + 1))
    local content=$(cat "$coder_ticket")
    local spec_content=""

    if [ -f "$PROJECT_ROOT/SPEC.md" ]; then
        spec_content="

--- SPEC.md ---
$(cat "$PROJECT_ROOT/SPEC.md")
--- END SPEC ---"
    fi

    run_agent "code-verifier" "Round $round. The coder just finished. Verify the codebase against the spec, check code quality, fix anything missing or broken, then update ticket.md.
$spec_content
--- CODER TICKET ---
$content
--- END TICKET ---"
}

run_qa_agent() {
    local agent_name="$1"
    local coder_ticket="$2"
    local round=$(get_round)
    round=$((round + 1))
    local content=$(cat "$coder_ticket")

    run_agent "$agent_name" "Round $round. The coder has finished. Here is the coder's ticket describing what was built. Do your job as described in your prompt. Read SPEC.md for full requirements. Check the reports/ directory for other agents' reports.

--- CODER TICKET ---
$content
--- END TICKET ---"
}

run_project_lead() {
    local coder_ticket="$1"
    local round=$(get_round)
    round=$((round + 1))
    local content=$(cat "$coder_ticket")

    run_agent "project-lead" "Round $round. All agents have finished their work. Read every report in the reports/ directory. Read SPEC.md. Here is the latest ticket (updated by code-verifier). Decide: write ticket.md with issues for the coder, or create done.md if the project is complete.

--- CODER TICKET ---
$content
--- END TICKET ---"
}

run_coder_with_retry() {
    local ticket="$1"
    local attempt=1
    while [ $attempt -le $MAX_RETRIES ]; do
        run_coder "$ticket"

        if [ -f "$PROJECT_ROOT/done.md" ]; then
            return 0
        fi
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ -s "$PROJECT_ROOT/ticket.md" ]; then
            return 0
        fi

        # Clean up empty ticket
        if [ -f "$PROJECT_ROOT/ticket.md" ] && [ ! -s "$PROJECT_ROOT/ticket.md" ]; then
            rm -f "$PROJECT_ROOT/ticket.md"
            log "Empty ticket.md removed."
        fi

        # Failsafe: create ticket from logs
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
            log "Coder failed after $MAX_RETRIES attempts. Stopping."
            log "Restart: $PROJECT_ROOT/watcher.sh"
            exit 1
        fi
        attempt=$((attempt + 1))
    done
}

run_qa_pipeline() {
    local coder_ticket="$1"

    for agent in "${QA_AGENTS[@]}"; do
        # Check if a previous agent wrote ticket.md (early exit on blocker)
        if [ -f "$PROJECT_ROOT/ticket.md" ]; then
            log "EARLY EXIT: $agent skipped — ticket.md exists (blocker found by previous agent)."
            break
        fi

        if [ -f "$PROJECT_ROOT/done.md" ]; then
            log "EARLY EXIT: $agent skipped — done.md exists."
            break
        fi

        if [ "$agent" = "project-lead" ]; then
            run_project_lead "$coder_ticket"
        else
            run_qa_agent "$agent" "$coder_ticket"
        fi
    done
}

# ----------------------------------------------------------
# Main loop
# ----------------------------------------------------------
log "========================================="
log "Watcher v2 started: $PROJECT_NAME"
log "Pipeline: coder → code-verifier → backend-tester → frontend-tester → visual-qa → functional-qa → project-lead"
log "========================================="

# Check SPEC.md
if [ ! -f "$PROJECT_ROOT/SPEC.md" ]; then
    log "ERROR: No SPEC.md found. Create the spec first."
    exit 1
fi

# Ensure reports directory exists
mkdir -p "$REPORTS_DIR"

# Archive leftover ticket.md from previous run
if [ -f "$PROJECT_ROOT/ticket.md" ]; then
    archive_ticket "PREVIOUS_RUN"
fi

while true; do
    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        rm -f "$PROJECT_ROOT/.watcher.pid"
        exit 0
    fi

    WORKER=$(get_worker)

    if [ "$WORKER" = "done" ]; then
        log "Project already done."
        rm -f "$PROJECT_ROOT/.watcher.pid"
        exit 0
    fi

    TICKET=$(get_latest_ticket)

    # First run: create initial ticket from SPEC.md
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

    log "=== ROUND START === Ticket: $(basename $TICKET)"

    # Phase 1: Coder
    clean_reports
    run_coder_with_retry "$TICKET"

    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        rm -f "$PROJECT_ROOT/.watcher.pid"
        exit 0
    fi

    # Archive coder's ticket, keep a copy for QA pipeline
    CODER_TICKET="$PROJECT_ROOT/ticket.md"
    if [ -f "$CODER_TICKET" ]; then
        cp "$CODER_TICKET" "$REPORTS_DIR/coder-ticket.md"
        archive_ticket "CODER"
        CODER_TICKET="$REPORTS_DIR/coder-ticket.md"
    else
        log "WARNING: Coder didn't produce ticket.md. Using last archived ticket."
        CODER_TICKET=$(get_latest_ticket)
    fi

    # Phase 2: Code Verifier
    log "--- Code Verifier starting ---"
    run_code_verifier "$CODER_TICKET"

    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        rm -f "$PROJECT_ROOT/.watcher.pid"
        exit 0
    fi

    # If code-verifier updated ticket.md, use that as the source for QA
    if [ -f "$PROJECT_ROOT/ticket.md" ]; then
        cp "$PROJECT_ROOT/ticket.md" "$REPORTS_DIR/coder-ticket.md"
        archive_ticket "CODE_VERIFIER"
        CODER_TICKET="$REPORTS_DIR/coder-ticket.md"
    fi

    # Phase 3: QA Pipeline
    log "--- QA Pipeline starting ---"
    run_qa_pipeline "$CODER_TICKET"

    if [ -f "$PROJECT_ROOT/done.md" ]; then
        set_worker "done"
        log "PROJECT COMPLETE."
        rm -f "$PROJECT_ROOT/.watcher.pid"
        exit 0
    fi

    # Archive project-lead's ticket, loop back to coder
    if [ -f "$PROJECT_ROOT/ticket.md" ]; then
        archive_ticket "PROJECT_LEAD"
        set_worker "coder"
    else
        log "WARNING: No ticket.md or done.md after QA pipeline. Retrying round."
        set_worker "coder"
    fi

    log "=== ROUND END ==="
done
