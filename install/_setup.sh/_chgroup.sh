#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: chgroup
# Changes file/directory group (chgrp)
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_chgroup.sh
# input: PATH+
# input: GROUP.
# input: SUDO*=false
# input: RECURSIVE*=false
# validate: PATH=path
# output: PATH:LAST

# Change file/directory group
# Arguments passed as KEY=VALUE
_chgroup() {
    local path=""
    local group=""
    local use_sudo="false"
    local recursive="false"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            PATH=*)
                path="${arg#PATH=}"
                ;;
            GROUP=*)
                group="${arg#GROUP=}"
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
    
    if [[ -z "$group" ]]; then
        echo "ERROR: GROUP is required"
        return 1
    fi
    
    # Check if path exists
    if [[ ! -e "$path" ]]; then
        echo "ERROR: Path does not exist: $path"
        return 1
    fi
    
    # Build command
    local cmd="chgrp"
    
    if [[ "$recursive" == "true" ]]; then
        cmd+=" -R"
    fi
    
    cmd+=" $group \"$path\""
    
    # Execute with or without sudo
    local result
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo $cmd" 2>&1)
    else
        result=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to change group of '$path' to '$group': $result"
        return 2
    fi
    
    # Output the path
    echo "PATH=$path"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _chgroup "$@"
fi
