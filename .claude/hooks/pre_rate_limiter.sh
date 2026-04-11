#!/bin/bash
# =============================================================================
# Pre-Hook 2: Rate Limiter
# Purpose:    Track command count per session, block after exceeding limit.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},"session_id":"..."}
# Exit codes: 0 = allow (possibly with warning), 2 = blocked (limit exceeded)
# State file: data/.command_count — format per line: session_id|total|type1:N,type2:N,...
# =============================================================================
RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$RUNNER_DIR/.claude/hooks/config/hooks.conf"
INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
SESSION_ID="$(printf '%s' "$INPUT" | grep -o '"session_id":"[^"]*"' | head -1 | sed 's/"session_id":"//;s/"//')"
if [[ -z "$SESSION_ID" ]]; then
    SESSION_ID="default"
fi
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi
source "$CONFIG_FILE"
mkdir -p "$RUNNER_DIR/.claude/hooks/data"
touch "$RUNNER_DIR/.claude/hooks/data/.command_count"
COMMAND_COUNT_FILE="$RUNNER_DIR/.claude/hooks/data/.command_count"
SESSION_LINE=$(grep "^$SESSION_ID|" "$COMMAND_COUNT_FILE" 2>/dev/null)
RESET_FILE="$RUNNER_DIR/.claude/hooks/data/.reset_commands"
if [[ -f "$RESET_FILE" ]]; then
    if [[ -f "$COMMAND_COUNT_FILE" ]]; then
        sed -i "/^$SESSION_ID|/d" "$COMMAND_COUNT_FILE"
    fi
    rm -f "$RESET_FILE"
fi
COMMAND_TYPE=$(echo $COMMAND | cut -d ' ' -f1)
sed -i '/^$(SESSION_LINE)/d' $COMMAND_COUNT_FILE
if [[ -z "$SESSION_LINE" ]]; then
    TOTAL_COUNT=0
    BREAKDOWN=""
else
    TOTAL_COUNT=$(echo "$SESSION_LINE" | cut -d'|' -f2)
    BREAKDOWN=$(echo "$SESSION_LINE" | cut -d'|' -f3)
fi
TOTAL_COUNT=$((TOTAL_COUNT + 1))
if echo "$BREAKDOWN" | grep -q "$COMMAND_TYPE:"; then
    OLD_VAL=$(echo "$BREAKDOWN" | grep -o "$COMMAND_TYPE:[0-9]*" | cut -d':' -f2)
    NEW_VAL=$((OLD_VAL + 1))
    BREAKDOWN=$(echo "$BREAKDOWN" | sed "s/$COMMAND_TYPE:$OLD_VAL/$COMMAND_TYPE:$NEW_VAL/")
else
    if [[ -z "$BREAKDOWN" ]]; then
        BREAKDOWN="$COMMAND_TYPE:1"
    else
        BREAKDOWN="$BREAKDOWN,$COMMAND_TYPE:1"
    fi
fi
NEW_LINE="$SESSION_ID|$TOTAL_COUNT|$BREAKDOWN"
mkdir -p "$(dirname "$COMMAND_COUNT_FILE")"
touch "$COMMAND_COUNT_FILE"
sed -i "/^$SESSION_ID|/d" "$COMMAND_COUNT_FILE"
echo "$NEW_LINE" >> "$COMMAND_COUNT_FILE"

if (( TOTAL_COUNT > MAX_COMMANDS )); then
    printf "Error: Command limit exceeded (%d/%d).\nBreakdown: %s\n" \
           "$TOTAL_COUNT" "$MAX_COMMANDS" "$BREAKDOWN" >&2
    exit 2
elif (( TOTAL_COUNT > WARNING_THRESHOLD )); then
    printf "Warning: You are approaching the command limit (%d/%d).\n" \
           "$TOTAL_COUNT" "$MAX_COMMANDS" >&2
    exit 0
else
    exit 0
fi
exit 0