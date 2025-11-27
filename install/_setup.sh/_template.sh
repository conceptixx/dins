#!/usr/bin/env bash
# =============================================================================
# DINS Function Module: template
# Processes template files with placeholder substitution
# =============================================================================

# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_template.sh
# input: SOURCE_FILE.
# input: DEST_FILE.
# input: VARS*
# input: SUDO*=false
# input: MODE*=644
# placeholder:keep
# validate: SOURCE_FILE=path
# validate: DEST_FILE=path
# validate: MODE=chmod_mode
# output: DEST_FILE:LAST

# Process a template file, replacing placeholders
# Arguments passed as KEY=VALUE
_template() {
    local source_file=""
    local dest_file=""
    local use_sudo="false"
    local mode="644"
    local -A vars=()
    
    # Parse arguments
    for arg in "$@"; do
        case "$arg" in
            SOURCE_FILE=*)
                source_file="${arg#SOURCE_FILE=}"
                ;;
            DEST_FILE=*)
                dest_file="${arg#DEST_FILE=}"
                ;;
            SUDO=*)
                use_sudo="${arg#SUDO=}"
                ;;
            MODE=*)
                mode="${arg#MODE=}"
                ;;
            VARS=*)
                # Parse JSON-like vars specification
                local vars_str="${arg#VARS=}"
                # Simple key=value parsing from comma-separated list
                IFS=',' read -ra var_pairs <<< "$vars_str"
                for pair in "${var_pairs[@]}"; do
                    if [[ "$pair" =~ ^([^=]+)=(.*)$ ]]; then
                        vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
                    fi
                done
                ;;
            *=*)
                # Any other key=value is treated as a template variable
                if [[ "$arg" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                    vars["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
                fi
                ;;
        esac
    done
    
    # Validate required parameters
    if [[ -z "$source_file" ]]; then
        echo "ERROR: SOURCE_FILE is required"
        return 1
    fi
    
    if [[ -z "$dest_file" ]]; then
        echo "ERROR: DEST_FILE is required"
        return 1
    fi
    
    # Check if source exists
    if [[ ! -f "$source_file" ]]; then
        echo "ERROR: Source template file not found: $source_file"
        return 1
    fi
    
    # Read template content
    local content
    content=$(cat "$source_file")
    
    # Replace placeholders {%NAME%}
    for var_name in "${!vars[@]}"; do
        local var_value="${vars[$var_name]}"
        local placeholder="{%${var_name}%}"
        content="${content//$placeholder/$var_value}"
    done
    
    # Create destination directory if needed
    local dest_dir
    dest_dir=$(dirname "$dest_file")
    if [[ ! -d "$dest_dir" ]]; then
        if [[ "$use_sudo" == "true" ]]; then
            sudo mkdir -p "$dest_dir"
        else
            mkdir -p "$dest_dir"
        fi
    fi
    
    # Write processed content
    if [[ "$use_sudo" == "true" ]]; then
        echo "$content" | sudo tee "$dest_file" > /dev/null
        sudo chmod "$mode" "$dest_file"
    else
        echo "$content" > "$dest_file"
        chmod "$mode" "$dest_file"
    fi
    
    local exit_code=$?
    
    if [[ $exit_code -ne 0 ]]; then
        echo "ERROR: Failed to write template output to '$dest_file'"
        return 2
    fi
    
    # Output the destination file path
    echo "DEST_FILE=$dest_file"
    return 0
}

# Run function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _template "$@"
fi
