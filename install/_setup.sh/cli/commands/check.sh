#!/usr/bin/env bash
# =============================================================================
# dinser check - Troubleshooting/diagnostic command
# Location: /dins/install/_setup.sh/cli/commands/check.sh
# description: Run diagnostic checks on DINS components
# =============================================================================
# Implements PART 6.3: Troubleshooting mechanic via `dinser check`
#
# Usage:
#   dinser check web-ui
#   dinser check dins-setup.local
#   dinser check --help
# =============================================================================

# Colors (inherited from parent, but define for standalone)
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
CYAN="${CYAN:-\033[0;36m}"
NC="${NC:-\033[0m}"

# Check result tracking
declare -i CHECK_PASSED=0
declare -i CHECK_FAILED=0
declare -a FAILURES=()

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

check_ok() {
    local name="$1"
    echo -e "  ${GREEN}✓${NC} $name"
    ((CHECK_PASSED++))
}

check_fail() {
    local name="$1"
    local reason="$2"
    echo -e "  ${RED}✗${NC} $name"
    echo -e "    ${YELLOW}→${NC} $reason"
    FAILURES+=("$name: $reason")
    ((CHECK_FAILED++))
}

check_warn() {
    local name="$1"
    local reason="$2"
    echo -e "  ${YELLOW}!${NC} $name"
    echo -e "    ${CYAN}→${NC} $reason"
}

print_summary() {
    echo ""
    echo "=========================================="
    if [[ $CHECK_FAILED -eq 0 ]]; then
        echo -e "${GREEN}STATUS: OK${NC}"
    else
        echo -e "${RED}STATUS: FAILED${NC}"
    fi
    echo "=========================================="
    echo "Checks passed: $CHECK_PASSED"
    echo "Checks failed: $CHECK_FAILED"
    
    if [[ ${#FAILURES[@]} -gt 0 ]]; then
        echo ""
        echo "Failed checks:"
        for failure in "${FAILURES[@]}"; do
            echo "  - $failure"
        done
    fi
}

# =============================================================================
# DIAGNOSTIC CHECKS
# =============================================================================

# Check DNS/Name Resolution
check_dns() {
    local hostname="$1"
    echo "Checking DNS resolution for $hostname..."
    
    if command -v getent &>/dev/null; then
        if getent hosts "$hostname" &>/dev/null; then
            local ip
            ip=$(getent hosts "$hostname" | awk '{print $1}' | head -1)
            check_ok "DNS resolution: $hostname → $ip"
            return 0
        fi
    elif command -v host &>/dev/null; then
        if host "$hostname" &>/dev/null; then
            check_ok "DNS resolution: $hostname resolves"
            return 0
        fi
    elif command -v nslookup &>/dev/null; then
        if nslookup "$hostname" &>/dev/null; then
            check_ok "DNS resolution: $hostname resolves"
            return 0
        fi
    fi
    
    # Try mDNS specifically
    if command -v avahi-resolve &>/dev/null; then
        if avahi-resolve -n "$hostname" &>/dev/null 2>&1; then
            check_ok "DNS resolution (mDNS): $hostname resolves"
            return 0
        fi
    fi
    
    check_fail "DNS resolution" "$hostname cannot be resolved. Check mDNS/Bonjour/Avahi setup."
    return 1
}

# Check network reachability
check_reachability() {
    local hostname="$1"
    echo "Checking network reachability..."
    
    if command -v ping &>/dev/null; then
        if ping -c 1 -W 2 "$hostname" &>/dev/null; then
            check_ok "Network reachability: $hostname is reachable"
            return 0
        fi
    fi
    
    # Fallback: try TCP connection
    if command -v nc &>/dev/null; then
        if nc -z -w 2 "$hostname" 80 &>/dev/null; then
            check_ok "Network reachability: $hostname port 80 open"
            return 0
        fi
    fi
    
    check_fail "Network reachability" "$hostname is not reachable. Check network connection, Wi-Fi, or VPN."
    return 1
}

# Check port availability and conflicts
check_port() {
    local port="$1"
    echo "Checking port $port..."
    
    # Check if port is in use
    local port_info=""
    
    if command -v ss &>/dev/null; then
        port_info=$(ss -tlnp 2>/dev/null | grep ":$port " | head -1)
    elif command -v netstat &>/dev/null; then
        port_info=$(netstat -tlnp 2>/dev/null | grep ":$port " | head -1)
    elif command -v lsof &>/dev/null; then
        port_info=$(lsof -i ":$port" 2>/dev/null | grep LISTEN | head -1)
    fi
    
    if [[ -n "$port_info" ]]; then
        # Port is in use - check if it's DINS
        if echo "$port_info" | grep -qi "dins\|nginx\|docker"; then
            check_ok "Port $port: In use by DINS service"
            return 0
        else
            # Port conflict detected
            local process_name
            process_name=$(echo "$port_info" | grep -oP 'users:\(\("\K[^"]+' || echo "unknown process")
            check_fail "Port $port" "Port conflict - already used by $process_name"
            echo -e "    ${CYAN}Suggestion:${NC} Stop the conflicting service or change DINS port in configuration."
            return 1
        fi
    else
        # Port not in use - might be a problem if DINS should be running
        check_warn "Port $port" "Port not in use. DINS service may not be running."
        return 2
    fi
}

# Check HTTP response
check_http() {
    local url="$1"
    echo "Checking HTTP response from $url..."
    
    local status_code=""
    local response=""
    
    if command -v curl &>/dev/null; then
        status_code=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" 2>/dev/null)
        response=$(curl -s --connect-timeout 5 "$url" 2>/dev/null | head -c 200)
    elif command -v wget &>/dev/null; then
        if wget -q --spider --timeout=5 "$url" 2>/dev/null; then
            status_code="200"
        else
            status_code="000"
        fi
    fi
    
    case "$status_code" in
        200)
            check_ok "HTTP response: $url returns 200 OK"
            return 0
            ;;
        000|"")
            check_fail "HTTP response" "Cannot connect to $url"
            return 1
            ;;
        *)
            check_fail "HTTP response" "$url returns HTTP $status_code"
            return 1
            ;;
    esac
}

# Check Docker service status
check_docker_service() {
    local service_name="$1"
    echo "Checking Docker service: $service_name..."
    
    if ! command -v docker &>/dev/null; then
        check_fail "Docker" "Docker is not installed"
        return 1
    fi
    
    if ! docker info &>/dev/null 2>&1; then
        check_fail "Docker" "Docker daemon is not running or not accessible"
        return 1
    fi
    
    # Check for running containers matching the name
    local container_status
    container_status=$(docker ps --filter "name=$service_name" --format "{{.Status}}" 2>/dev/null | head -1)
    
    if [[ -n "$container_status" ]]; then
        if echo "$container_status" | grep -qi "up"; then
            check_ok "Docker service: $service_name is running ($container_status)"
            return 0
        else
            check_fail "Docker service" "$service_name status: $container_status"
            return 1
        fi
    fi
    
    # Check Docker Swarm services
    if docker node ls &>/dev/null 2>&1; then
        local swarm_status
        swarm_status=$(docker service ls --filter "name=$service_name" --format "{{.Replicas}}" 2>/dev/null | head -1)
        
        if [[ -n "$swarm_status" ]]; then
            if echo "$swarm_status" | grep -qP "^\d+/\d+$"; then
                local running desired
                running=$(echo "$swarm_status" | cut -d'/' -f1)
                desired=$(echo "$swarm_status" | cut -d'/' -f2)
                
                if [[ "$running" -eq "$desired" ]] && [[ "$running" -gt 0 ]]; then
                    check_ok "Docker Swarm service: $service_name ($swarm_status replicas)"
                    return 0
                else
                    check_fail "Docker Swarm service" "$service_name has $running/$desired replicas"
                    return 1
                fi
            fi
        fi
    fi
    
    check_fail "Docker service" "$service_name is not running"
    return 1
}

# Attempt automatic fix
attempt_auto_fix() {
    local fix_type="$1"
    
    case "$fix_type" in
        restart_webui)
            echo ""
            echo -e "${CYAN}Attempting automatic fix: Restarting DINS web-ui service...${NC}"
            
            # Try docker-compose first
            local webui_dir
            webui_dir="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")/_webui.sh/docker"
            
            if [[ -f "$webui_dir/docker-compose.webui.yml" ]]; then
                if docker-compose -f "$webui_dir/docker-compose.webui.yml" restart 2>/dev/null; then
                    echo -e "${GREEN}Restart successful.${NC}"
                    return 0
                fi
            fi
            
            # Try docker service update (Swarm)
            if docker service update --force dins-webui 2>/dev/null; then
                echo -e "${GREEN}Swarm service restart successful.${NC}"
                return 0
            fi
            
            echo -e "${YELLOW}Automatic fix failed. Please restart manually.${NC}"
            return 1
            ;;
        *)
            return 1
            ;;
    esac
}

# =============================================================================
# CHECK TARGETS
# =============================================================================

check_webui() {
    echo ""
    echo "=========================================="
    echo "DINS Web-UI Diagnostic Check"
    echo "=========================================="
    echo ""
    
    local hostname="dins-setup.local"
    local can_reach=1
    
    # Step 1: DNS Resolution
    check_dns "$hostname" || can_reach=0
    
    # Step 2: Network Reachability (only if DNS resolved)
    if [[ $can_reach -eq 1 ]]; then
        check_reachability "$hostname" || can_reach=0
    fi
    
    # Step 3: Port checks
    check_port 80
    local port_result=$?
    
    # Step 4: HTTP check (only if reachable)
    if [[ $can_reach -eq 1 ]] && [[ $port_result -eq 0 ]]; then
        check_http "http://$hostname/"
        check_http "http://$hostname/api/health" || true
    fi
    
    # Step 5: Docker service check
    check_docker_service "dins" || check_docker_service "webui" || check_docker_service "dins-webui"
    
    # Step 6: Summary and auto-fix suggestion
    print_summary
    
    # Offer auto-fix if there were failures
    if [[ $CHECK_FAILED -gt 0 ]]; then
        echo ""
        echo -e "${CYAN}Troubleshooting suggestions:${NC}"
        
        for failure in "${FAILURES[@]}"; do
            case "$failure" in
                *"DNS"*)
                    echo "  - Check that Avahi/mDNS is running: sudo systemctl status avahi-daemon"
                    echo "  - Ensure .local hostname resolution is enabled"
                    ;;
                *"Port conflict"*)
                    echo "  - Stop the conflicting service or reconfigure DINS port"
                    echo "  - Common conflicts: apache2, nginx, other web servers"
                    ;;
                *"Docker"*)
                    echo "  - Start DINS web-ui: dinser webui up"
                    echo "  - Check Docker logs: dinser webui logs"
                    ;;
                *"HTTP"*)
                    echo "  - Restart web-ui service: dinser webui restart"
                    ;;
            esac
        done
    fi
    
    # Exit code
    [[ $CHECK_FAILED -eq 0 ]] && return 0 || return 1
}

# =============================================================================
# COMMAND ENTRY POINT
# =============================================================================

cmd_check() {
    local target="${1:-}"
    
    case "$target" in
        web-ui|webui|dins-setup.local)
            check_webui
            return $?
            ;;
        --help|-h|help|"")
            cat << EOF
${BLUE}dinser check${NC} - Run diagnostic checks on DINS components

${YELLOW}Usage:${NC}
    dinser check <target>

${YELLOW}Available Targets:${NC}
    web-ui              Check DINS WebUI accessibility
    dins-setup.local    Alias for web-ui

${YELLOW}Examples:${NC}
    dinser check web-ui
    dinser check dins-setup.local

${YELLOW}Exit Codes:${NC}
    0   All checks passed
    1   One or more checks failed

EOF
            return 0
            ;;
        *)
            echo -e "${RED}Unknown check target: $target${NC}"
            echo "Use 'dinser check --help' for available targets."
            return 1
            ;;
    esac
}
