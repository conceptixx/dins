#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: mkdir
# Creates directories with optional mode and sudo support
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_mkdir.sh
# input: PATH+
# input: MODE*=755
# input: SUDO*=false
# input: PARENTS*=true
# validate: PATH=path
# validate: MODE=chmod_mode
# output: PATH:LAST

# Create directory/directories
# Arguments passed as KEY=VALUE
_mkdir() {
    local path=""
    local mode="755"
    local use_sudo="false"
    local parents="true"
    
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
            PARENTS=*)
                parents="${arg#PARENTS=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$path" ]]; then
        echo "ERROR: PATH is required"
        return 1
    fi
    
    # Build command
    local cmd="mkdir"
    
    if [[ "$parents" == "true" ]]; then
        cmd+=" -p"
    fi
    
    cmd+=" -m $mode"
    cmd+=" \"$path\""
    
    # Execute with or without sudo
    local result
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo $cmd" 2>&1)
    else
        result=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to create directory '$path': $result"
        return 2
    fi
    
    # Output the created path
    echo "PATH=$path"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _mkdir "$@"
fi
