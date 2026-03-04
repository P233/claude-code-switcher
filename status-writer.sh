#!/bin/bash
# Claude Code Status Writer
# Usage: status-writer.sh <status>
# status: running | idle | cleanup

STATUS_DIR="/tmp/cc-status"
mkdir -p "$STATUS_DIR"

PROJECT_HASH=$(echo "$PWD" | shasum | cut -c1-8)
SESSION_ID="${CLAUDE_SESSION_ID:-no-session}"
STATUS_FILE="$STATUS_DIR/${PROJECT_HASH}-${SESSION_ID}.json"

if [ "$1" = "cleanup" ]; then
    rm -f "$STATUS_FILE"
else
    PROJECT_NAME=$(basename "$PWD")
    cat > "$STATUS_FILE" <<EOF
{
  "status": "$1",
  "cwd": "$PWD",
  "projectName": "$PROJECT_NAME",
  "sessionId": "$SESSION_ID",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi
