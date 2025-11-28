#!/usr/bin/env bash
# =============================================================================
# DINS WebUI Manifest Executor
# Location: /dins/install/_webui.sh/execute_manifest.sh
# =============================================================================
# Parses and executes the WebUI Manifest file.
# =============================================================================

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly MODULES_DIR="${SCRIPT_DIR}/modules"

# Environment defaults
export DINS_BASE_DIR="${DINS_BASE_DIR:-/opt/dins}"
export DINS_CONFIG_DIR="${DINS_CONFIG_DIR:-${DINS_BASE_DIR}/config}"
export DINS_LOG_DIR="${DINS_LOG_DIR:-${DINS_BASE_DIR}/logs}"
export DINS_SECRETS_DIR="${DINS_SECRETS_DIR:-${DINS_BASE_DIR}/secrets}"
export DINS_WEBUI_DIR="${DINS_WEBUI_DIR:-${DINS_BASE_DIR}/webui}"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_section() { echo -e "${BLUE}>>> $*${NC}"; }

# Global variables storage
declare -gA GLOBAL_VARS

# Initialize system variables
init_system_vars() {
    GLOBAL_VARS[DINS_BASE_DIR]="${DINS_BASE_DIR}"
    GLOBAL_VARS[DINS_CONFIG_DIR]="${DINS_CONFIG_DIR}"
    GLOBAL_VARS[DINS_LOG_DIR]="${DINS_LOG_DIR}"
    GLOBAL_VARS[DINS_SECRETS_DIR]="${DINS_SECRETS_DIR}"
    GLOBAL_VARS[DINS_WEBUI_DIR]="${DINS_WEBUI_DIR}"
    GLOBAL_VARS[SCRIPT_DIR]="${SCRIPT_DIR}/.."
}

# Expand placeholders in a string
expand_placeholders() {
    local text="$1"
    local result="$text"
    
    # Replace {%VAR%} patterns with their values
    while [[ "$result" =~ \{%([A-Z_][A-Z0-9_]*)%\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${GLOBAL_VARS[$var_name]:-}"
        
        if [[ -z "$var_value" ]]; then
            # Try environment variable
            var_value="${!var_name:-}"
        fi
        
        if [[ -z "$var_value" ]]; then
            log_warn "Unknown variable: $var_name"
            var_value=""
        fi
        
        result="${result//\{%${var_name}%\}/${var_value}}"
    done
    
    echo "$result"
}

# Execute a module operation
execute_module() {
    local module_name="$1"
    shift
    local -a args=("$@")
    
    local module_file="${MODULES_DIR}/_${module_name}.sh"
    
    # Check if module exists
    if [[ ! -f "$module_file" ]]; then
        log_warn "Module not found: $module_file - using fallback"
        execute_fallback "$module_name" "${args[@]}"
        return $?
    fi
    
    # Source and execute module
    source "$module_file"
    "_${module_name}" "${args[@]}"
    return $?
}

# Fallback execution for modules
execute_fallback() {
    local module_name="$1"
    shift
    local -a args=("$@")
    
    # Parse args into an associative array
    declare -A params
    for arg in "${args[@]}"; do
        if [[ "$arg" =~ ^([^=]+)=(.*)$ ]]; then
            params["${BASH_REMATCH[1]}"]="${BASH_REMATCH[2]}"
        fi
    done
    
    case "$module_name" in
        mkdir)
            local path="${params[path]:-}"
            local mode="${params[mode]:-755}"
            local use_sudo="${params[sudo]:-false}"
            
            path=$(expand_placeholders "$path")
            
            if [[ -z "$path" ]]; then
                log_error "mkdir: path is required"
                return 1
            fi
            
            log_info "Creating directory: $path (mode: $mode)"
            
            if [[ "$use_sudo" == "true" ]]; then
                sudo mkdir -p "$path"
                sudo chmod "$mode" "$path"
            else
                mkdir -p "$path"
                chmod "$mode" "$path"
            fi
            ;;
            
        copy)
            local source="${params[source]:-}"
            local destination="${params[destination]:-}"
            local recursive="${params[recursive]:-false}"
            local use_sudo="${params[sudo]:-false}"
            
            source=$(expand_placeholders "$source")
            destination=$(expand_placeholders "$destination")
            
            if [[ -z "$source" || -z "$destination" ]]; then
                log_error "copy: source and destination are required"
                return 1
            fi
            
            log_info "Copying: $source -> $destination"
            
            local cp_opts="-a"
            if [[ "$recursive" == "true" ]]; then
                cp_opts="-r"
            fi
            
            if [[ "$use_sudo" == "true" ]]; then
                sudo cp $cp_opts "$source" "$destination"
            else
                cp $cp_opts "$source" "$destination"
            fi
            ;;
            
        chmod)
            local path="${params[path]:-}"
            local mode="${params[mode]:-644}"
            local recursive="${params[recursive]:-false}"
            local use_sudo="${params[sudo]:-false}"
            
            path=$(expand_placeholders "$path")
            
            if [[ -z "$path" ]]; then
                log_error "chmod: path is required"
                return 1
            fi
            
            log_info "Setting permissions: $path (mode: $mode, recursive: $recursive)"
            
            local chmod_opts=""
            if [[ "$recursive" == "true" ]]; then
                chmod_opts="-R"
            fi
            
            if [[ "$use_sudo" == "true" ]]; then
                sudo chmod $chmod_opts "$mode" "$path"
            else
                chmod $chmod_opts "$mode" "$path"
            fi
            ;;
            
        chuser)
            local path="${params[path]:-}"
            local user="${params[user]:-}"
            local recursive="${params[recursive]:-false}"
            local use_sudo="${params[sudo]:-false}"
            
            path=$(expand_placeholders "$path")
            
            if [[ -z "$path" || -z "$user" ]]; then
                log_error "chuser: path and user are required"
                return 1
            fi
            
            log_info "Changing owner: $path -> $user"
            
            local chown_opts=""
            if [[ "$recursive" == "true" ]]; then
                chown_opts="-R"
            fi
            
            if [[ "$use_sudo" == "true" ]]; then
                sudo chown $chown_opts "$user" "$path"
            else
                chown $chown_opts "$user" "$path"
            fi
            ;;
            
        chgroup)
            local path="${params[path]:-}"
            local group="${params[group]:-}"
            local recursive="${params[recursive]:-false}"
            local use_sudo="${params[sudo]:-false}"
            
            path=$(expand_placeholders "$path")
            
            if [[ -z "$path" || -z "$group" ]]; then
                log_error "chgroup: path and group are required"
                return 1
            fi
            
            log_info "Changing group: $path -> $group"
            
            local chgrp_opts=""
            if [[ "$recursive" == "true" ]]; then
                chgrp_opts="-R"
            fi
            
            if [[ "$use_sudo" == "true" ]]; then
                sudo chgrp $chgrp_opts "$group" "$path"
            else
                chgrp $chgrp_opts "$group" "$path"
            fi
            ;;
            
        run_cmd)
            local prompt="${params[prompt]:-}"
            local use_sudo="${params[sudo]:-false}"
            local allow_fail="${params[allow_fail]:-false}"
            
            prompt=$(expand_placeholders "$prompt")
            
            if [[ -z "$prompt" ]]; then
                log_error "run_cmd: prompt is required"
                return 1
            fi
            
            log_info "Executing: $prompt"
            
            local exit_code=0
            if [[ "$use_sudo" == "true" ]]; then
                sudo bash -c "$prompt" || exit_code=$?
            else
                bash -c "$prompt" || exit_code=$?
            fi
            
            if [[ $exit_code -ne 0 && "$allow_fail" != "true" ]]; then
                log_error "Command failed with exit code: $exit_code"
                return $exit_code
            fi
            ;;
            
        template)
            local source="${params[source]:-}"
            local destination="${params[destination]:-}"
            local overwrite="${params[overwrite]:-true}"
            local use_sudo="${params[sudo]:-false}"
            
            source=$(expand_placeholders "$source")
            destination=$(expand_placeholders "$destination")
            
            if [[ -z "$source" || -z "$destination" ]]; then
                log_error "template: source and destination are required"
                return 1
            fi
            
            # Check if destination exists and overwrite is false
            if [[ -f "$destination" && "$overwrite" == "false" ]]; then
                log_info "Skipping template (file exists): $destination"
                return 0
            fi
            
            log_info "Processing template: $source -> $destination"
            
            if [[ ! -f "$source" ]]; then
                log_warn "Template source not found: $source - creating default config"
                # Create a minimal default config
                create_default_config "$destination" "$use_sudo"
                return 0
            fi
            
            # Read template and expand placeholders
            local content
            content=$(cat "$source")
            content=$(expand_placeholders "$content")
            
            if [[ "$use_sudo" == "true" ]]; then
                echo "$content" | sudo tee "$destination" > /dev/null
            else
                echo "$content" > "$destination"
            fi
            ;;
            
        echo)
            local message="${params[message]:-}"
            local level="${params[level]:-INFO}"
            
            message=$(expand_placeholders "$message")
            
            case "$level" in
                INFO)  log_info "$message" ;;
                WARN)  log_warn "$message" ;;
                ERROR) log_error "$message" ;;
                *)     echo "$message" ;;
            esac
            ;;
            
        *)
            log_error "Unknown module: $module_name"
            return 1
            ;;
    esac
    
    return 0
}

# Create default configuration
create_default_config() {
    local destination="$1"
    local use_sudo="${2:-false}"
    
    local config_content
    read -r -d '' config_content << 'EOFCONFIG' || true
{
  "version": "1.0.0",
  "instance_role": "master",
  "identity": {
    "node_id": "dins-master",
    "display_name": "DINS Master Node"
  },
  "network": {
    "http": {
      "bind_address": "0.0.0.0",
      "port": 8000,
      "base_path": "/dins"
    }
  },
  "security": {
    "admin": {
      "username": "masteradmin",
      "email": "",
      "email_verified": false,
      "password_secret_file": "/opt/dins/secrets/admin_password",
      "two_factor": {
        "required": true,
        "methods": ["email"],
        "email_otp_enabled": true,
        "totp_enabled": false
      }
    },
    "permissions": {
      "allow_network_scan": false,
      "allow_ssh_scan": false
    },
    "api_tokens": []
  },
  "discovery": {
    "scan_ranges": ["192.168.0.0/24"],
    "ssh_defaults": {
      "username": "pi",
      "password_secret_file": "/opt/dins/secrets/ssh_pi_password"
    },
    "nodes": []
  },
  "cluster": {
    "swarm": {
      "enabled": false,
      "manager_node": "dins-main",
      "nodes": [],
      "replica_policy": {
        "default_replicas": "auto",
        "exceptions": {
          "audio": "pinned",
          "video": "pinned",
          "bluetooth": "pinned",
          "wireless_access": "pinned"
        }
      }
    }
  },
  "audio": {
    "gateways": []
  },
  "stt": {
    "mode": "local",
    "selected_engine_id": "whisper_local",
    "logical_inputs": [],
    "engines": []
  },
  "tts": {
    "engine": "opentts_local",
    "engines": [],
    "outputs": []
  },
  "llm": {
    "mode": "local_first",
    "selected_cloud_provider_id": null,
    "selected_local_provider_id": "ollama",
    "cloud_providers": [],
    "local_providers": [],
    "local": {
      "enabled": true,
      "api_url": "http://dins-llm-server:8001/v1/chat",
      "model": "local-dins-model"
    },
    "cloud": {
      "enabled": false
    }
  },
  "devices": {
    "bluetooth": [],
    "audio": [],
    "video": [],
    "other": []
  },
  "services": {
    "audio": [],
    "enhancements": [],
    "mobile": [],
    "vpn_mesh": [],
    "web": []
  }
}
EOFCONFIG

    # Ensure parent directory exists
    local parent_dir
    parent_dir=$(dirname "$destination")
    
    if [[ "$use_sudo" == "true" ]]; then
        sudo mkdir -p "$parent_dir"
        echo "$config_content" | sudo tee "$destination" > /dev/null
    else
        mkdir -p "$parent_dir"
        echo "$config_content" > "$destination"
    fi
}

# Parse and execute manifest
parse_manifest() {
    local manifest_file="$1"
    
    if [[ ! -f "$manifest_file" ]]; then
        log_error "Manifest file not found: $manifest_file"
        return 1
    fi
    
    local current_section=""
    local current_operation=""
    local current_module=""
    local -a current_args=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty lines and comments
        [[ -z "$line" || "$line" =~ ^[[:space:]]*\; ]] && continue
        
        # Trim whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        
        # Section header: [section:name]
        if [[ "$line" =~ ^\[([^:]+):([^\]]+)\]$ ]]; then
            # Execute pending operation
            if [[ -n "$current_module" && ${#current_args[@]} -gt 0 ]]; then
                execute_module "$current_module" "${current_args[@]}" || true
            fi
            
            current_section="${BASH_REMATCH[1]}"
            current_operation="${BASH_REMATCH[2]}"
            current_module=""
            current_args=()
            
            log_section "Section: $current_section/$current_operation"
            continue
        fi
        
        # Module call: module:operation_name
        if [[ "$line" =~ ^([a-z_]+):([a-z_]+)$ ]]; then
            # Execute pending operation
            if [[ -n "$current_module" && ${#current_args[@]} -gt 0 ]]; then
                execute_module "$current_module" "${current_args[@]}" || true
            fi
            
            current_module="${BASH_REMATCH[1]}"
            current_args=()
            continue
        fi
        
        # Argument: key="value" or key=value
        if [[ "$line" =~ ^([a-z_]+)=\"?([^\"]*)\"?$ || "$line" =~ ^([a-z_]+)=(.*)$ ]]; then
            local key="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            # Remove surrounding quotes if present
            value="${value#\"}"
            value="${value%\"}"
            current_args+=("${key}=${value}")
            continue
        fi
        
    done < "$manifest_file"
    
    # Execute final pending operation
    if [[ -n "$current_module" && ${#current_args[@]} -gt 0 ]]; then
        execute_module "$current_module" "${current_args[@]}" || true
    fi
    
    return 0
}

# Main
main() {
    local manifest_file="${1:-}"
    
    if [[ -z "$manifest_file" ]]; then
        log_error "Usage: $0 <manifest_file>"
        exit 1
    fi
    
    init_system_vars
    
    log_info "Executing manifest: $manifest_file"
    log_info "DINS_BASE_DIR: ${DINS_BASE_DIR}"
    log_info "DINS_CONFIG_DIR: ${DINS_CONFIG_DIR}"
    log_info "DINS_WEBUI_DIR: ${DINS_WEBUI_DIR}"
    
    parse_manifest "$manifest_file"
    
    log_info "Manifest execution complete"
}

main "$@"
