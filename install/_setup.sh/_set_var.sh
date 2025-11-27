#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: set_var
# Sets a global variable in the installation context
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_set_var.sh
# input: NAME.
# input: VALUE.
# output: NAME:SET
# output: VALUE:SET

# Set a global variable
# Arguments passed as KEY=VALUE
_set_var() {
    local name=""
    local value=""
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            NAME=*)
                name="${arg#NAME=}"
                ;;
            VALUE=*)
                value="${arg#VALUE=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$name" ]]; then
        echo "ERROR: NAME is required"
        return 1
    fi
    
    # Output the variable assignment
    # The orchestrator will parse this and add to global context
    echo "${name}=${value}"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _set_var "$@"
fi
