#!/bin/bash
# =============================================================================
# Pre-Hook 1: Command Firewall
# Purpose:    Block dangerous bash commands before execution.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (dangerous pattern matched)
# =============================================================================
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOOK_DIR/config/.claude/hooks/config/dangerous_patterns.txt"
INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
TOOL_NAME="$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | sed 's/"tool_name":"//;s/"//')"
if [[ "$TOOL_NAME" != "Bash" ]]; then
    exit 0
fi
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi
while IFS= read -r line; do
    if [[ "$line" == "#"* ]] || [[ -z "$line" ]]; then
        continue
    fi
    if printf '%s' "$COMMAND" | grep -qE "$line"; then
        printf "Error: dangerous patterns %s\n" "$line" >&2
        exit 2
    fi
done < "$CONFIG_FILE"
exit 0