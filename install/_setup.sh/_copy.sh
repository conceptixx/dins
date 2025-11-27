#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: copy
# Copies files or directories with optional mode and sudo support
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_copy.sh
# input: SOURCE.
# input: DEST.
# input: SOURCE_PATH.
# input: DEST_PATH.
# input: MODE*=644
# input: SUDO*=false
# input: RECURSIVE*=false
# input: PRESERVE*=false
# validate: SOURCE=path
# validate: DEST=path
# validate: SOURCE_PATH=path
# validate: DEST_PATH=path
# validate: MODE=chmod_mode
# output: DEST:LAST

# Copy file or directory
# Arguments passed as KEY=VALUE
_copy() {
    local source=""
    local dest=""
    local mode="644"
    local use_sudo="false"
    local recursive="false"
    local preserve="false"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            SOURCE=*|SOURCE_PATH=*)
                source="${arg#*=}"
                ;;
            DEST=*|DEST_PATH=*)
                dest="${arg#*=}"
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
            PRESERVE=*)
                preserve="${arg#PRESERVE=}"
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$source" ]]; then
        echo "ERROR: SOURCE is required"
        return 1
    fi
    
    if [[ -z "$dest" ]]; then
        echo "ERROR: DEST is required"
        return 1
    fi
    
    # Check if source exists
    if [[ ! -e "$source" ]]; then
        echo "WARN: Source does not exist: $source (skipping)"
        # Return success to allow installation to continue
        echo "DEST=$dest"
        return 0
    fi
    
    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$dest")
    if [[ ! -d "$dest_dir" ]]; then
        local mkdir_cmd="mkdir -p \"$dest_dir\""
        if [[ "$use_sudo" == "true" ]]; then
            eval "sudo $mkdir_cmd" 2>/dev/null
        else
            eval "$mkdir_cmd" 2>/dev/null
        fi
    fi
    
    # Build copy command
    local cmd="cp"
    
    if [[ "$recursive" == "true" ]] || [[ -d "$source" ]]; then
        cmd+=" -r"
    fi
    
    if [[ "$preserve" == "true" ]]; then
        cmd+=" -p"
    fi
    
    cmd+=" \"$source\" \"$dest\""
    
    # Execute copy
    local result
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo $cmd" 2>&1)
    else
        result=$(eval "$cmd" 2>&1)
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to copy '$source' to '$dest': $result"
        return 2
    fi
    
    # Set mode if specified
    if [[ -n "$mode" ]]; then
        local chmod_cmd="chmod $mode \"$dest\""
        if [[ "$use_sudo" == "true" ]]; then
            eval "sudo $chmod_cmd" 2>/dev/null
        else
            eval "$chmod_cmd" 2>/dev/null
        fi
    fi
    
    # Output the destination path
    echo "DEST=$dest"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _copy "$@"
fi
