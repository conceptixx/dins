#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: group
# Validates Unix group name values
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_group.sh
# input: VALUE.
# input: DEFAULT.*
# output: VALUE:VALIDATED

# Validate a Unix group name
# Valid group names:
# - Start with a letter or underscore
# - Contain only letters, digits, underscores, and hyphens
# - Max length 32 characters
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional)
#
# Returns:
#   0 on success, outputs validated group name
#   1 on failure
_validate_group() {
    local value="$1"
    local default="$2"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            value="$default"
        else
            echo "ERROR: Group name value is empty and no default provided"
            return 1
        fi
    fi
    
    # Check length (max 32 characters)
    if [[ ${#value} -gt 32 ]]; then
        echo "ERROR: Group name too long (max 32 characters): $value"
        return 1
    fi
    
    # Check format
    # Must start with letter or underscore, followed by letters, digits, underscores, or hyphens
    if [[ ! "$value" =~ ^[a-zA-Z_][a-zA-Z0-9_-]*$ ]]; then
        echo "ERROR: Invalid group name format: $value"
        echo "       Must start with letter/underscore, contain only alphanumeric, underscore, hyphen"
        return 1
    fi
    
    # Optionally check if group exists (informational only)
    if getent group "$value" &>/dev/null; then
        # Group exists, which is fine
        :
    fi
    
    echo "$value"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_group "$@"
fi
