#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: run_cmd
# Executes arbitrary shell commands with optional sudo support
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_run_cmd.sh
# input: PROMPT.
# input: COMMAND.
# input: SUDO*=false
# input: DESCRIPTION*
# input: IGNORE_ERRORS*=false
# placeholder:keep
# output: OUTPUT:LAST
# output: EXIT_CODE:LAST

# Run a shell command
# Arguments passed as KEY=VALUE
_run_cmd() {
    local prompt=""
    local command=""
    local use_sudo="false"
    local description=""
    local ignore_errors="false"
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            PROMPT=*|COMMAND=*)
                # Use the value, command and prompt are synonymous
                local val="${arg#*=}"
                if [[ -z "$prompt" ]]; then
                    prompt="$val"
                else
                    command="$val"
                fi
                ;;
            SUDO=*)
                use_sudo="${arg#SUDO=}"
                ;;
            DESCRIPTION=*)
                description="${arg#DESCRIPTION=}"
                ;;
            IGNORE_ERRORS=*)
                ignore_errors="${arg#IGNORE_ERRORS=}"
                ;;
        esac
    done
    
    # Use prompt as command if command not set
    if [[ -z "$command" ]] && [[ -n "$prompt" ]]; then
        command="$prompt"
    fi
    
    # Validate required parameters
    if [[ -z "$command" ]]; then
        echo "ERROR: PROMPT or COMMAND is required"
        return 1
    fi
    
    # Log description if provided
    if [[ -n "$description" ]]; then
        echo "INFO: $description"
    fi
    
    # Execute the command
    local result
    local exit_code
    
    if [[ "$use_sudo" == "true" ]]; then
        result=$(eval "sudo bash -c '$command'" 2>&1)
        exit_code=$?
    else
        result=$(eval "$command" 2>&1)
        exit_code=$?
    fi
    
    # Handle result
    if [[ $exit_code -ne 0 ]]; then
        if [[ "$ignore_errors" == "true" ]]; then
            echo "WARN: Command returned non-zero exit code ($exit_code), but ignore_errors is set"
            echo "OUTPUT=$result"
            echo "EXIT_CODE=$exit_code"
            return 0
        else
            echo "ERROR: Command failed with exit code $exit_code: $result"
            echo "EXIT_CODE=$exit_code"
            return 2
        fi
    fi
    
    # Output results
    if [[ -n "$result" ]]; then
        echo "OUTPUT=$result"
    fi
    echo "EXIT_CODE=0"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _run_cmd "$@"
fi
