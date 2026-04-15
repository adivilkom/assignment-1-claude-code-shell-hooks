#!/bin/bash
# =============================================================================
# Post-Hook 5: Syntax Checker
# Purpose:    Run appropriate syntax checker based on file extension after edit.
# Input:      JSON on stdin: {"tool_name":"Edit","tool_input":{"file_path":"..."},...}
# Exit codes: 0 = syntax OK (or no checker), 1 = syntax error (warn, don't block)
# Supported:  .sh/.bash (bash -n), .py (python3 -m py_compile), .c/.h (gcc -fsyntax-only)
# =============================================================================

RUNNER_DIR="$(cd "$(dirname "$0")" && pwd)"

#Read JSON input from stdin.
INPUT_JSON=$(cat)
#Extract file path and session ID from JSON.
FILE_PATH=$(echo "$INPUT_JSON" | jq -r '.tool_input.file_path')
SESSION_ID=$(echo "$INPUT_JSON" | jq -r '.session_id')
if [[ -z "$FILE_PATH" ]] || [[ ! -f "$FILE_PATH" ]]; then
    exit 0
fi
#Extract the file extension: EXTENSION="${FILE_PATH##*.}".
EXTENSION="${FILE_PATH##*.}"
BASENAME=$(basename "$FILE_PATH")
case "$EXTENSION" in
    (sh|bash)
        bash -n "$FILE_PATH"
        ;;
    (py)
        python3 -m py_compile "$FILE_PATH"
        ;;
    (c|h)
        gcc -fsyntax-only "$FILE_PATH"
        ;;
    (*)
        echo "No syntax checker for .$EXTENSION" >&2
        exit 0
        ;;
esac
#If check fails (non-zero exit):
#Print SYNTAX ERROR in <file_path>: + error output to stderr
#Log: [YYYY-MM-DD HH:MM:SS] SYNTAX_ERROR <file_path> (<extension>)
#Exit 1 (warning — non-fatal)
mkdir -p "$RUNNER_DIR/data"
if [ $? -ne 0 ]; then
    ERROR_MSG=$(case "$EXTENSION" in
        (sh|bash) echo "Syntax error in $FILE_PATH";;
        (py) echo "Syntax error in $FILE_PATH";;
        (c|h) echo "Syntax error in $FILE_PATH";;
    esac)
    echo "$ERROR_MSG" >&2
    #check if data exists, if not create it
    LOG_FILE="$RUNNER_DIR/data/session_${SESSION_ID}.log"
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] SYNTAX_ERROR $FILE_PATH (.$EXTENSION)" >> "$LOG_FILE"
    exit 1
fi
#If check passes:
#Print Syntax OK: <file_path> to stdout
#Log: [YYYY-MM-DD HH:MM:SS] SYNTAX_OK <file_path> (<extension>)
#Exit 0
echo "Syntax OK: $FILE_PATH"
LOG_FILE="$RUNNER_DIR/data/session_${SESSION_ID}.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[$TIMESTAMP] SYNTAX_OK $FILE_PATH (.$EXTENSION)" >> "$LOG_FILE"
exit 0


