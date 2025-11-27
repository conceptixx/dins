#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: echo
# Displays messages during installation
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_echo.sh
# input: MESSAGE.
# input: LEVEL*=INFO
# output: MESSAGE:DISPLAYED

# Display a message
# Arguments passed as KEY=VALUE
_echo() {
    local message=""
    local level="INFO"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            MESSAGE=*)
                message="${arg#MESSAGE=}"
                ;;
            LEVEL=*)
                level="${arg#LEVEL=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$message" ]]; then
        echo "ERROR: MESSAGE is required"
        return 1
    fi
    
    # Format based on level
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "${level^^}" in
        INFO)
            echo "[$timestamp] [INFO] $message"
            ;;
        WARN|WARNING)
            echo "[$timestamp] [WARN] $message"
            ;;
        ERROR)
            echo "[$timestamp] [ERROR] $message" >&2
            ;;
        DEBUG)
            if [[ "${DEBUG:-0}" == "1" ]]; then
                echo "[$timestamp] [DEBUG] $message"
            fi
            ;;
        *)
            echo "[$timestamp] [$level] $message"
            ;;
    esac
    
    echo "MESSAGE=$message"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _echo "$@"
fi
