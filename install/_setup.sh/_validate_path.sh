#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: path
# Validates filesystem path values
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_path.sh
# input: VALUE.
# input: DEFAULT.*
# output: VALUE:VALIDATED

# Validate a path value
# A valid path:
# - Starts with / (absolute) or is relative
# - Contains no null bytes
# - May contain alphanumeric, /, -, _, .
# - Does not contain ../ sequences for security (optional strict mode)
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional)
#
# Returns:
#   0 on success, outputs validated path
#   1 on failure
_validate_path() {
    local value="$1"
    local default="$2"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        if [[ -n "$default" ]]; then
            value="$default"
        else
            echo "ERROR: Path value is empty and no default provided"
            return 1
        fi
    fi
    
    # Check for null bytes (security)
    if [[ "$value" == *$'\0'* ]]; then
        echo "ERROR: Path contains null bytes"
        return 1
    fi
    
    # Check for basic path pattern
    # Allow absolute paths (starting with /) and relative paths
    # Allow alphanumeric, /, -, _, ., ~, and spaces (quoted paths)
    if [[ ! "$value" =~ ^[/~]?[A-Za-z0-9_./-]*$ ]] && [[ ! "$value" =~ ^[A-Za-z0-9_./-]+$ ]]; then
        # More permissive check for paths with special but valid characters
        if [[ "$value" =~ [[:cntrl:]] ]]; then
            echo "ERROR: Path contains control characters"
            return 1
        fi
    fi
    
    # Optional: Check for directory traversal attempts (strict mode)
    # Uncomment to enable strict mode
    # if [[ "$value" == *".."* ]]; then
    #     echo "ERROR: Path contains directory traversal sequence"
    #     return 1
    # fi
    
    # Normalize the path (remove trailing slashes except for root)
    local normalized="$value"
    if [[ "$normalized" != "/" ]]; then
        normalized="${normalized%/}"
    fi
    
    # Output the validated path
    echo "$normalized"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_path "$@"
fi
