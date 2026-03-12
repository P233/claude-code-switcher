#!/bin/bash
# Claude Code Status Writer
# Usage: status-writer.sh <status>
# status: running | waiting | idle | cleanup

STATUS_DIR="/tmp/cc-status"
mkdir -p "$STATUS_DIR"

PROJECT_HASH=$(echo "$PWD" | shasum | cut -c1-8)
SESSION_ID="${CLAUDE_SESSION_ID:-no-session}"
STATUS_FILE="$STATUS_DIR/${PROJECT_HASH}-${SESSION_ID}.json"

if [ "$1" = "cleanup" ]; then
    rm -f "$STATUS_FILE"
else
    # Use printf %s to avoid interpreting backslashes, and jq to produce valid JSON
    # regardless of special characters in paths or names.
    printf '%s' "$1" | jq -Rs \
        --arg cwd "$PWD" \
        --arg name "$(basename "$PWD")" \
        --arg sid "$SESSION_ID" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{status: ., cwd: $cwd, projectName: $name, sessionId: $sid, timestamp: $ts}' \
        > "$STATUS_FILE"
fi
