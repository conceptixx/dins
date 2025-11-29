#!/usr/bin/env bash
# =============================================================================
# DINSER SERVICE COMMAND
# Location: cli/commands/service.sh
# =============================================================================
# description: Manage DINS Swarm services (build, deploy, status, logs)
# =============================================================================
# Implements PART 9 - DINS Swarm Service Construction
# Provides: list, info, build, deploy, remove, logs, status, check
# =============================================================================

set -euo pipefail

# Get script directory and project paths
readonly CMD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly CLI_DIR="$(dirname "$CMD_DIR")"
readonly SETUP_DIR="$(dirname "$CLI_DIR")"
readonly INSTALL_DIR="$(dirname "$SETUP_DIR")"
readonly DINS_ROOT="$(dirname "$INSTALL_DIR")"

# Service directories
readonly SERVICES_DIR="${DINS_ROOT}/services"
readonly CONFIG_DIR="${DINS_ROOT}/config"
readonly SWARM_DIR="${DINS_ROOT}/swarm"
readonly SECRETS_DIR="${DINS_ROOT}/system/secrets"
readonly LOGS_DIR="${DINS_ROOT}/logs"

# Ensure logs directory exists
mkdir -p "${LOGS_DIR}" 2>/dev/null || true

# Log file for service operations
readonly SERVICE_LOG="${LOGS_DIR}/service_operations.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Logging functions
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && echo -e "${CYAN}[DEBUG]${NC} $*"; }

# Log to file
log_operation() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $*" >> "$SERVICE_LOG"
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Check if a service exists
service_exists() {
    local name="$1"
    [[ -d "${SERVICES_DIR}/${name}" ]] && [[ -f "${SERVICES_DIR}/${name}/service.yaml" ]]
}

# Get list of all services
get_all_services() {
    if [[ ! -d "$SERVICES_DIR" ]]; then
        return
    fi
    
    for dir in "$SERVICES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        local name
        name=$(basename "$dir")
        # Skip template/example services
        [[ "$name" == "_example" ]] && continue
        [[ "$name" == "_template" ]] && continue
        # Must have service.yaml
        [[ -f "${dir}/service.yaml" ]] && echo "$name"
    done
}

# Parse YAML field (simple parser for common cases)
yaml_get() {
    local file="$1"
    local key="$2"
    grep -E "^${key}:" "$file" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | tr -d '"' | tr -d "'"
}

# Get nested YAML field (e.g., image.mode)
yaml_get_nested() {
    local file="$1"
    local key="$2"
    local parent="${key%%.*}"
    local child="${key#*.}"
    
    # Simple approach: look for indented key under parent
    awk -v parent="$parent" -v child="$child" '
        $0 ~ "^" parent ":" { in_parent=1; next }
        in_parent && /^[a-zA-Z]/ { in_parent=0 }
        in_parent && $0 ~ "^[[:space:]]+" child ":" {
            sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "")
            gsub(/["'\'']/, "")
            print
            exit
        }
    ' "$file"
}

# Check if Docker is available
check_docker() {
    if ! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    if ! docker info &>/dev/null 2>&1; then
        log_error "Docker is not running or not accessible"
        return 1
    fi
    return 0
}

# Check if Docker Swarm is active
check_swarm() {
    if ! docker info 2>/dev/null | grep -q "Swarm: active"; then
        log_warn "Docker Swarm is not active"
        return 1
    fi
    return 0
}

# =============================================================================
# SUBCOMMANDS
# =============================================================================

# List all services
cmd_service_list() {
    echo "=========================================="
    echo "DINS Services"
    echo "=========================================="
    echo ""
    
    if [[ ! -d "$SERVICES_DIR" ]]; then
        log_warn "Services directory not found: $SERVICES_DIR"
        return 0
    fi
    
    local count=0
    printf "%-25s %-15s %-15s %s\n" "NAME" "TYPE" "MODE" "STATUS"
    printf "%-25s %-15s %-15s %s\n" "----" "----" "----" "------"
    
    for dir in "$SERVICES_DIR"/*/; do
        [[ -d "$dir" ]] || continue
        local name
        name=$(basename "$dir")
        
        # Skip templates
        [[ "$name" == "_example" ]] && continue
        [[ "$name" == "_template" ]] && continue
        
        local service_yaml="${dir}/service.yaml"
        if [[ ! -f "$service_yaml" ]]; then
            continue
        fi
        
        local stype mode status
        stype=$(yaml_get "$service_yaml" "type" || echo "unknown")
        mode=$(yaml_get_nested "$service_yaml" "image.mode" || echo "unknown")
        
        # Check deployment status
        if check_docker 2>/dev/null && check_swarm 2>/dev/null; then
            if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^dins_${name}$"; then
                status="${GREEN}running${NC}"
            else
                status="${YELLOW}not deployed${NC}"
            fi
        else
            status="${CYAN}unknown${NC}"
        fi
        
        printf "%-25s %-15s %-15s %b\n" "$name" "$stype" "$mode" "$status"
        ((count++))
    done
    
    echo ""
    if [[ $count -eq 0 ]]; then
        echo "No services found."
        echo ""
        echo "Create a service by copying the example:"
        echo "  cp -r ${SERVICES_DIR}/_example ${SERVICES_DIR}/my-service"
    else
        echo "Total: $count service(s)"
    fi
    echo ""
}

# Show service info
cmd_service_info() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service info <service_name>"
        return 1
    fi
    
    if ! service_exists "$name"; then
        log_error "Service not found: $name"
        return 1
    fi
    
    local service_yaml="${SERVICES_DIR}/${name}/service.yaml"
    
    echo "=========================================="
    echo "Service: $name"
    echo "=========================================="
    echo ""
    
    echo "Descriptor: $service_yaml"
    echo ""
    
    # Basic info from YAML
    echo "Configuration:"
    echo "  Name: $(yaml_get "$service_yaml" "name")"
    echo "  Description: $(yaml_get "$service_yaml" "description")"
    echo "  Type: $(yaml_get "$service_yaml" "type")"
    echo "  Version: $(yaml_get "$service_yaml" "version")"
    echo ""
    
    echo "Image:"
    echo "  Mode: $(yaml_get_nested "$service_yaml" "image.mode")"
    echo ""
    
    # Directory contents
    echo "Directory Structure:"
    local service_dir="${SERVICES_DIR}/${name}"
    for item in "$service_dir"/*; do
        [[ -e "$item" ]] || continue
        local basename_item
        basename_item=$(basename "$item")
        if [[ -d "$item" ]]; then
            echo "  [DIR]  $basename_item/"
        else
            echo "  [FILE] $basename_item"
        fi
    done
    echo ""
    
    # Deployment status
    echo "Deployment Status:"
    if check_docker 2>/dev/null; then
        if check_swarm 2>/dev/null; then
            local swarm_name="dins_${name}"
            if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${swarm_name}$"; then
                echo "  Status: RUNNING"
                docker service ps "$swarm_name" --format "  {{.Name}}: {{.CurrentState}}" 2>/dev/null | head -5
            else
                echo "  Status: NOT DEPLOYED"
            fi
        else
            echo "  Status: Swarm not active"
        fi
    else
        echo "  Status: Docker not available"
    fi
    echo ""
}

# Build service image
cmd_service_build() {
    local name="${1:-}"
    shift || true
    
    local mode=""
    local force=0
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mode)
                mode="$2"
                shift 2
                ;;
            --force|-f)
                force=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service build <service_name> [--mode local|remote|prebuilt]"
        return 1
    fi
    
    if ! service_exists "$name"; then
        log_error "Service not found: $name"
        return 1
    fi
    
    if ! check_docker; then
        return 1
    fi
    
    local service_yaml="${SERVICES_DIR}/${name}/service.yaml"
    local service_dir="${SERVICES_DIR}/${name}"
    
    # Get mode from descriptor if not specified
    if [[ -z "$mode" ]]; then
        mode=$(yaml_get_nested "$service_yaml" "image.mode" || echo "local-build")
    fi
    
    log_info "Building service: $name (mode: $mode)"
    log_operation "BUILD $name mode=$mode"
    
    case "$mode" in
        local-build|local)
            _build_local "$name" "$service_dir" "$service_yaml"
            ;;
        remote-build|remote)
            _build_remote "$name" "$service_yaml"
            ;;
        prebuilt)
            _pull_prebuilt "$name" "$service_yaml"
            ;;
        *)
            log_error "Unknown build mode: $mode"
            return 1
            ;;
    esac
}

_build_local() {
    local name="$1"
    local service_dir="$2"
    local service_yaml="$3"
    
    local dockerfile="${service_dir}/Dockerfile"
    if [[ ! -f "$dockerfile" ]]; then
        log_error "Dockerfile not found: $dockerfile"
        return 1
    fi
    
    local context
    context=$(yaml_get_nested "$service_yaml" "build.context" || echo ".")
    [[ "$context" == "." ]] && context="$service_dir"
    [[ ! "$context" = /* ]] && context="${service_dir}/${context}"
    
    local version
    version=$(yaml_get "$service_yaml" "version" || echo "latest")
    
    local image_tag="dins/${name}:${version}"
    
    log_info "Building image: $image_tag"
    log_info "Context: $context"
    log_info "Dockerfile: $dockerfile"
    
    if docker build -t "$image_tag" -f "$dockerfile" "$context"; then
        log_info "Build successful: $image_tag"
        log_operation "BUILD SUCCESS $name image=$image_tag"
        return 0
    else
        log_error "Build failed"
        log_operation "BUILD FAILED $name"
        return 1
    fi
}

_build_remote() {
    local name="$1"
    local service_yaml="$2"
    
    local repo_url
    repo_url=$(yaml_get_nested "$service_yaml" "source.repo_url")
    
    if [[ -z "$repo_url" ]]; then
        log_error "No source.repo_url defined for remote build"
        return 1
    fi
    
    local ref
    ref=$(yaml_get_nested "$service_yaml" "source.ref" || echo "main")
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local tmp_dir="/tmp/dins/build/${name}/${timestamp}"
    
    log_info "Cloning from: $repo_url (ref: $ref)"
    log_info "Temp directory: $tmp_dir"
    
    mkdir -p "$tmp_dir"
    
    if ! git clone --depth 1 --branch "$ref" "$repo_url" "$tmp_dir"; then
        log_error "Failed to clone repository"
        rm -rf "$tmp_dir"
        return 1
    fi
    
    local context
    context=$(yaml_get_nested "$service_yaml" "build.context" || echo ".")
    [[ ! "$context" = /* ]] && context="${tmp_dir}/${context}"
    
    local dockerfile_name
    dockerfile_name=$(yaml_get_nested "$service_yaml" "build.dockerfile" || echo "Dockerfile")
    local dockerfile="${context}/${dockerfile_name}"
    
    local version
    version=$(yaml_get "$service_yaml" "version" || echo "latest")
    local image_tag="dins/${name}:${version}"
    
    log_info "Building image: $image_tag"
    
    local result=0
    if docker build -t "$image_tag" -f "$dockerfile" "$context"; then
        log_info "Build successful: $image_tag"
        log_operation "BUILD SUCCESS $name image=$image_tag (remote)"
    else
        log_error "Build failed"
        log_operation "BUILD FAILED $name (remote)"
        result=1
    fi
    
    # Cleanup temp directory
    log_info "Cleaning up temporary directory..."
    rm -rf "$tmp_dir"
    
    return $result
}

_pull_prebuilt() {
    local name="$1"
    local service_yaml="$2"
    
    local registry
    registry=$(yaml_get_nested "$service_yaml" "image.registry" || echo "")
    local image_name
    image_name=$(yaml_get_nested "$service_yaml" "image.name")
    local tag
    tag=$(yaml_get_nested "$service_yaml" "image.tag" || echo "latest")
    
    if [[ -z "$image_name" ]]; then
        log_error "No image.name defined for prebuilt mode"
        return 1
    fi
    
    local full_image
    if [[ -n "$registry" ]]; then
        full_image="${registry}/${image_name}:${tag}"
    else
        full_image="${image_name}:${tag}"
    fi
    
    log_info "Pulling image: $full_image"
    
    if docker pull "$full_image"; then
        log_info "Pull successful: $full_image"
        log_operation "PULL SUCCESS $name image=$full_image"
        return 0
    else
        log_error "Pull failed"
        log_operation "PULL FAILED $name image=$full_image"
        return 1
    fi
}

# Deploy service to swarm
cmd_service_deploy() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service deploy <service_name>"
        return 1
    fi
    
    if ! service_exists "$name"; then
        log_error "Service not found: $name"
        return 1
    fi
    
    if ! check_docker; then
        return 1
    fi
    
    if ! check_swarm; then
        log_error "Docker Swarm is not active. Initialize with: docker swarm init"
        return 1
    fi
    
    local service_yaml="${SERVICES_DIR}/${name}/service.yaml"
    local version
    version=$(yaml_get "$service_yaml" "version" || echo "latest")
    local image_tag="dins/${name}:${version}"
    
    # Check if image exists
    if ! docker image inspect "$image_tag" &>/dev/null; then
        log_warn "Image not found: $image_tag"
        log_info "Building image first..."
        if ! cmd_service_build "$name"; then
            return 1
        fi
    fi
    
    log_info "Deploying service: $name"
    log_operation "DEPLOY $name"
    
    # Generate stack file
    local stack_file="${SWARM_DIR}/stack_${name}.yaml"
    _generate_stack_file "$name" "$service_yaml" "$stack_file"
    
    # Deploy stack
    if docker stack deploy -c "$stack_file" "dins"; then
        log_info "Deployment successful: $name"
        log_operation "DEPLOY SUCCESS $name"
        echo ""
        log_info "Check status with: dinser service status $name"
        return 0
    else
        log_error "Deployment failed"
        log_operation "DEPLOY FAILED $name"
        return 1
    fi
}

_generate_stack_file() {
    local name="$1"
    local service_yaml="$2"
    local output_file="$3"
    
    local version
    version=$(yaml_get "$service_yaml" "version" || echo "latest")
    local image_tag="dins/${name}:${version}"
    
    local replicas
    replicas=$(yaml_get_nested "$service_yaml" "runtime.replicas" || echo "1")
    
    mkdir -p "$(dirname "$output_file")"
    
    # Generate minimal stack file
    cat > "$output_file" << EOF
# Generated by DINS/DINSER - do not edit manually
# Service: $name
# Generated: $(date -Iseconds)

version: '3.8'

services:
  ${name}:
    image: ${image_tag}
    deploy:
      replicas: ${replicas}
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
      labels:
        - "dins.managed=true"
        - "dins.service=${name}"
    networks:
      - dins-network

networks:
  dins-network:
    driver: overlay
    attachable: true
EOF
    
    log_debug "Generated stack file: $output_file"
}

# Remove service from swarm
cmd_service_remove() {
    local name="${1:-}"
    local force=0
    
    shift || true
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
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service remove <service_name> [--force]"
        return 1
    fi
    
    if ! check_docker; then
        return 1
    fi
    
    local swarm_name="dins_${name}"
    
    # Check if service is deployed
    if ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${swarm_name}$"; then
        log_warn "Service is not deployed: $name"
        return 0
    fi
    
    # Confirmation
    if [[ $force -eq 0 ]]; then
        echo -e "${YELLOW}Warning: This will remove the service from the swarm.${NC}"
        echo "Service: $name"
        read -p "Are you sure? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Cancelled"
            return 0
        fi
    fi
    
    log_info "Removing service: $name"
    log_operation "REMOVE $name"
    
    if docker service rm "$swarm_name"; then
        log_info "Service removed: $name"
        log_operation "REMOVE SUCCESS $name"
        return 0
    else
        log_error "Failed to remove service"
        log_operation "REMOVE FAILED $name"
        return 1
    fi
}

# Show service logs
cmd_service_logs() {
    local name="${1:-}"
    shift || true
    
    local follow=0
    local tail=100
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --follow|-f)
                follow=1
                shift
                ;;
            --tail)
                tail="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service logs <service_name> [--follow] [--tail N]"
        return 1
    fi
    
    if ! check_docker; then
        return 1
    fi
    
    local swarm_name="dins_${name}"
    
    if ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${swarm_name}$"; then
        log_error "Service is not deployed: $name"
        return 1
    fi
    
    local cmd="docker service logs --tail $tail"
    [[ $follow -eq 1 ]] && cmd="$cmd --follow"
    cmd="$cmd $swarm_name"
    
    exec $cmd
}

# Show service status
cmd_service_status() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service status <service_name>"
        return 1
    fi
    
    if ! check_docker; then
        return 1
    fi
    
    local swarm_name="dins_${name}"
    
    echo "=========================================="
    echo "Service Status: $name"
    echo "=========================================="
    echo ""
    
    if ! docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${swarm_name}$"; then
        echo "Status: NOT DEPLOYED"
        echo ""
        if service_exists "$name"; then
            echo "Service definition exists. Deploy with:"
            echo "  dinser service deploy $name"
        fi
        return 0
    fi
    
    echo "Service Info:"
    docker service inspect "$swarm_name" --format '
  Name: {{.Spec.Name}}
  Image: {{.Spec.TaskTemplate.ContainerSpec.Image}}
  Replicas: {{.Spec.Mode.Replicated.Replicas}}
  Created: {{.CreatedAt}}
  Updated: {{.UpdatedAt}}' 2>/dev/null
    echo ""
    
    echo "Tasks:"
    docker service ps "$swarm_name" --format "  {{.ID}}: {{.CurrentState}} ({{.DesiredState}})" 2>/dev/null
    echo ""
}

# Run service diagnostics
cmd_service_check() {
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        log_error "Service name required"
        echo "Usage: dinser service check <service_name>"
        return 1
    fi
    
    echo "=========================================="
    echo "Service Diagnostics: $name"
    echo "=========================================="
    echo ""
    
    local errors=0
    
    # Check 1: Service definition exists
    echo "1. Service Definition:"
    if service_exists "$name"; then
        echo "   [OK] service.yaml found"
    else
        echo "   [FAIL] service.yaml not found"
        ((errors++))
    fi
    
    # Check 2: Docker available
    echo "2. Docker:"
    if check_docker 2>/dev/null; then
        echo "   [OK] Docker is running"
    else
        echo "   [FAIL] Docker not available"
        ((errors++))
    fi
    
    # Check 3: Swarm active
    echo "3. Docker Swarm:"
    if check_swarm 2>/dev/null; then
        echo "   [OK] Swarm is active"
    else
        echo "   [WARN] Swarm not active"
    fi
    
    # Check 4: Image exists
    echo "4. Image:"
    if service_exists "$name"; then
        local service_yaml="${SERVICES_DIR}/${name}/service.yaml"
        local version
        version=$(yaml_get "$service_yaml" "version" || echo "latest")
        local image_tag="dins/${name}:${version}"
        
        if docker image inspect "$image_tag" &>/dev/null; then
            echo "   [OK] Image exists: $image_tag"
        else
            echo "   [WARN] Image not found: $image_tag"
            echo "         Build with: dinser service build $name"
        fi
    fi
    
    # Check 5: Deployment status
    echo "5. Deployment:"
    local swarm_name="dins_${name}"
    if docker service ls --format '{{.Name}}' 2>/dev/null | grep -q "^${swarm_name}$"; then
        local running
        running=$(docker service ps "$swarm_name" --filter "desired-state=running" --format "{{.ID}}" 2>/dev/null | wc -l)
        echo "   [OK] Service deployed (${running} task(s) running)"
    else
        echo "   [INFO] Service not deployed"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        echo "Result: All checks passed"
        return 0
    else
        echo "Result: $errors error(s) found"
        return 1
    fi
}

# =============================================================================
# HELP
# =============================================================================

show_help() {
    cat << EOF
${BLUE}DINSER SERVICE - Swarm Service Management${NC}

${YELLOW}Usage:${NC}
    dinser service <subcommand> [options]

${YELLOW}Subcommands:${NC}
    list                    List all defined services
    info <name>             Show service details
    build <name>            Build service image
    deploy <name>           Deploy service to swarm
    remove <name>           Remove service from swarm
    logs <name>             View service logs
    status <name>           Show deployment status
    check <name>            Run service diagnostics

${YELLOW}Build Options:${NC}
    --mode <mode>           Build mode: local, remote, prebuilt
    --force                 Skip confirmations

${YELLOW}Logs Options:${NC}
    --follow, -f            Follow log output
    --tail <N>              Number of lines to show (default: 100)

${YELLOW}Examples:${NC}
    dinser service list
    dinser service info my-service
    dinser service build my-service --mode local
    dinser service deploy my-service
    dinser service logs my-service --follow
    dinser service status my-service
    dinser service check my-service
    dinser service remove my-service --force

${YELLOW}Creating a New Service:${NC}
    1. Copy example: cp -r services/_example services/my-service
    2. Edit service.yaml
    3. Build: dinser service build my-service
    4. Deploy: dinser service deploy my-service

EOF
}

# =============================================================================
# ENTRY POINT
# =============================================================================

cmd_service() {
    local subcommand="${1:-}"
    shift || true
    
    case "$subcommand" in
        list|ls)
            cmd_service_list "$@"
            ;;
        info|show)
            cmd_service_info "$@"
            ;;
        build)
            cmd_service_build "$@"
            ;;
        deploy)
            cmd_service_deploy "$@"
            ;;
        remove|rm)
            cmd_service_remove "$@"
            ;;
        logs)
            cmd_service_logs "$@"
            ;;
        status)
            cmd_service_status "$@"
            ;;
        check)
            cmd_service_check "$@"
            ;;
        help|-h|--help|"")
            show_help
            ;;
        *)
            log_error "Unknown subcommand: $subcommand"
            echo ""
            show_help
            return 1
            ;;
    esac
}
