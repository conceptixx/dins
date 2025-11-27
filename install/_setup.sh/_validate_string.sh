#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: string
# Validates generic string values with optional constraints
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_string.sh
# input: VALUE.
# input: DEFAULT.*
# input: MIN_LENGTH.*=0
# input: MAX_LENGTH.*=4096
# output: VALUE:VALIDATED

# Validate a string value
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional)
#
# Returns:
#   0 on success, outputs validated string
#   1 on failure
_validate_string() {
    local value="$1"
    local default="$2"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            value="$default"
        fi
    fi
    
    # Check for null bytes (security)
    if [[ "$value" == *$'\0'* ]]; then
        echo "ERROR: String contains null bytes"
        return 1
    fi
    
    # Output the validated string
    echo "$value"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_string "$@"
fi
