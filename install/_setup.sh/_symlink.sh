#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: symlink
# Creates symbolic links
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_symlink.sh
# input: SOURCE.
# input: DEST.
# input: TARGET.
# input: LINK.
# input: SUDO*=false
# input: FORCE*=false
# validate: SOURCE=path
# validate: DEST=path
# validate: TARGET=path
# validate: LINK=path
# output: LINK:LAST

# Create a symbolic link
# Arguments passed as KEY=VALUE
_symlink() {
    local source=""
    local dest=""
    local use_sudo="false"
    local force="false"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            SOURCE=*|TARGET=*)
                source="${arg#*=}"
                ;;
            DEST=*|LINK=*)
                dest="${arg#*=}"
                ;;
            SUDO=*)
                use_sudo="${arg#SUDO=}"
                ;;
            FORCE=*)
                force="${arg#FORCE=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$source" ]]; then
        echo "ERROR: SOURCE/TARGET is required"
        return 1
    fi
    
    if [[ -z "$dest" ]]; then
        echo "ERROR: DEST/LINK is required"
        return 1
    fi
    
    # Build command
    local cmd="ln -s"
    
    if [[ "$force" == "true" ]]; then
        cmd+=" -f"
    fi
    
    cmd+=" \"$source\" \"$dest\""
    
    # Execute with or without sudo
    local result
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo $cmd" 2>&1)
    else
        result=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to create symlink '$dest' -> '$source': $result"
        return 2
    fi
    
    # Output the link path
    echo "LINK=$dest"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _symlink "$@"
fi
