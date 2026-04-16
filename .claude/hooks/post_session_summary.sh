#!/bin/bash
# =============================================================================
# Post-Hook 6: Session Summary
# Purpose:    Generate a formatted summary from session.log when Claude stops.
# Input:      JSON on stdin: {"session_id":"...","cwd":"...","stop_hook_active":false}
# Exit codes: 0 always
# IMPORTANT:  Checks stop_hook_active first to prevent infinite loops.
# =============================================================================

#Infinite-loop guard (critical!): Extract stop_hook_active. If true, exit 0 immediately. This prevents Claude Code from entering an infinite Stop→Hook→Stop loop.

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
#Extract session_id. Set log path to .claude/hooks/data/session_<session_id>.log.
INPUT="$(cat)"
STOP_HOOK_ACTIVE=$(printf '%s' "$INPUT" | grep -o '"stop_hook_active":[^,}]*' | head -1 | cut -d':' -f2 | tr -d ' "')
# If stop_hook_active is true, exit 0 immediately to prevent infinite loops.
if [[ "$STOP_HOOK_ACTIVE" == "true" ]]; then
    exit 0
fi

SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"
mkdir -p "$RUNNER_DIR/data"
LOG_FILE="$RUNNER_DIR/data/session_$SESSION_ID.log"
#If the log doesn't exist or is empty, print No session activity recorded. and exit 0.
if [ ! -s "$LOG_FILE" ]; then
    printf "No session activity recorded.\n"
    exit 0
fi
#Gather statistics from the log:
#Total lines = total actions
#Count BACKUP lines → backups made
#Count SYNTAX_OK and SYNTAX_ERROR lines separately
#First and last timestamps → session time range
#Top 3 most-edited files (from BACKUP lines) using sort | uniq -c | sort -rn | head -3
#File type counts using awk
TOTAL_ACTIONS=$(wc -l < "$LOG_FILE")
BACKUP_COUNT=$(grep -c "BACKUP" "$LOG_FILE")
SYNTAX_OK_COUNT=$(grep -c "SYNTAX_OK" "$LOG_FILE")
SYNTAX_ERROR_COUNT=$(grep -c "SYNTAX_ERROR" "$LOG_FILE")
FIRST_TIMESTAMP=$(head -1 "$LOG_FILE" | cut -d' ' -f1-2)
LAST_TIMESTAMP=$(tail -1 "$LOG_FILE" | cut -d' ' -f1-2)
TOP_FILES=$(grep "BACKUP" "$LOG_FILE" | awk '{print $NF}' | sort | uniq -c | sort -rn | head -3)
FILE_TYPE_COUNTS=$(awk '/BACKUP/ {n=split($NF, a, "."); if (n>1) print a[n]; else print "no_extension"}' "$LOG_FILE" | sort | uniq -c | sort -rn)

echo "================================"
echo "      SESSION SUMMARY REPORT    "
echo "================================"
echo ""
echo "Session: $SESSION_ID"
echo "Period:  $START_TIME -> $END_TIME"
echo ""
echo "--- Activity ---"
echo "Total actions: $TOTAL_ACTIONS"
echo "Backups made:  $BACKUP_COUNT"
echo "Syntax checks: $SYNTAX_OK_COUNT"
echo "Syntax errors: $SYNTAX_ERROR_COUNT"
echo ""
echo "--- Most Edited Files ---"
if [[ -z "$TOP_FILES" ]]; then echo "  None"; else echo "$TOP_FILES"; fi
echo ""
echo "--- File Types ---"
if [[ -z "$FILE_TYPE_COUNTS" ]]; then echo "  None"; else echo "$FILE_TYPE_COUNTS"; fi
echo ""

# 6. Always exit 0
exit 0

