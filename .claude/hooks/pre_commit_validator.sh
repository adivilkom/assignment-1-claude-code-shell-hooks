#!/bin/bash
# =============================================================================
# Pre-Hook 3: Commit Message Validator
# Purpose:    Validate git commit messages follow conventional commit format.
#             Suggests a prefix if one is missing based on staged diff heuristics.
# Input:      JSON on stdin: {"tool_name":"Bash","tool_input":{"command":"..."},...}
# Exit codes: 0 = allow, 2 = block (invalid commit message)
# =============================================================================
RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$RUNNER_DIR/.claude/hooks/config/commit_prefixes.txt"
INPUT="$(cat)"
COMMAND="$(printf '%s' "$INPUT" | grep -o '"command":"[^"]*"' | head -1 | sed 's/"command":"//;s/"//')"
if [[ -z "$(printf '%s' "$COMMAND" | grep -qE '^git commit ')" ]]; then
    exit 0
fi
if [[ -z "$(printf '%s' "$COMMAND" | grep -qE ' -m| -[a-zA-Z]*m[a-zA-Z]* | --message')" ]]; then
    exit 0
fi
COMMAND_MSG="$(printf '%s' "$COMMAND" | grep -oP '(-[a-zA-Z]*m|--message)(\s+|=)?\s*"\K[^"]+')"

COMMAND_MSG_LENGTH=$(printf "%s" "$COMMAND_MSG" | wc -m)
if [[ $COMMAND_MSG_LENGTH <= 10 ]] || [[ $COMMAND_MSG_LENGTH >= 72 ]]; then
    printf "Too short" >&2
    exit 2
fi
if [[ "$COMMAND_MSG" =~ \.$ ]]; then
    echo "Error: Commit message must not end with a period." >&2
    exit 2
fi
PREFIX_PATTERN=""
while IFS= read -r line; do
    PREFIX_PATTERN="$PREFIX_PATTERN$line|"
done < "$CONFIG_FILE"
PREFIX_PATTERN=$(printf '%s' "$PREFIX_PATTERN" | sed 's/|$//')
if [[ "$COMMAND_MSG" =~ ^($PREFIX_PATTERN): ]]; then
    exit 0
else
    GIT_STAT=$(git diff --cached --stat)
    GIT_NAME_STAT=$(git diff --cached --name-status)
    INSERTIONS=$(echo "$GIT_STAT" | grep -oP '\d+(?= insertion)' || echo 0)
    DELETIONS=$(echo "$GIT_STAT" | grep -oP '\d+(?= deletion)' || echo 0)
    SUGGESTED_PREFIX="feat"
    if echo "$GIT_NAME_STAT" | grep -qiE "test|spec"; then
        SUGGESTED_PREFIX="test"
    elif echo "$GIT_NAME_STAT" | grep -qiE "README|\.md"; then
        SUGGESTED_PREFIX="docs"
    elif echo "$GIT_NAME_STAT" | grep -q ^"A"; then
        SUGGESTED_PREFIX="feat"
    elif [[ $DELETIONS > $INSERTIONS ]]; then
        SUGGESTED_PREFIX="refactor"
    fi
    printf "Error: BLOCKED: Missing prefix. Based on your changes, try: '%s: \
    your message'.\nValid prefixes: feat, fix, docs, refactor, test, chore\n" \
    "$SUGGESTED_PREFIX" >&2
    exit 2
fi
exit 0
