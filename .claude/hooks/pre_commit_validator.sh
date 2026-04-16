#!/bin/bash
# =============================================================================
# Pre-Hook 3: Commit Message Validator
# Purpose:    Validate git commit messages follow conventional commit format.
#             Suggests a prefix if one is missing based on staged diff heuristics.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (invalid commit message)
# =============================================================================
RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
# Extract the command from JSON input
CONFIG_FILE="$RUNNER_DIR/config/commit_prefixes.txt"
INPUT="$(cat)"
# Extract the command using grep and sed
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
MSG_FLAG_REGEX="[[:space:]](-[a-zA-Z]*m|--message)([[:space:]]|=)"
# Only run this hook for git commit commands that include a message flag
if [[ "$COMMAND" =~ ^git[[:space:]]+commit ]] && [[ "$COMMAND" =~ $MSG_FLAG_REGEX ]]; then
    # Extract the commit message using grep and sed
    COMMAND_MSG=$(echo "$COMMAND" | sed -E 's/.*(-[a-zA-Z]*m|--message)[[:space:]=]+["'\'']([^"'\'']+)["'\''].*/\2/')
else
    # Not a git commit with a message flag, so we skip validation
    exit 0
fi
# Validate commit message length and format
COMMAND_MSG_LENGTH=$(printf "%s" "$COMMAND_MSG" | wc -m)
# Check if message is too short, too long
if (( COMMAND_MSG_LENGTH < 10 )) || (( COMMAND_MSG_LENGTH > 72 )); then
    printf "Too shortֿ\n" >&2
    exit 2
fi
# Check if message ends with a period
if [[ "$COMMAND_MSG" =~ \.$ ]]; then
    printf "Error: Commit message must not end with a period.\n" >&2
    exit 2
fi
# Check if message starts with a valid prefix from config file
PREFIX_PATTERN=""
while IFS= read -r line; do
    PREFIX_PATTERN="$PREFIX_PATTERN$line|"
done < "$CONFIG_FILE"
# Remove trailing | from PREFIX_PATTERN
PREFIX_PATTERN=$(printf '%s' "$PREFIX_PATTERN" | sed 's/|$//')
# If the message starts with a valid prefix, allow it. Otherwise, block and suggest a prefix based on the staged changes.
if [[ "$COMMAND_MSG" =~ ^($PREFIX_PATTERN): ]]; then
    exit 0
else
    # Analyze staged changes to suggest a prefix
    GIT_STAT=$(git diff --cached --stat)
    GIT_NAME_STAT=$(git diff --cached --name-status)
    # Extract numbers - if grep fails, the variable is assigned a default of 0 later
    RAW_INS=$(echo "$GIT_STAT_SUMMARY" | grep -oE '[0-9]+ insertion' | awk '{print $1}')
    RAW_DEL=$(echo "$GIT_STAT_SUMMARY" | grep -oE '[0-9]+ deletion' | awk '{print $1}')

    # Force numeric values: if empty, set to 0
    INSERTIONS=${RAW_INS:-0}
    DELETIONS=${RAW_DEL:-0}
    SUGGESTED_PREFIX="feat"
    # Heuristic rules to suggest a prefix based on file types and change patterns
    if echo "$GIT_NAME_STAT" | grep -qiE "test|spec"; then
        SUGGESTED_PREFIX="test"
    elif echo "$GIT_NAME_STAT" | grep -qiE "README|\.md"; then
        SUGGESTED_PREFIX="docs"
    elif echo "$GIT_NAME_STAT" | grep -q ^"A"; then
        SUGGESTED_PREFIX="feat"
    elif [[ $DELETIONS > $INSERTIONS ]]; then
        SUGGESTED_PREFIX="refactor"
    fi
    # Final check: if the message doesn't start with a valid prefix, block and suggest one
    printf "Error: BLOCKED: Missing prefix. Based on your changes, try: '%s: %s'.\nValid prefixes: %s\n" \
    "$SUGGESTED_PREFIX" "$COMMAND_MSG" "${PREFIX_PATTERN//|/, }" >&2
    exit 2
fi
exit 0
