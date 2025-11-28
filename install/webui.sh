#!/usr/bin/env bash
# =============================================================================
# DINS WebUI Installer Orchestrator v1.0
# Location: /dins/install/webui.sh
# =============================================================================
# Manages the DINS Setup WebUI Docker container stack.
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION & DEFAULTS
# =============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WEBUI_ENGINE_DIR="${SCRIPT_DIR}/_webui.sh"
readonly MANIFEST_FILE="${WEBUI_ENGINE_DIR}/Manifest"
readonly DOCKER_DIR="${WEBUI_ENGINE_DIR}/docker"
readonly COMPOSE_FILE="${DOCKER_DIR}/docker-compose.webui.yml"
readonly MODULES_DIR="${WEBUI_ENGINE_DIR}/modules"

# Environment defaults
export DINS_BASE_DIR="${DINS_BASE_DIR:-/opt/dins}"
export DINS_CONFIG_DIR="${DINS_CONFIG_DIR:-${DINS_BASE_DIR}/config}"
export DINS_LOG_DIR="${DINS_LOG_DIR:-${DINS_BASE_DIR}/logs}"
export DINS_SECRETS_DIR="${DINS_SECRETS_DIR:-${DINS_BASE_DIR}/secrets}"
export DINS_WEBUI_DIR="${DINS_WEBUI_DIR:-${DINS_BASE_DIR}/webui}"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${CYAN}[DEBUG]${NC} $*"
    fi
}

log_section() {
    echo ""
    echo -e "${BLUE}============================================${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}============================================${NC}"
}

# Source helper modules if available
source_modules() {
    local module
    for module in "${MODULES_DIR}"/_*.sh; do
        if [[ -f "$module" ]]; then
            # shellcheck source=/dev/null
            source "$module"
            log_debug "Loaded module: $(basename "$module")"
        fi
    done
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    if ! docker info &>/dev/null; then
        log_error "Docker daemon is not running or you don't have permissions"
        return 1
    fi
    
    if ! command -v docker-compose &>/dev/null && ! docker compose version &>/dev/null; then
        log_error "Docker Compose is not installed"
        return 1
    fi
    
    return 0
}

# Get docker compose command
get_compose_cmd() {
    if docker compose version &>/dev/null 2>&1; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# =============================================================================
# USAGE / HELP
# =============================================================================

usage() {
    cat << EOF
${CYAN}DINS WebUI Orchestrator v1.0${NC}

${YELLOW}Usage:${NC}
    ${SCRIPT_NAME} <command> [options]

${YELLOW}Commands:${NC}
    manifest        Run the WebUI manifest to prepare directories, configs, and permissions
    up              Build and start the WebUI Docker stack
    down            Stop and remove the WebUI Docker stack
    restart         Restart the WebUI Docker stack
    status          Show Docker container status and health
    logs            Show container logs (use -f to follow)
    config-path     Print the path to the main configuration file
    build           Build the WebUI Docker images without starting
    shell           Open a shell in the running WebUI container

${YELLOW}Options:${NC}
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --debug     Enable debug mode
    -f, --follow    Follow logs (for logs command)
    --force         Force rebuild images (for up/build commands)

${YELLOW}Environment Variables:${NC}
    DINS_BASE_DIR       Base directory (default: /opt/dins)
    DINS_CONFIG_DIR     Config directory (default: \$DINS_BASE_DIR/config)
    DINS_LOG_DIR        Log directory (default: \$DINS_BASE_DIR/logs)
    DINS_SECRETS_DIR    Secrets directory (default: \$DINS_BASE_DIR/secrets)
    DINS_WEBUI_DIR      WebUI directory (default: \$DINS_BASE_DIR/webui)

${YELLOW}Examples:${NC}
    ${SCRIPT_NAME} manifest       # Prepare all directories and configs
    ${SCRIPT_NAME} up             # Start the WebUI
    ${SCRIPT_NAME} up --force     # Rebuild and start
    ${SCRIPT_NAME} logs -f        # Follow container logs
    ${SCRIPT_NAME} status         # Check container health

${YELLOW}Access:${NC}
    WebUI is available at: ${CYAN}http://dins-setup.local${NC}
    (Ensure dins-setup.local resolves to this host in /etc/hosts)

EOF
}

# =============================================================================
# COMMAND: manifest
# =============================================================================

cmd_manifest() {
    log_section "Running WebUI Manifest"
    
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        log_error "Manifest file not found: $MANIFEST_FILE"
        return 1
    fi
    
    log_info "Base directory: $DINS_BASE_DIR"
    log_info "Config directory: $DINS_CONFIG_DIR"
    log_info "Log directory: $DINS_LOG_DIR"
    log_info "Secrets directory: $DINS_SECRETS_DIR"
    log_info "WebUI directory: $DINS_WEBUI_DIR"
    
    # Source and execute the manifest
    # The manifest uses declarative syntax parsed by our engine
    bash "${SCRIPT_DIR}/_webui.sh/execute_manifest.sh" "$MANIFEST_FILE"
    
    log_info "Manifest execution complete"
    return 0
}

# =============================================================================
# COMMAND: up
# =============================================================================

cmd_up() {
    local force=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force|-f)
                force=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    log_section "Starting WebUI Docker Stack"
    
    check_docker || return 1
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    # Export environment variables for docker-compose
    export DINS_BASE_DIR DINS_CONFIG_DIR DINS_LOG_DIR DINS_SECRETS_DIR DINS_WEBUI_DIR
    
    log_info "Building and starting containers..."
    
    local build_opts=""
    if [[ $force -eq 1 ]]; then
        build_opts="--build --force-recreate"
    fi
    
    # shellcheck disable=SC2086
    $compose_cmd -f "$COMPOSE_FILE" up -d $build_opts
    
    log_info "Waiting for services to become healthy..."
    sleep 3
    
    cmd_status
    
    echo ""
    log_info "WebUI should be accessible at: ${CYAN}http://dins-setup.local${NC}"
    log_info "Ensure 'dins-setup.local' resolves to this host's IP in /etc/hosts"
    
    return 0
}

# =============================================================================
# COMMAND: down
# =============================================================================

cmd_down() {
    log_section "Stopping WebUI Docker Stack"
    
    check_docker || return 1
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    export DINS_BASE_DIR DINS_CONFIG_DIR DINS_LOG_DIR DINS_SECRETS_DIR DINS_WEBUI_DIR
    
    log_info "Stopping and removing containers..."
    $compose_cmd -f "$COMPOSE_FILE" down
    
    log_info "WebUI stack stopped"
    return 0
}

# =============================================================================
# COMMAND: restart
# =============================================================================

cmd_restart() {
    log_section "Restarting WebUI Docker Stack"
    
    cmd_down
    sleep 2
    cmd_up "$@"
    
    return 0
}

# =============================================================================
# COMMAND: status
# =============================================================================

cmd_status() {
    log_section "WebUI Docker Stack Status"
    
    check_docker || return 1
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    export DINS_BASE_DIR DINS_CONFIG_DIR DINS_LOG_DIR DINS_SECRETS_DIR DINS_WEBUI_DIR
    
    echo ""
    echo -e "${YELLOW}Container Status:${NC}"
    $compose_cmd -f "$COMPOSE_FILE" ps
    
    echo ""
    echo -e "${YELLOW}Health Check:${NC}"
    local container_id
    container_id=$(docker ps -q -f "name=dins-setup" 2>/dev/null || true)
    
    if [[ -n "$container_id" ]]; then
        local health
        health=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "unknown")
        echo "  Container: dins-setup"
        echo "  Health: $health"
        
        # Check if API is responding
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:80/api/health" 2>/dev/null | grep -q "200"; then
            echo "  API: ${GREEN}Responding${NC}"
        else
            echo "  API: ${YELLOW}Not responding (may still be starting)${NC}"
        fi
    else
        echo "  No running containers found"
    fi
    
    return 0
}

# =============================================================================
# COMMAND: logs
# =============================================================================

cmd_logs() {
    local follow=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--follow)
                follow=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    check_docker || return 1
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    export DINS_BASE_DIR DINS_CONFIG_DIR DINS_LOG_DIR DINS_SECRETS_DIR DINS_WEBUI_DIR
    
    local follow_opt=""
    if [[ $follow -eq 1 ]]; then
        follow_opt="-f"
    fi
    
    # shellcheck disable=SC2086
    $compose_cmd -f "$COMPOSE_FILE" logs $follow_opt
    
    return 0
}

# =============================================================================
# COMMAND: config-path
# =============================================================================

cmd_config_path() {
    echo "${DINS_CONFIG_DIR}/dins_config.json"
}

# =============================================================================
# COMMAND: build
# =============================================================================

cmd_build() {
    log_section "Building WebUI Docker Images"
    
    check_docker || return 1
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_error "Docker Compose file not found: $COMPOSE_FILE"
        return 1
    fi
    
    local compose_cmd
    compose_cmd=$(get_compose_cmd)
    
    export DINS_BASE_DIR DINS_CONFIG_DIR DINS_LOG_DIR DINS_SECRETS_DIR DINS_WEBUI_DIR
    
    log_info "Building images..."
    $compose_cmd -f "$COMPOSE_FILE" build
    
    log_info "Build complete"
    return 0
}

# =============================================================================
# COMMAND: shell
# =============================================================================

cmd_shell() {
    log_info "Opening shell in WebUI container..."
    
    check_docker || return 1
    
    local container_id
    container_id=$(docker ps -q -f "name=dins-setup" 2>/dev/null || true)
    
    if [[ -z "$container_id" ]]; then
        log_error "No running WebUI container found. Start with: $SCRIPT_NAME up"
        return 1
    fi
    
    docker exec -it "$container_id" /bin/bash
    
    return 0
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    local command=""
    local verbose=0
    local debug=0
    
    # Parse global options first
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                verbose=1
                shift
                ;;
            -d|--debug)
                debug=1
                export DEBUG=1
                shift
                ;;
            -*)
                # Unknown option, pass to command
                break
                ;;
            *)
                command="$1"
                shift
                break
                ;;
        esac
    done
    
    # No command provided
    if [[ -z "$command" ]]; then
        usage
        exit 1
    fi
    
    # Source helper modules
    source_modules
    
    # Execute command
    case "$command" in
        manifest)
            cmd_manifest "$@"
            ;;
        up)
            cmd_up "$@"
            ;;
        down)
            cmd_down "$@"
            ;;
        restart)
            cmd_restart "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        logs)
            cmd_logs "$@"
            ;;
        config-path)
            cmd_config_path "$@"
            ;;
        build)
            cmd_build "$@"
            ;;
        shell)
            cmd_shell "$@"
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
    
    exit $?
}

main "$@"
