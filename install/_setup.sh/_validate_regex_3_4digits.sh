#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: regex_3_4digits
# Validates values that must be 3 or 4 digits
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_regex_3_4digits.sh
# input: VALUE.
# input: DEFAULT.*
# output: VALUE:VALIDATED

# Validate a 3 or 4 digit value
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional)
#
# Returns:
#   0 on success, outputs validated value
#   1 on failure
_validate_regex_3_4digits() {
    local value="$1"
    local default="$2"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            value="$default"
        else
            echo "ERROR: Value is empty and no default provided"
            return 1
        fi
    fi
    
    # Check for 3 or 4 digit pattern
    if [[ "$value" =~ ^[0-9]{3,4}$ ]]; then
        echo "$value"
        return 0
    fi
    
    echo "ERROR: Value must be 3 or 4 digits: $value"
    return 1
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_regex_3_4digits "$@"
fi
