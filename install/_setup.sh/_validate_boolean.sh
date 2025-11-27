#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: boolean
# Validates boolean values (true/false, yes/no, 1/0)
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_boolean.sh
# input: VALUE.
# input: DEFAULT.*=false
# output: VALUE:VALIDATED

# Validate a boolean value
# Accepts: true, false, yes, no, 1, 0, on, off
# Normalizes to: true or false
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional, defaults to false)
#
# Returns:
#   0 on success, outputs normalized boolean (true/false)
#   1 on failure
_validate_boolean() {
    local value="$1"
    local default="${2:-false}"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        value="$default"
    fi
    
    # Normalize to lowercase
    value="${value,,}"
    
    # Check for truthy values
    case "$value" in
        true|yes|1|on)
            echo "true"
            return 0
            ;;
        false|no|0|off)
            echo "false"
            return 0
            ;;
        *)
            echo "ERROR: Invalid boolean value: $value"
            echo "       Expected: true/false, yes/no, 1/0, on/off"
            return 1
            ;;
    esac
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_boolean "$@"
fi
