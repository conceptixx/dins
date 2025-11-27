#!/usr/bin/env bash
# =============================================================================
# DINS Installer & Runtime Orchestrator
# Main installer orchestrator script
# =============================================================================
# This script:
# - Reads the Manifest file
# - Parses sections and operations (indentation-based parent/child)
# - Performs parameter resolution (including PATH/FILE heuristics)
# - Performs placeholder replacement
# - Loads function and validator modules
# - Orchestrates all installation phases
# =============================================================================

set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SETUP_DIR="${SCRIPT_DIR}/_setup.sh"
readonly MANIFEST_FILE="${SETUP_DIR}/Manifest"
readonly LOG_FILE="${SCRIPT_DIR}/install.log"
readonly VERSION="1.0.0"

# Global variables storage (associative array)
declare -A GLOBAL_VARS
declare -A LOADED_MODULES
declare -A LOADED_VALIDATORS
declare -a SECTION_ORDER
declare -A SECTIONS
declare -A OPERATIONS

# Error counters
declare -i ERROR_COUNT=0
declare -i WARN_COUNT=0

# Default indentation step
readonly INDENT_STEP=2

# =============================================================================
# LOGGING FUNCTIONS
# =============================================================================

_log() {
    local level="$1"
    shift
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[$timestamp] [$level] $*"
    echo "$message" | tee -a "$LOG_FILE"
}

log_info() {
    _log "INFO" "$@"
}

log_warn() {
    _log "WARN" "$@"
    ((WARN_COUNT++))
}

log_error() {
    _log "ERROR" "$@"
    ((ERROR_COUNT++))
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        _log "DEBUG" "$@"
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Trim leading and trailing whitespace
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

# Get indentation level of a line (number of leading spaces)
get_indent_level() {
    local line="$1"
    local spaces="${line%%[! ]*}"
    echo "${#spaces}"
}

# Normalize parameter name to uppercase
normalize_name() {
    local name="$1"
    echo "${name^^}"
}

# Check if a string is path-like (starts with /)
is_path_like_value() {
    local value="$1"
    # Path-like: starts with /, contains no whitespace, may have multiple segments
    if [[ "$value" =~ ^/[^[:space:]]*$ ]]; then
        return 0
    fi
    return 1
}

# Check if a string is file-like (contains dot, no slashes)
is_file_like_value() {
    local value="$1"
    # File-like: no slashes, contains at least one dot not at start/end, no whitespace
    if [[ ! "$value" =~ / ]] && [[ "$value" =~ ^[^.[:space:]].*\.[^.[:space:]].*$ ]]; then
        return 0
    fi
    return 1
}

# Check if a parameter name is path-like
is_path_like_name() {
    local name="$1"
    name="$(normalize_name "$name")"
    if [[ "$name" == "PATH" ]] || [[ "$name" == *_PATH ]] || [[ "$name" == *PATH* ]]; then
        return 0
    fi
    return 1
}

# Check if a parameter name is file-like
is_file_like_name() {
    local name="$1"
    name="$(normalize_name "$name")"
    if [[ "$name" == "FILE" ]] || [[ "$name" == *_FILE ]] || [[ "$name" == *FILE* ]]; then
        return 0
    fi
    return 1
}

# =============================================================================
# PLACEHOLDER HANDLING
# =============================================================================

# Expand placeholders in a string
# Usage: expand_placeholders "string with {%PLACEHOLDER%}"
expand_placeholders() {
    local input="$1"
    local max_depth=10
    local depth=0
    local result="$input"
    local changed=1
    
    while [[ $changed -eq 1 ]] && [[ $depth -lt $max_depth ]]; do
        changed=0
        ((depth++))
        
        # Find all placeholders {%NAME%}
        while [[ "$result" =~ \{%([A-Za-z0-9_]+)%\} ]]; do
            local placeholder="${BASH_REMATCH[0]}"
            local var_name="${BASH_REMATCH[1]}"
            local normalized_name
            normalized_name="$(normalize_name "$var_name")"
            
            # Look up the variable
            local var_value=""
            if [[ -v "GLOBAL_VARS[$normalized_name]" ]]; then
                var_value="${GLOBAL_VARS[$normalized_name]}"
            elif [[ -v "GLOBAL_VARS[$var_name]" ]]; then
                var_value="${GLOBAL_VARS[$var_name]}"
            fi
            
            if [[ -n "$var_value" ]]; then
                result="${result//$placeholder/$var_value}"
                changed=1
            else
                log_warn "Cannot resolve placeholder: $placeholder"
                break
            fi
        done
    done
    
    if [[ $depth -ge $max_depth ]]; then
        log_error "Maximum placeholder nesting depth reached, possible cyclic definition"
    fi
    
    echo "$result"
}

# =============================================================================
# MODULE LOADING
# =============================================================================

# Load a function module
# Usage: load_module "mkdir"
load_module() {
    local module_name="$1"
    local module_file="${SETUP_DIR}/_${module_name}.sh"
    
    # Check if already loaded
    if [[ -v "LOADED_MODULES[$module_name]" ]]; then
        return 0
    fi
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module_file"
        return 1
    fi
    
    log_debug "Loading module: $module_file"
    # shellcheck source=/dev/null
    source "$module_file"
    LOADED_MODULES[$module_name]=1
    return 0
}

# Load a validator module
# Usage: load_validator "path"
load_validator() {
    local validator_id="$1"
    local validator_file="${SETUP_DIR}/_validate_${validator_id}.sh"
    
    # Check if already loaded
    if [[ -v "LOADED_VALIDATORS[$validator_id]" ]]; then
        return 0
    fi
    
    if [[ ! -f "$validator_file" ]]; then
        log_error "Validator not found: $validator_file"
        return 1
    fi
    
    log_debug "Loading validator: $validator_file"
    # shellcheck source=/dev/null
    source "$validator_file"
    LOADED_VALIDATORS[$validator_id]=1
    return 0
}

# =============================================================================
# DECLARATION PARSING
# =============================================================================

# Parse declaration block from a module file
# Returns associative array with: location, inputs, validates, outputs, placeholder_keep
parse_declaration() {
    local file="$1"
    local -n decl_ref=$2
    
    local in_declaration=0
    local line
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Check for declaration start
        if [[ "$line" =~ ^#[[:space:]]*declaration[[:space:]]*$ ]]; then
            in_declaration=1
            continue
        fi
        
        if [[ $in_declaration -eq 1 ]]; then
            # Check if still in declaration (lines starting with #)
            if [[ ! "$line" =~ ^# ]]; then
                break
            fi
            
            # Parse declaration lines
            local content="${line#\#}"
            content="$(trim "$content")"
            
            if [[ "$content" =~ ^location:[[:space:]]*(.+)$ ]]; then
                decl_ref[location]="${BASH_REMATCH[1]}"
            elif [[ "$content" =~ ^input:[[:space:]]*(.+)$ ]]; then
                local input_spec="${BASH_REMATCH[1]}"
                decl_ref[inputs]+="${input_spec};"
            elif [[ "$content" =~ ^validate:[[:space:]]*(.+)$ ]]; then
                local validate_spec="${BASH_REMATCH[1]}"
                decl_ref[validates]+="${validate_spec};"
            elif [[ "$content" =~ ^output:[[:space:]]*(.+)$ ]]; then
                local output_spec="${BASH_REMATCH[1]}"
                decl_ref[outputs]+="${output_spec};"
            elif [[ "$content" =~ ^placeholder:keep$ ]]; then
                decl_ref[placeholder_keep]=1
            fi
        fi
    done < "$file"
}

# Parse input specification: NAME<CARDINALITY>[=DEFAULT]
# Cardinality: . = exactly one, * = optional, + = one or more
parse_input_spec() {
    local spec="$1"
    local -n result_ref=$2
    
    # Pattern: NAME followed by . or * or +, optionally followed by =DEFAULT
    if [[ "$spec" =~ ^([A-Za-z_][A-Za-z0-9_]*)([.*+])?(=(.*))?$ ]]; then
        result_ref[name]="${BASH_REMATCH[1]}"
        result_ref[cardinality]="${BASH_REMATCH[2]:-.}"
        result_ref[default]="${BASH_REMATCH[4]}"
        return 0
    fi
    return 1
}

# =============================================================================
# MANIFEST PARSING
# =============================================================================

# Parse a parameter line: key="value"
# Returns: key and value
parse_parameter() {
    local line="$1"
    local -n key_ref=$2
    local -n value_ref=$3
    
    # Pattern: key="value" with possible escapes
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=\"(.*)\"$ ]]; then
        key_ref="${BASH_REMATCH[1]}"
        value_ref="${BASH_REMATCH[2]}"
        # Unescape
        value_ref="${value_ref//\\\"/\"}"
        value_ref="${value_ref//\\\\/\\}"
        return 0
    fi
    return 1
}

# Parse operation line with optional daisy-chained parameters
# Format: OPERATION_NAME[:flag1][:flag2][:key="value"]...
parse_operation_line() {
    local line="$1"
    local -n op_name_ref=$2
    local -n op_params_ref=$3
    
    # Split by colons, but be careful with key="value" containing colons
    local trimmed
    trimmed="$(trim "$line")"
    
    # Extract operation name (first segment before : or end)
    if [[ "$trimmed" =~ ^([A-Za-z_][A-Za-z0-9_]*)(:|$) ]]; then
        op_name_ref="${BASH_REMATCH[1]}"
        local remainder="${trimmed#"$op_name_ref"}"
        remainder="${remainder#:}"
        
        # Parse remaining segments
        local segment=""
        local in_quotes=0
        local i
        
        for ((i=0; i<${#remainder}; i++)); do
            local char="${remainder:$i:1}"
            
            if [[ "$char" == '"' ]]; then
                segment+="$char"
                if [[ $in_quotes -eq 0 ]]; then
                    in_quotes=1
                else
                    in_quotes=0
                fi
            elif [[ "$char" == ':' ]] && [[ $in_quotes -eq 0 ]]; then
                # End of segment
                if [[ -n "$segment" ]]; then
                    op_params_ref+=("$segment")
                fi
                segment=""
            else
                segment+="$char"
            fi
        done
        
        # Add last segment
        if [[ -n "$segment" ]]; then
            op_params_ref+=("$segment")
        fi
        
        return 0
    fi
    return 1
}

# Parse the Manifest file
parse_manifest() {
    local manifest="$1"
    
    if [[ ! -f "$manifest" ]]; then
        log_error "Manifest file not found: $manifest"
        return 1
    fi
    
    log_info "Parsing Manifest: $manifest"
    
    local current_section=""
    local current_section_desc=""
    local current_operation=""
    local current_op_indent=0
    local line_num=0
    local -a current_section_ops=()
    local -A current_op_params=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        ((line_num++))
        
        # Skip empty lines
        [[ -z "$(trim "$line")" ]] && continue
        
        # Skip comments
        [[ "$line" =~ ^[[:space:]]*[\;\#] ]] && continue
        
        local indent
        indent=$(get_indent_level "$line")
        local trimmed
        trimmed="$(trim "$line")"
        
        # Section header (no indentation)
        if [[ $indent -eq 0 ]] && [[ "$trimmed" =~ ^\[([^:]+):([^\]]+)\]$ ]]; then
            # Save previous section if exists
            if [[ -n "$current_section" ]]; then
                if [[ -n "$current_operation" ]]; then
                    # Save current operation params
                    local params_str=""
                    for key in "${!current_op_params[@]}"; do
                        params_str+="${key}=\"${current_op_params[$key]}\";"
                    done
                    OPERATIONS["${current_section}:${current_operation}"]="$params_str"
                fi
                SECTIONS["$current_section"]="${current_section_ops[*]}"
            fi
            
            current_section="${BASH_REMATCH[1]}"
            current_section_desc="${BASH_REMATCH[2]}"
            SECTION_ORDER+=("$current_section")
            current_section_ops=()
            current_operation=""
            current_op_params=()
            log_debug "Found section: $current_section ($current_section_desc)"
            continue
        fi
        
        # Must be inside a section
        if [[ -z "$current_section" ]]; then
            log_warn "Line $line_num: Content outside of section: $trimmed"
            continue
        fi
        
        # Check if this is an operation or a parameter
        # Operations start with identifier possibly followed by : or parameters
        if [[ $indent -le $INDENT_STEP ]] || [[ $indent -le $current_op_indent ]]; then
            # This might be a new operation
            local op_name=""
            local -a op_inline_params=()
            
            if parse_operation_line "$trimmed" op_name op_inline_params; then
                # Save previous operation if exists
                if [[ -n "$current_operation" ]]; then
                    local params_str=""
                    for key in "${!current_op_params[@]}"; do
                        params_str+="${key}=\"${current_op_params[$key]}\";"
                    done
                    OPERATIONS["${current_section}:${current_operation}"]="$params_str"
                fi
                
                current_operation="${op_name}_${#current_section_ops[@]}"
                current_section_ops+=("$op_name:$current_operation")
                current_op_indent=$indent
                current_op_params=()
                current_op_params[_op_type]="$op_name"
                
                # Process inline parameters
                for param in "${op_inline_params[@]}"; do
                    if [[ "$param" =~ ^([A-Za-z_][A-Za-z0-9_]*)=\"(.*)\"$ ]]; then
                        # key="value" format
                        current_op_params["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
                    else
                        # Flag format (e.g., "sudo")
                        current_op_params["$param"]="true"
                    fi
                done
                
                log_debug "Found operation: $op_name (section: $current_section)"
                continue
            fi
        fi
        
        # This should be a parameter for the current operation
        if [[ -n "$current_operation" ]]; then
            local param_key=""
            local param_value=""
            
            if parse_parameter "$trimmed" param_key param_value; then
                current_op_params["$param_key"]="$param_value"
                log_debug "Found parameter: $param_key=$param_value"
            else
                log_warn "Line $line_num: Invalid parameter syntax: $trimmed"
            fi
        fi
        
    done < "$manifest"
    
    # Save last section and operation
    if [[ -n "$current_section" ]]; then
        if [[ -n "$current_operation" ]]; then
            local params_str=""
            for key in "${!current_op_params[@]}"; do
                params_str+="${key}=\"${current_op_params[$key]}\";"
            done
            OPERATIONS["${current_section}:${current_operation}"]="$params_str"
        fi
        SECTIONS["$current_section"]="${current_section_ops[*]}"
    fi
    
    log_info "Parsed ${#SECTION_ORDER[@]} sections"
    return 0
}

# =============================================================================
# PARAMETER RESOLUTION
# =============================================================================

# Validate a value using a validator
# Usage: validate_value "validator_id" "value" ["default"]
# Returns: 0 on success (validated value on stdout), non-zero on failure
validate_value() {
    local validator_id="$1"
    local value="$2"
    local default="${3:-}"
    
    if ! load_validator "$validator_id"; then
        return 1
    fi
    
    local func_name="_validate_${validator_id}"
    
    if declare -f "$func_name" > /dev/null 2>&1; then
        "$func_name" "$value" "$default"
        return $?
    else
        log_error "Validator function not found: $func_name"
        return 1
    fi
}

# Resolve parameters for an operation
# This implements the multi-phase parameter resolution algorithm
resolve_parameters() {
    local op_type="$1"
    local -n params_ref=$2
    local -n resolved_ref=$3
    
    local module_file="${SETUP_DIR}/_${op_type}.sh"
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module file not found for operation: $op_type"
        return 1
    fi
    
    # Parse module declaration
    local -A decl
    parse_declaration "$module_file" decl
    
    local placeholder_keep="${decl[placeholder_keep]:-0}"
    local inputs_spec="${decl[inputs]:-}"
    local validates_spec="${decl[validates]:-}"
    
    # Build input definitions
    local -A input_defs  # name -> cardinality
    local -A input_defaults  # name -> default value
    local -A input_validators  # name -> validator_id
    local -a input_order  # preserve declaration order
    
    IFS=';' read -ra input_specs <<< "$inputs_spec"
    for spec in "${input_specs[@]}"; do
        [[ -z "$spec" ]] && continue
        local -A parsed
        if parse_input_spec "$spec" parsed; then
            local input_name
            input_name="$(normalize_name "${parsed[name]}")"
            input_defs[$input_name]="${parsed[cardinality]}"
            input_defaults[$input_name]="${parsed[default]}"
            input_order+=("$input_name")
        fi
    done
    
    # Parse validate specifications
    IFS=';' read -ra validate_specs <<< "$validates_spec"
    for spec in "${validate_specs[@]}"; do
        [[ -z "$spec" ]] && continue
        if [[ "$spec" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.+)$ ]]; then
            local val_name
            val_name="$(normalize_name "${BASH_REMATCH[1]}")"
            input_validators[$val_name]="${BASH_REMATCH[2]}"
        fi
    done
    
    # Track which inputs have been assigned
    local -A assigned_inputs
    local -A unresolved_params
    
    # Phase 1: Direct match
    for key in "${!params_ref[@]}"; do
        [[ "$key" == "_op_type" ]] && continue
        
        local norm_key
        norm_key="$(normalize_name "$key")"
        local value="${params_ref[$key]}"
        
        # Expand placeholders unless placeholder:keep
        if [[ "$placeholder_keep" -ne 1 ]]; then
            value="$(expand_placeholders "$value")"
        fi
        
        if [[ -v "input_defs[$norm_key]" ]] && [[ ! -v "assigned_inputs[$norm_key]" ]]; then
            # Direct match found
            local validator_id="${input_validators[$norm_key]:-}"
            
            # Apply default validator based on name
            if [[ -z "$validator_id" ]]; then
                if is_path_like_name "$norm_key"; then
                    validator_id="path"
                elif is_file_like_name "$norm_key"; then
                    validator_id="file"
                fi
            fi
            
            # Validate if validator exists
            if [[ -n "$validator_id" ]]; then
                local validated_value
                if validated_value=$(validate_value "$validator_id" "$value" "${input_defaults[$norm_key]}"); then
                    resolved_ref[$norm_key]="$validated_value"
                    assigned_inputs[$norm_key]=1
                else
                    log_warn "Validation failed for $key=$value with validator $validator_id"
                    unresolved_params[$key]="$value"
                fi
            else
                resolved_ref[$norm_key]="$value"
                assigned_inputs[$norm_key]=1
            fi
        else
            unresolved_params[$key]="$value"
        fi
    done
    
    # Phase 2: Name heuristics (PATH/FILE)
    for key in "${!unresolved_params[@]}"; do
        local norm_key
        norm_key="$(normalize_name "$key")"
        local value="${unresolved_params[$key]}"
        local matched=0
        
        if is_path_like_name "$norm_key"; then
            # Try to assign to unassigned PATH-type inputs
            for input_name in "${input_order[@]}"; do
                if [[ ! -v "assigned_inputs[$input_name]" ]] && is_path_like_name "$input_name"; then
                    local validator_id="${input_validators[$input_name]:-path}"
                    local validated_value
                    if validated_value=$(validate_value "$validator_id" "$value" "${input_defaults[$input_name]}"); then
                        resolved_ref[$input_name]="$validated_value"
                        assigned_inputs[$input_name]=1
                        unset "unresolved_params[$key]"
                        matched=1
                        break
                    fi
                fi
            done
        elif is_file_like_name "$norm_key"; then
            # Try to assign to unassigned FILE-type inputs
            for input_name in "${input_order[@]}"; do
                if [[ ! -v "assigned_inputs[$input_name]" ]] && is_file_like_name "$input_name"; then
                    local validator_id="${input_validators[$input_name]:-file}"
                    local validated_value
                    if validated_value=$(validate_value "$validator_id" "$value" "${input_defaults[$input_name]}"); then
                        resolved_ref[$input_name]="$validated_value"
                        assigned_inputs[$input_name]=1
                        unset "unresolved_params[$key]"
                        matched=1
                        break
                    fi
                fi
            done
        fi
    done
    
    # Phase 3: Content-type heuristics (value-driven)
    for key in "${!unresolved_params[@]}"; do
        local value="${unresolved_params[$key]}"
        local matched=0
        
        if is_path_like_value "$value"; then
            # Try to assign to unassigned PATH-type inputs
            for input_name in "${input_order[@]}"; do
                if [[ ! -v "assigned_inputs[$input_name]" ]] && is_path_like_name "$input_name"; then
                    local validator_id="${input_validators[$input_name]:-path}"
                    local validated_value
                    if validated_value=$(validate_value "$validator_id" "$value" "${input_defaults[$input_name]}"); then
                        resolved_ref[$input_name]="$validated_value"
                        assigned_inputs[$input_name]=1
                        unset "unresolved_params[$key]"
                        matched=1
                        break
                    fi
                fi
            done
        elif is_file_like_value "$value"; then
            # Try to assign to unassigned FILE-type inputs
            for input_name in "${input_order[@]}"; do
                if [[ ! -v "assigned_inputs[$input_name]" ]] && is_file_like_name "$input_name"; then
                    local validator_id="${input_validators[$input_name]:-file}"
                    local validated_value
                    if validated_value=$(validate_value "$validator_id" "$value" "${input_defaults[$input_name]}"); then
                        resolved_ref[$input_name]="$validated_value"
                        assigned_inputs[$input_name]=1
                        unset "unresolved_params[$key]"
                        matched=1
                        break
                    fi
                fi
            done
        fi
    done
    
    # Phase 4: Global variables
    for key in "${!unresolved_params[@]}"; do
        local norm_key
        norm_key="$(normalize_name "$key")"
        local value="${unresolved_params[$key]}"
        
        # Set as global variable
        if [[ -v "GLOBAL_VARS[$norm_key]" ]]; then
            local old_value="${GLOBAL_VARS[$norm_key]}"
            log_info "Updating global variable: $norm_key (old=$old_value, new=$value)"
        else
            log_info "Setting global variable: $norm_key=$value"
        fi
        GLOBAL_VARS[$norm_key]="$value"
        unset "unresolved_params[$key]"
    done
    
    # Apply defaults for unassigned required inputs
    for input_name in "${input_order[@]}"; do
        if [[ ! -v "assigned_inputs[$input_name]" ]]; then
            local cardinality="${input_defs[$input_name]}"
            local default="${input_defaults[$input_name]}"
            
            if [[ -n "$default" ]]; then
                resolved_ref[$input_name]="$default"
            elif [[ "$cardinality" == "." ]] || [[ "$cardinality" == "+" ]]; then
                log_error "Required input '$input_name' not provided for operation $op_type"
                return 1
            fi
        fi
    done
    
    return 0
}

# =============================================================================
# OPERATION EXECUTION
# =============================================================================

# Execute a single operation
execute_operation() {
    local section="$1"
    local op_key="$2"
    local params_str="$3"
    
    # Parse operation type from key (format: type_index)
    local op_type="${op_key%%_*}"
    
    log_info "[$section] Executing operation: $op_type"
    
    # Load the module
    if ! load_module "$op_type"; then
        log_error "[$section] [$op_type] Failed to load module"
        return 1
    fi
    
    # Parse parameters string back into associative array
    local -A params
    local param
    while IFS=';' read -ra param_parts; do
        for part in "${param_parts[@]}"; do
            [[ -z "$part" ]] && continue
            if [[ "$part" =~ ^([^=]+)=\"(.*)\"$ ]]; then
                params["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
            fi
        done
    done <<< "$params_str"
    
    # Resolve parameters
    local -A resolved_params
    if ! resolve_parameters "$op_type" params resolved_params; then
        log_error "[$section] [$op_type] Parameter resolution failed"
        return 1
    fi
    
    # Build argument list for function call
    local -a func_args=()
    for key in "${!resolved_params[@]}"; do
        func_args+=("${key}=${resolved_params[$key]}")
    done
    
    # Call the function
    local func_name="_${op_type}"
    if declare -f "$func_name" > /dev/null 2>&1; then
        log_debug "Calling $func_name with: ${func_args[*]}"
        
        local output
        local exit_code
        output=$("$func_name" "${func_args[@]}" 2>&1)
        exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_info "[$section] [$op_type] Success"
            # Parse output for variable assignments
            while IFS= read -r line; do
                if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
                    local var_name
                    var_name="$(normalize_name "${BASH_REMATCH[1]}")"
                    GLOBAL_VARS[$var_name]="${BASH_REMATCH[2]}"
                    log_debug "Output variable: $var_name=${BASH_REMATCH[2]}"
                fi
            done <<< "$output"
        elif [[ $exit_code -eq 1 ]]; then
            log_error "[$section] [$op_type] Config error: $output"
            return 1
        else
            log_error "[$section] [$op_type] Runtime error (exit=$exit_code): $output"
            return 2
        fi
    else
        log_error "[$section] [$op_type] Function not found: $func_name"
        return 1
    fi
    
    return 0
}

# Execute all operations in a section
execute_section() {
    local section="$1"
    local ops_str="${SECTIONS[$section]}"
    
    log_info "=== Executing section: $section ==="
    
    local -a ops
    read -ra ops <<< "$ops_str"
    
    local section_errors=0
    
    for op_entry in "${ops[@]}"; do
        local op_type="${op_entry%%:*}"
        local op_key="${op_entry#*:}"
        local params_str="${OPERATIONS["${section}:${op_key}"]}"
        
        if ! execute_operation "$section" "$op_key" "$params_str"; then
            ((section_errors++))
        fi
    done
    
    if [[ $section_errors -gt 0 ]]; then
        log_warn "Section '$section' completed with $section_errors error(s)"
        return 1
    fi
    
    log_info "=== Section '$section' completed successfully ==="
    return 0
}

# =============================================================================
# MAIN INSTALLATION ORCHESTRATION
# =============================================================================

run_installation() {
    log_info "Starting DINS Installation (v$VERSION)"
    log_info "Script directory: $SCRIPT_DIR"
    log_info "Setup directory: $SETUP_DIR"
    
    # Initialize system variables
    GLOBAL_VARS[SCRIPT_DIR]="$SCRIPT_DIR"
    GLOBAL_VARS[SETUP_DIR]="$SETUP_DIR"
    
    # Parse the manifest
    if ! parse_manifest "$MANIFEST_FILE"; then
        log_error "Failed to parse Manifest"
        return 1
    fi
    
    # Execute sections in order
    local total_errors=0
    
    for section in "${SECTION_ORDER[@]}"; do
        if ! execute_section "$section"; then
            ((total_errors++))
        fi
    done
    
    # Summary
    log_info "=========================================="
    log_info "Installation Summary"
    log_info "=========================================="
    log_info "Sections processed: ${#SECTION_ORDER[@]}"
    log_info "Total errors: $ERROR_COUNT"
    log_info "Total warnings: $WARN_COUNT"
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        log_error "Installation completed with errors"
        return 1
    else
        log_info "Installation completed successfully"
        return 0
    fi
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

show_help() {
    cat << EOF
DINS Installer & Runtime Orchestrator v$VERSION

Usage: $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    -v, --version   Show version
    -d, --debug     Enable debug mode
    --dry-run       Parse manifest without executing
    --manifest FILE Use alternate manifest file

Environment Variables:
    DEBUG=1         Enable debug logging
    TMP_PATH        Staging directory for dry-run

EOF
}

main() {
    local dry_run=0
    local alt_manifest=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                echo "DINS Installer v$VERSION"
                exit 0
                ;;
            -d|--debug)
                export DEBUG=1
                shift
                ;;
            --dry-run)
                dry_run=1
                shift
                ;;
            --manifest)
                alt_manifest="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Override manifest if specified
    if [[ -n "$alt_manifest" ]]; then
        MANIFEST_FILE="$alt_manifest"
    fi
    
    # Initialize log file
    echo "=== DINS Installation Log ===" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    
    if [[ $dry_run -eq 1 ]]; then
        log_info "DRY RUN MODE - No actual changes will be made"
        GLOBAL_VARS[DRY_RUN]="true"
    fi
    
    run_installation
    exit $?
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
