#!/usr/bin/env bash
# =============================================================================
# DINS Validator Module: chmod_mode
# Validates chmod permission mode values
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_chmod_mode.sh
# input: VALUE.
# input: DEFAULT.*=644
# output: VALUE:VALIDATED

# Validate a chmod mode value
# Valid modes:
# - Octal format: 3 or 4 digits (e.g., 755, 0755, 1777)
# - Symbolic format: [ugoa][+-=][rwxXst] (e.g., u+x, go-w, a=rx)
#
# Arguments:
#   $1 - VALUE to validate
#   $2 - DEFAULT value (optional, defaults to 644)
#
# Returns:
#   0 on success, outputs validated mode
#   1 on failure
_validate_chmod_mode() {
    local value="$1"
    local default="${2:-644}"
    
    # Use default if value is empty
    if [[ -z "$value" ]]; then
        value="$default"
    fi
    
    # Remove leading zeros for comparison but keep for output
    local normalized="$value"
    
    # Check for octal format (3 or 4 digits)
    if [[ "$value" =~ ^[0-7]{3,4}$ ]]; then
        # Valid octal mode
        # Validate each digit is 0-7
        local valid=true
        for ((i=0; i<${#value}; i++)); do
            local digit="${value:$i:1}"
            if [[ ! "$digit" =~ ^[0-7]$ ]]; then
                valid=false
                break
            fi
        done
        
        if [[ "$valid" == "true" ]]; then
            echo "$value"
            return 0
        fi
    fi
    
    # Check for symbolic format
    # Pattern: [ugoa]*[+-=][rwxXst]+
    # Can be multiple comma-separated specs
    if [[ "$value" =~ ^[ugoa]*[+-=][rwxXst,+-=ugoa]+$ ]]; then
        echo "$value"
        return 0
    fi
    
    # More flexible symbolic check
    # Split by comma and validate each part
    local IFS=','
    local -a parts
    read -ra parts <<< "$value"
    
    local all_valid=true
    for part in "${parts[@]}"; do
        # Each part should match: [ugoa]*[+-=][rwxXst]+
        if [[ ! "$part" =~ ^[ugoa]*[+-=][rwxXst]+$ ]]; then
            # Check if it's a valid numeric mode
            if [[ ! "$part" =~ ^[0-7]{3,4}$ ]]; then
                all_valid=false
                break
            fi
        fi
    done
    
    if [[ "$all_valid" == "true" ]]; then
        echo "$value"
        return 0
    fi
    
    # Invalid mode
    echo "ERROR: Invalid chmod mode: $value"
    echo "       Expected octal (e.g., 755) or symbolic (e.g., u+x) format"
    return 1
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_chmod_mode "$@"
fi
