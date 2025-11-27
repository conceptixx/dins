#!/usr/bin/env bash
# =============================================================================
# DINS Setup Script
# Final setup routine called by 'dinser setup'
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="${DINS_BASE_DIR:-/opt/dins}"
readonly CONFIG_DIR="${BASE_DIR}/config"
readonly LOG_DIR="${BASE_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/setup.log"

# =============================================================================
# LOGGING
# =============================================================================

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] $*" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] ERROR: $*" | tee -a "$LOG_FILE" >&2
}

log_success() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[$timestamp] ✓ $*" | tee -a "$LOG_FILE"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

ensure_directory() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        mkdir -p "$dir"
        log "Created directory: $dir"
    fi
}

check_prerequisites() {
    local missing=()
    
    # Check for required commands
    local cmds=("bash" "curl" "jq")
    for cmd in "${cmds[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing[*]}"
        return 1
    fi
    
    return 0
}

# =============================================================================
# SETUP: INIT
# =============================================================================

setup_init() {
    log "=========================================="
    log "DINS Initialization"
    log "=========================================="
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        return 1
    fi
    
    # Ensure directories exist
    ensure_directory "$LOG_DIR"
    ensure_directory "$CONFIG_DIR"
    ensure_directory "${BASE_DIR}/services"
    ensure_directory "${BASE_DIR}/tmp"
    
    # Create initial configuration
    local config_file="${CONFIG_DIR}/dins.conf"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << EOF
# DINS Configuration File
# Generated: $(date)

# Base directory
DINS_BASE_DIR="${BASE_DIR}"

# Log directory
DINS_LOG_DIR="${LOG_DIR}"

# Config directory
DINS_CONFIG_DIR="${CONFIG_DIR}"

# Docker settings
DINS_DOCKER_NETWORK="dins-network"
DINS_DOCKER_STACK="dins"

# Service settings
DINS_SERVICE_USER="dins"
DINS_SERVICE_GROUP="dins"
EOF
        log_success "Created configuration file: $config_file"
    else
        log "Configuration file already exists: $config_file"
    fi
    
    # Check Docker
    if command -v docker &> /dev/null; then
        log_success "Docker is installed"
        
        # Check if Swarm is active
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            log_success "Docker Swarm is active"
        else
            log "Docker Swarm is not active"
            log "To initialize Swarm, run: docker swarm init"
        fi
    else
        log "Docker is not installed"
        log "To install Docker, run: curl -fsSL https://get.docker.com | sh"
    fi
    
    log ""
    log_success "DINS initialization complete!"
    log ""
    log "Next steps:"
    log "  1. Configure services in ${CONFIG_DIR}"
    log "  2. Run 'dinser setup cli-ui' for CLI interface"
    log "  3. Run 'dinser setup web-ui' for web interface"
    log ""
    
    return 0
}

# =============================================================================
# SETUP: CLI-UI
# =============================================================================

setup_cli_ui() {
    log "=========================================="
    log "Setting up CLI User Interface"
    log "=========================================="
    
    # Create CLI UI configuration
    local cli_config="${CONFIG_DIR}/cli-ui.conf"
    cat > "$cli_config" << EOF
# CLI UI Configuration
# Generated: $(date)

# Enable colors
CLI_COLORS=true

# Default output format (text, json, yaml)
CLI_OUTPUT_FORMAT=text

# History file
CLI_HISTORY_FILE="${BASE_DIR}/.dins_history"

# Prompt style
CLI_PROMPT_STYLE="default"
EOF
    
    log_success "CLI UI configuration created: $cli_config"
    log_success "CLI User Interface setup complete!"
    
    return 0
}

# =============================================================================
# SETUP: WEB-UI
# =============================================================================

setup_web_ui() {
    log "=========================================="
    log "Setting up Web User Interface"
    log "=========================================="
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker is required for Web UI"
        return 1
    fi
    
    # Create web UI configuration
    local web_config="${CONFIG_DIR}/web-ui.conf"
    cat > "$web_config" << EOF
# Web UI Configuration
# Generated: $(date)

# Web server port
WEB_PORT=8080

# Bind address
WEB_BIND_ADDRESS=0.0.0.0

# Enable HTTPS
WEB_HTTPS_ENABLED=false

# Session timeout (seconds)
WEB_SESSION_TIMEOUT=3600

# Static files directory
WEB_STATIC_DIR="${BASE_DIR}/web/static"
EOF
    
    log_success "Web UI configuration created: $web_config"
    
    # Create docker-compose for web UI
    local web_compose="${CONFIG_DIR}/docker-compose.web-ui.yml"
    cat > "$web_compose" << 'EOF'
version: '3.8'

services:
  dins-web-ui:
    image: nginx:alpine
    container_name: dins-web-ui
    ports:
      - "8080:80"
    volumes:
      - ${DINS_BASE_DIR:-/opt/dins}/web:/usr/share/nginx/html:ro
    networks:
      - dins-network
    restart: unless-stopped

networks:
  dins-network:
    external: true
EOF
    
    log_success "Web UI docker-compose created: $web_compose"
    log ""
    log "To start the Web UI, run:"
    log "  cd ${CONFIG_DIR} && docker-compose -f docker-compose.web-ui.yml up -d"
    log ""
    log_success "Web User Interface setup complete!"
    
    return 0
}

# =============================================================================
# SETUP: SERVICE
# =============================================================================

setup_service() {
    local service_name="$1"
    
    log "=========================================="
    log "Setting up Service: $service_name"
    log "=========================================="
    
    # Create service directory
    local service_dir="${BASE_DIR}/services/${service_name}"
    ensure_directory "$service_dir"
    ensure_directory "${service_dir}/config"
    ensure_directory "${service_dir}/data"
    ensure_directory "${service_dir}/logs"
    
    # Create service configuration template
    local service_config="${service_dir}/config/service.conf"
    cat > "$service_config" << EOF
# Service Configuration: ${service_name}
# Generated: $(date)

# Service name
SERVICE_NAME="${service_name}"

# Service directory
SERVICE_DIR="${service_dir}"

# Enable/disable service
SERVICE_ENABLED=true

# Service port (if applicable)
SERVICE_PORT=

# Service replicas (for Docker Swarm)
SERVICE_REPLICAS=1

# Resource limits
SERVICE_CPU_LIMIT=0.5
SERVICE_MEMORY_LIMIT=256M
EOF
    
    log_success "Service configuration created: $service_config"
    
    # Create service docker-compose template
    local service_compose="${service_dir}/docker-compose.yml"
    cat > "$service_compose" << EOF
version: '3.8'

services:
  ${service_name}:
    image: alpine:latest
    container_name: dins-${service_name}
    volumes:
      - ./config:/config:ro
      - ./data:/data
      - ./logs:/logs
    networks:
      - dins-network
    restart: unless-stopped
    deploy:
      replicas: 1
      resources:
        limits:
          cpus: '0.5'
          memory: 256M

networks:
  dins-network:
    external: true
EOF
    
    log_success "Service docker-compose created: $service_compose"
    log ""
    log "To start the service, run:"
    log "  cd ${service_dir} && docker-compose up -d"
    log ""
    log_success "Service '${service_name}' setup complete!"
    
    return 0
}

# =============================================================================
# MAIN
# =============================================================================

show_help() {
    cat << EOF
DINS Setup Script

Usage: $(basename "$0") [options]

Options:
    --init              Initialize DINS system
    --cli-ui            Setup CLI user interface
    --web-ui            Setup web user interface
    --service NAME      Setup a specific service
    -h, --help          Show this help message

Examples:
    $(basename "$0") --init
    $(basename "$0") --cli-ui
    $(basename "$0") --service myservice

EOF
}

main() {
    # Ensure log directory exists
    ensure_directory "$LOG_DIR"
    
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --init)
                setup_init
                exit $?
                ;;
            --cli-ui)
                setup_cli_ui
                exit $?
                ;;
            --web-ui)
                setup_web_ui
                exit $?
                ;;
            --service)
                if [[ $# -lt 2 ]]; then
                    log_error "Service name required"
                    exit 1
                fi
                setup_service "$2"
                exit $?
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

main "$@"
