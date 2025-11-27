#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: chmod
# Changes file/directory permissions
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_chmod.sh
# input: PATH+
# input: MODE.
# input: SUDO*=false
# input: RECURSIVE*=false
# validate: PATH=path
# validate: MODE=chmod_mode
# output: PATH:LAST

# Change file/directory permissions
# Arguments passed as KEY=VALUE
_chmod() {
    local path=""
    local mode=""
    local use_sudo="false"
    local recursive="false"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            PATH=*)
                path="${arg#PATH=}"
                ;;
            MODE=*)
                mode="${arg#MODE=}"
                ;;
            SUDO=*)
                use_sudo="${arg#SUDO=}"
                ;;
            RECURSIVE=*)
                recursive="${arg#RECURSIVE=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$path" ]]; then
        echo "ERROR: PATH is required"
        return 1
    fi
    
    if [[ -z "$mode" ]]; then
        echo "ERROR: MODE is required"
        return 1
    fi
    
    # Check if path exists
    if [[ ! -e "$path" ]]; then
        echo "ERROR: Path does not exist: $path"
        return 1
    fi
    
    # Build command
    local cmd="chmod"
    
    if [[ "$recursive" == "true" ]]; then
        cmd+=" -R"
    fi
    
    cmd+=" $mode \"$path\""
    
    # Execute with or without sudo
    local result
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo $cmd" 2>&1)
    else
        result=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to chmod '$path' to '$mode': $result"
        return 2
    fi
    
    # Output the path
    echo "PATH=$path"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _chmod "$@"
fi
