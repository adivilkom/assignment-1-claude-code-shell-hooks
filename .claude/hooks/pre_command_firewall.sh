#!/bin/bash
# =============================================================================
# Pre-Hook 1: Command Firewall
# Purpose:    Block dangerous bash commands before execution.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (dangerous pattern matched)
# =============================================================================
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# Load dangerous patterns from config file
CONFIG_FILE="$HOOK_DIR/config/dangerous_patterns.txt"
# Extract command and tool_name from JSON input
INPUT="$(cat)"
# Extract the command and tool_name using grep and sed
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
TOOL_NAME="$(printf '%s' "$INPUT" | grep -o '"tool_name":"[^"]*"' | head -1 | sed 's/"tool_name":"//;s/"//')"
# Only run this hook for Bash commands
if [[ "$TOOL_NAME" != "Bash" ]] || [[ -z "$COMMAND" ]]; then
    exit 0
fi
# If config file doesn't exist, allow all commands by default
if [[ ! -f "$CONFIG_FILE" ]]; then
    exit 0
fi
# Check each pattern in the config file against the command
while IFS= read -r line; do
    # Skip empty lines and comments
    if [[ "$line" == "#"* ]] || [[ -z "$line" ]]; then
        continue
    fi
    # Use grep to check if the command contains the dangerous pattern
    if printf '%s' "$COMMAND" | grep -qE "$line"; then
        printf "Error: dangerous patterns %s\n" "$line" >&2
        exit 2
    fi
done < "$CONFIG_FILE"
exit 0