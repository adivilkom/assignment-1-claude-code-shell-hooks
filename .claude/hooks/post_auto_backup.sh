#!/bin/bash
# =============================================================================
# Post-Hook 4: Auto-Backup
# Purpose:    After a file edit, create a timestamped backup with rotation.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 always (post-hooks should not block)
# Backups:    data/.backups/<basename>.<timestamp>
# Log:        data/session_<session_id>.log
# =============================================================================

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
# Read configuration and input
CONFIG_FILE="$RUNNER_DIR/config/hooks.conf"
# Read JSON input from stdin
INPUT="$(cat)"
# Extract command, session_id, and file_path from JSON input
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"
FILE_PATH="$(printf '%s' "$INPUT" | grep -o '"file_path":"[^"]*"' | head -1 | sed 's/"file_path":"//;s/"//')"
# Validate command
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="default"
fi

# If file_path is empty or the file does not exist, exit 0.
if [[ -z "$FILE_PATH" ]] || [[ ! -e "$FILE_PATH" ]]; then
    exit 0
fi
#Generate a timestamp for the backup filename
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
#making sure data directory exists
mkdir -p "$RUNNER_DIR/data"
#Create .claude/hooks/data/.backups/ if it doesn't exist.
BACKUP_DIR="$RUNNER_DIR/data/.backups"
mkdir -p "$BACKUP_DIR"

#Copy the file to .claude/hooks/data/.backups/<basename>.<timestamp>.
BASENAME=$(basename "$FILE_PATH")
BACKUP_PATH="$BACKUP_DIR/$BASENAME.$TIMESTAMP"
cp "$FILE_PATH" "$BACKUP_PATH"
#Get file size with wc -c.
FILE_SIZE=$(wc -c < "$FILE_PATH")
#Append to .claude/hooks/data/session_<session_id>.log:
LOG_FILE="$RUNNER_DIR/data/session_$SESSION_ID.log"
LOG_ENTRY="[$(date '+%Y-%m-%d %H:%M:%S')] BACKUP $FILE_PATH -> .backups/$BASENAME.$TIMESTAMP ($FILE_SIZE bytes)"
echo "$LOG_ENTRY" >> "$LOG_FILE"
#Rotation: Read MAX_BACKUPS from hooks.conf (default 5). Count existing backups for this filename. If count exceeds MAX_BACKUPS, list them sorted newest-first (ls -t) and delete the oldest ones.
MAX_BACKUPS=$(grep "MAX_BACKUPS" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
if [[ -z "$MAX_BACKUPS" ]]; then
    MAX_BACKUPS=5
fi
# Count existing backups for this file
OLD_IFS=$IFS
IFS=$'\n'
# List existing backups sorted by modification time (newest first)
EXISTING_BACKUPS=($(ls -t "$BACKUP_DIR/$BASENAME."* 2>/dev/null))
IFS=$OLD_IFSBACKUP_COUNT=${#EXISTING_BACKUPS[@]}
if (( BACKUP_COUNT > MAX_BACKUPS )); then
    # Delete oldest backups
    for (( i=MAX_BACKUPS; i<BACKUP_COUNT; i++ )); do
        rm -f "${EXISTING_BACKUPS[i]}"
    done
fi
exit 0

