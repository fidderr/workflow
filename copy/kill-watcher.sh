#!/bin/bash
# Kills all running watchers for this project
pkill -f "$(dirname "$0")/watcher.sh" 2>/dev/null
pkill -f "watcher.sh" 2>/dev/null
echo "Watcher killed."
