#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: file
# Validates filename values
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_file.sh
# input: VALUE.
# input: DEFAULT.*
# output: VALUE:VALIDATED

# Validate a filename value
# A valid filename:
# - Does not contain / (path separator)
# - Does not contain null bytes
# - Is not empty
# - Does not start with -
# - May contain alphanumeric, -, _, .
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional)
#
# Returns:
#   0 on success, outputs validated filename
#   1 on failure
_validate_file() {
    local value="$1"
    local default="$2"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            value="$default"
        else
            echo "ERROR: Filename value is empty and no default provided"
            return 1
        fi
    fi
    
    # Check for null bytes (security)
    if [[ "$value" == *$'\0'* ]]; then
        echo "ERROR: Filename contains null bytes"
        return 1
    fi
    
    # Check for path separators (this should be just a filename, not a path)
    if [[ "$value" == */* ]]; then
        echo "ERROR: Filename contains path separator"
        return 1
    fi
    
    # Check for leading dash (could be interpreted as option)
    if [[ "$value" == -* ]]; then
        echo "ERROR: Filename starts with dash"
        return 1
    fi
    
    # Check for control characters
    if [[ "$value" =~ [[:cntrl:]] ]]; then
        echo "ERROR: Filename contains control characters"
        return 1
    fi
    
    # Check for valid filename pattern
    # Allow alphanumeric, -, _, ., and space
    if [[ ! "$value" =~ ^[A-Za-z0-9._-][A-Za-z0-9.\ _-]*$ ]]; then
        # Be more permissive but warn
        echo "WARN: Filename contains unusual characters" >&2
    fi
    
    # Output the validated filename
    echo "$value"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_file "$@"
fi
