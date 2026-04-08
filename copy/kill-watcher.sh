#!/bin/bash
# Kills the watcher for THIS project only
PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
PIDFILE="$PROJECT_ROOT/.watcher.pid"

if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        # Kill child processes (kiro-cli agents) first
        pkill -P "$PID" 2>/dev/null
        kill "$PID" 2>/dev/null
        rm -f "$PIDFILE"
        echo "Watcher (PID $PID) killed."
    else
        rm -f "$PIDFILE"
        echo "Watcher was not running (stale PID file removed)."
    fi
else
    echo "No watcher PID file found. Watcher may not be running."
fi
