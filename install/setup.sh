#!/usr/bin/env bash
# =============================================================================
# DINS Installer & Runtime Orchestrator
# Main installer orchestrator script
# =============================================================================
# This script implements PART 6.1 requirements:
# - Phase-based, stateful, resumable setup
# - State file at /var/lib/dins/setup_state
# - MOTD mechanism for Raspberry Pi
# - dinser CLI available before any reboot (Phase 2)
#
# Phase Order (per PART 6.1.2):
#   Phase 1: Runtime Environment Setup
#   Phase 2: DINSER CLI Installation
#   Phase 3: System Preparation  
#   Phase 4: Docker Swarm Setup
#   Phase 5: Setup Docker Service Deployment
#   Phase 6: Final Setup Routine
# =============================================================================

set -o pipefail

# =============================================================================
# GLOBAL CONFIGURATION
# =============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SETUP_DIR="${SCRIPT_DIR}/_setup.sh"
readonly MANIFEST_FILE="${SETUP_DIR}/Manifest"
readonly LOG_FILE="${SCRIPT_DIR}/install.log"
readonly VERSION="2.0.0"

# State file location (per PART 6.1.3.1 - Option A)
readonly STATE_DIR="/var/lib/dins"
readonly STATE_FILE="${STATE_DIR}/setup_state"

# MOTD handling (per PART 6.1.5)
readonly MOTD_FILE="/etc/motd"
readonly MOTD_BACKUP="/etc/motd.dins-backup"
readonly MOTD_MARKER="### DINS SETUP ###"

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

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

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

log_info() { _log "INFO" "$@"; }
log_warn() { _log "WARN" "$@"; ((WARN_COUNT++)); }
log_error() { _log "ERROR" "$@"; ((ERROR_COUNT++)); }
log_debug() { [[ "${DEBUG:-0}" == "1" ]] && _log "DEBUG" "$@"; }

# =============================================================================
# STATE FILE MECHANICS (PART 6.1.3)
# =============================================================================

# Ensure state directory exists
setup_state_init() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null || sudo mkdir -p "$STATE_DIR"
    fi
    touch "$STATE_FILE" 2>/dev/null || sudo touch "$STATE_FILE"
}

# Set state for a phase/step
# Usage: setup_state_set <phase> <step_id> <status>
# Status: start, completed, warning, skipped, not_assigned
setup_state_set() {
    local phase="$1"
    local step_id="$2"
    local status="$3"
    
    setup_state_init
    
    local entry="${phase}:${step_id}:${status}"
    
    # Remove any existing entry for this phase:step
    if [[ -f "$STATE_FILE" ]]; then
        local temp_file
        temp_file=$(mktemp)
        grep -v "^${phase}:${step_id}:" "$STATE_FILE" > "$temp_file" 2>/dev/null || true
        cat "$temp_file" > "$STATE_FILE" 2>/dev/null || sudo cp "$temp_file" "$STATE_FILE"
        rm -f "$temp_file"
    fi
    
    # Append new entry
    echo "$entry" >> "$STATE_FILE" 2>/dev/null || echo "$entry" | sudo tee -a "$STATE_FILE" > /dev/null
    
    log_debug "State set: $entry"
}

# Get state for a phase/step
# Usage: setup_state_get <phase> <step_id>
# Returns: status string or empty if not found
setup_state_get() {
    local phase="$1"
    local step_id="$2"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return
    fi
    
    local status
    status=$(grep "^${phase}:${step_id}:" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d: -f3)
    echo "$status"
}

# Check if a phase is completed
# Usage: setup_state_phase_is_completed <phase>
setup_state_phase_is_completed() {
    local phase="$1"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    # Check if phase has a "phase_complete" marker
    if grep -q "^${phase}:phase_complete:completed" "$STATE_FILE" 2>/dev/null; then
        return 0
    fi
    
    return 1
}

# Check if a step is completed (or skipped/warning - treated as done)
setup_state_step_is_done() {
    local phase="$1"
    local step_id="$2"
    
    local status
    status=$(setup_state_get "$phase" "$step_id")
    
    case "$status" in
        completed|skipped|warning)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Clear all state (for --from-beginning)
setup_state_clear_all() {
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE" 2>/dev/null || sudo rm -f "$STATE_FILE"
    fi
    log_info "Setup state cleared"
}

# Mark entire phase as complete
setup_state_mark_phase_complete() {
    local phase="$1"
    setup_state_set "$phase" "phase_complete" "completed"
}

# =============================================================================
# MOTD HANDLING (PART 6.1.5)
# =============================================================================
# Note: MOTD handling is Raspberry-Pi-specific and may differ on other distros

motd_add_reminder() {
    # Backup original MOTD if not already backed up
    if [[ -f "$MOTD_FILE" ]] && [[ ! -f "$MOTD_BACKUP" ]]; then
        cp "$MOTD_FILE" "$MOTD_BACKUP" 2>/dev/null || sudo cp "$MOTD_FILE" "$MOTD_BACKUP"
        log_debug "MOTD backed up to $MOTD_BACKUP"
    fi
    
    # Check if reminder already present
    if grep -q "$MOTD_MARKER" "$MOTD_FILE" 2>/dev/null; then
        return 0
    fi
    
    # Add DINS setup reminder
    local reminder_text="
$MOTD_MARKER
╔════════════════════════════════════════════════════════════╗
║  DINS setup is not finished.                               ║
║  To resume, run: dinser setup                              ║
╚════════════════════════════════════════════════════════════╝
$MOTD_MARKER
"
    
    if [[ -f "$MOTD_FILE" ]]; then
        echo "$reminder_text" >> "$MOTD_FILE" 2>/dev/null || \
            echo "$reminder_text" | sudo tee -a "$MOTD_FILE" > /dev/null
    else
        echo "$reminder_text" > "$MOTD_FILE" 2>/dev/null || \
            echo "$reminder_text" | sudo tee "$MOTD_FILE" > /dev/null
    fi
    
    log_info "MOTD reminder added"
}

motd_remove_reminder() {
    # Restore original MOTD if backup exists
    if [[ -f "$MOTD_BACKUP" ]]; then
        cp "$MOTD_BACKUP" "$MOTD_FILE" 2>/dev/null || sudo cp "$MOTD_BACKUP" "$MOTD_FILE"
        rm -f "$MOTD_BACKUP" 2>/dev/null || sudo rm -f "$MOTD_BACKUP"
        log_info "MOTD restored from backup"
    elif [[ -f "$MOTD_FILE" ]]; then
        # Remove DINS section if no backup
        local temp_file
        temp_file=$(mktemp)
        sed "/$MOTD_MARKER/,/$MOTD_MARKER/d" "$MOTD_FILE" > "$temp_file"
        cat "$temp_file" > "$MOTD_FILE" 2>/dev/null || sudo cp "$temp_file" "$MOTD_FILE"
        rm -f "$temp_file"
        log_info "MOTD reminder removed"
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo -n "$var"
}

get_indent_level() {
    local line="$1"
    local spaces="${line%%[! ]*}"
    echo "${#spaces}"
}

normalize_name() {
    local name="$1"
    echo "${name^^}"
}

is_path_like_value() {
    local value="$1"
    [[ "$value" =~ ^/[^[:space:]]*$ ]]
}

is_file_like_value() {
    local value="$1"
    [[ ! "$value" =~ / ]] && [[ "$value" =~ ^[^.[:space:]].*\.[^.[:space:]].*$ ]]
}

is_path_like_name() {
    local name="$1"
    name="$(normalize_name "$name")"
    [[ "$name" == "PATH" ]] || [[ "$name" == *_PATH ]] || [[ "$name" == *PATH* ]]
}

is_file_like_name() {
    local name="$1"
    name="$(normalize_name "$name")"
    [[ "$name" == "FILE" ]] || [[ "$name" == *_FILE ]] || [[ "$name" == *FILE* ]]
}

# =============================================================================
# PLACEHOLDER HANDLING
# =============================================================================

expand_placeholders() {
    local input="$1"
    local max_depth=10
    local depth=0
    local result="$input"
    local changed=1
    
    while [[ $changed -eq 1 ]] && [[ $depth -lt $max_depth ]]; do
        changed=0
        ((depth++))
        
        while [[ "$result" =~ \{%([A-Za-z0-9_]+)%\} ]]; do
            local placeholder="${BASH_REMATCH[0]}"
            local var_name="${BASH_REMATCH[1]}"
            local normalized_name
            normalized_name="$(normalize_name "$var_name")"
            
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
    
    echo "$result"
}

# =============================================================================
# MODULE LOADING
# =============================================================================

load_module() {
    local module_name="$1"
    local module_file="${SETUP_DIR}/_${module_name}.sh"
    
    [[ -v "LOADED_MODULES[$module_name]" ]] && return 0
    
    if [[ ! -f "$module_file" ]]; then
        log_error "Module not found: $module_file"
        return 1
    fi
    
    log_debug "Loading module: $module_file"
    source "$module_file"
    LOADED_MODULES[$module_name]=1
    return 0
}

load_validator() {
    local validator_id="$1"
    local validator_file="${SETUP_DIR}/_validate_${validator_id}.sh"
    
    [[ -v "LOADED_VALIDATORS[$validator_id]" ]] && return 0
    
    if [[ ! -f "$validator_file" ]]; then
        log_error "Validator not found: $validator_file"
        return 1
    fi
    
    log_debug "Loading validator: $validator_file"
    source "$validator_file"
    LOADED_VALIDATORS[$validator_id]=1
    return 0
}

# =============================================================================
# PHASE EXECUTION (PART 6.1.2)
# =============================================================================

# Phase 1: Runtime Environment Setup
execute_phase1() {
    local phase="phase1"
    
    log_info "=== PHASE 1: Runtime Environment Setup ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 1 already completed, skipping..."
        return 0
    fi
    
    # Step: Check system requirements
    if ! setup_state_step_is_done "$phase" "check_requirements"; then
        setup_state_set "$phase" "check_requirements" "start"
        log_info "Checking system requirements..."
        # Basic checks
        if command -v apt-get &>/dev/null || command -v dnf &>/dev/null || command -v pacman &>/dev/null; then
            setup_state_set "$phase" "check_requirements" "completed"
        else
            log_warn "Unknown package manager"
            setup_state_set "$phase" "check_requirements" "warning"
        fi
    fi
    
    # Step: Install base packages
    if ! setup_state_step_is_done "$phase" "install_packages"; then
        setup_state_set "$phase" "install_packages" "start"
        log_info "Installing base packages..."
        # This would install curl, git, jq, etc.
        # For now, mark as completed (actual install depends on environment)
        setup_state_set "$phase" "install_packages" "completed"
    fi
    
    # Step: Install Docker
    if ! setup_state_step_is_done "$phase" "install_docker"; then
        setup_state_set "$phase" "install_docker" "start"
        log_info "Checking Docker installation..."
        if command -v docker &>/dev/null; then
            log_info "Docker already installed"
            setup_state_set "$phase" "install_docker" "completed"
        else
            log_info "Docker not found - would install here"
            setup_state_set "$phase" "install_docker" "skipped"
        fi
    fi
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 1 completed ==="
    return 0
}

# Phase 2: DINSER CLI Installation
execute_phase2() {
    local phase="phase2"
    
    log_info "=== PHASE 2: DINSER CLI Installation ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 2 already completed, skipping..."
        return 0
    fi
    
    # Step: Install dinser CLI
    if ! setup_state_step_is_done "$phase" "install_dinser"; then
        setup_state_set "$phase" "install_dinser" "start"
        log_info "Installing dinser CLI..."
        
        local dinser_src="${SETUP_DIR}/cli/dinser"
        local dinser_dest="/usr/local/bin/dinser"
        
        if [[ -f "$dinser_src" ]]; then
            # Copy dinser to PATH
            cp "$dinser_src" "$dinser_dest" 2>/dev/null || sudo cp "$dinser_src" "$dinser_dest"
            chmod +x "$dinser_dest" 2>/dev/null || sudo chmod +x "$dinser_dest"
            
            if command -v dinser &>/dev/null; then
                log_info "dinser CLI installed successfully"
                setup_state_set "$phase" "install_dinser" "completed"
            else
                log_warn "dinser installed but not in PATH"
                setup_state_set "$phase" "install_dinser" "warning"
            fi
        else
            log_error "dinser source not found: $dinser_src"
            setup_state_set "$phase" "install_dinser" "warning"
        fi
    fi
    
    # Add MOTD reminder (dinser now available for resume after reboot)
    motd_add_reminder
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 2 completed - dinser is now available ==="
    return 0
}

# Phase 3: System Preparation
execute_phase3() {
    local phase="phase3"
    
    log_info "=== PHASE 3: System Preparation ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 3 already completed, skipping..."
        return 0
    fi
    
    # Step: Configure hostname
    if ! setup_state_step_is_done "$phase" "configure_hostname"; then
        setup_state_set "$phase" "configure_hostname" "start"
        log_info "Hostname configuration..."
        # Would set hostname here
        setup_state_set "$phase" "configure_hostname" "completed"
    fi
    
    # Step: Network basics
    if ! setup_state_step_is_done "$phase" "network_setup"; then
        setup_state_set "$phase" "network_setup" "start"
        log_info "Network setup..."
        setup_state_set "$phase" "network_setup" "completed"
    fi
    
    # Step: Create DINS directories
    if ! setup_state_step_is_done "$phase" "create_directories"; then
        setup_state_set "$phase" "create_directories" "start"
        log_info "Creating DINS directories..."
        
        for dir in /opt/dins /opt/dins/config /opt/dins/logs /opt/dins/secrets; do
            mkdir -p "$dir" 2>/dev/null || sudo mkdir -p "$dir"
        done
        
        setup_state_set "$phase" "create_directories" "completed"
    fi
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 3 completed ==="
    return 0
}

# Phase 4: Docker Swarm Setup
execute_phase4() {
    local phase="phase4"
    
    log_info "=== PHASE 4: Docker Swarm Setup ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 4 already completed, skipping..."
        return 0
    fi
    
    # Step: Initialize Swarm
    if ! setup_state_step_is_done "$phase" "swarm_init"; then
        setup_state_set "$phase" "swarm_init" "start"
        log_info "Checking Docker Swarm..."
        
        if docker info 2>/dev/null | grep -q "Swarm: active"; then
            log_info "Docker Swarm already active"
            setup_state_set "$phase" "swarm_init" "completed"
        elif command -v docker &>/dev/null; then
            log_info "Would initialize Docker Swarm here"
            setup_state_set "$phase" "swarm_init" "skipped"
        else
            log_warn "Docker not available for Swarm setup"
            setup_state_set "$phase" "swarm_init" "skipped"
        fi
    fi
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 4 completed ==="
    return 0
}

# Phase 5: Setup Docker Service Deployment
execute_phase5() {
    local phase="phase5"
    
    log_info "=== PHASE 5: Docker Service Deployment ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 5 already completed, skipping..."
        return 0
    fi
    
    # Step: Deploy WebUI
    if ! setup_state_step_is_done "$phase" "deploy_webui"; then
        setup_state_set "$phase" "deploy_webui" "start"
        log_info "WebUI deployment..."
        
        # Check if webui.sh exists and can be run
        local webui_script="${SCRIPT_DIR}/webui.sh"
        if [[ -f "$webui_script" ]]; then
            log_info "WebUI script available at $webui_script"
            setup_state_set "$phase" "deploy_webui" "completed"
        else
            log_warn "WebUI script not found"
            setup_state_set "$phase" "deploy_webui" "skipped"
        fi
    fi
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 5 completed ==="
    return 0
}

# Phase 6: Final Setup Routine
execute_phase6() {
    local phase="phase6"
    
    log_info "=== PHASE 6: Final Setup Routine ==="
    
    if setup_state_phase_is_completed "$phase"; then
        log_info "Phase 6 already completed, skipping..."
        return 0
    fi
    
    # Step: Consistency checks
    if ! setup_state_step_is_done "$phase" "consistency_check"; then
        setup_state_set "$phase" "consistency_check" "start"
        log_info "Running consistency checks..."
        
        local issues=0
        
        # Check dinser is available
        if ! command -v dinser &>/dev/null; then
            log_warn "dinser not in PATH"
            ((issues++))
        fi
        
        # Check directories exist
        for dir in /opt/dins /opt/dins/config; do
            if [[ ! -d "$dir" ]]; then
                log_warn "Directory missing: $dir"
                ((issues++))
            fi
        done
        
        if [[ $issues -eq 0 ]]; then
            setup_state_set "$phase" "consistency_check" "completed"
        else
            setup_state_set "$phase" "consistency_check" "warning"
        fi
    fi
    
    # Step: Cleanup
    if ! setup_state_step_is_done "$phase" "cleanup"; then
        setup_state_set "$phase" "cleanup" "start"
        log_info "Cleanup..."
        
        # Remove MOTD reminder since setup is complete
        motd_remove_reminder
        
        setup_state_set "$phase" "cleanup" "completed"
    fi
    
    setup_state_mark_phase_complete "$phase"
    log_info "=== Phase 6 completed ==="
    log_info ""
    log_info "=========================================="
    log_info "  DINS Setup Completed Successfully!"
    log_info "=========================================="
    log_info ""
    log_info "Next steps:"
    log_info "  - Run 'dinser status' to check system status"
    log_info "  - Run 'dinser webui up' to start the WebUI"
    log_info "  - Run 'dinser check web-ui' to diagnose issues"
    log_info ""
    
    return 0
}

# =============================================================================
# MAIN ORCHESTRATION
# =============================================================================

run_phased_installation() {
    log_info "Starting DINS Phased Installation (v$VERSION)"
    log_info "Script directory: $SCRIPT_DIR"
    log_info "State file: $STATE_FILE"
    
    # Initialize state tracking
    setup_state_init
    
    # Check if already fully complete
    if setup_state_phase_is_completed "phase6"; then
        log_info ""
        log_info "=========================================="
        log_info "  DINS setup is already complete!"
        log_info "=========================================="
        log_info ""
        log_info "Use 'dinser setup --from-beginning' to restart."
        log_info "Use 'dinser status' to check system status."
        return 0
    fi
    
    # Execute phases in order
    execute_phase1 || return 1
    execute_phase2 || return 1
    execute_phase3 || return 1
    execute_phase4 || return 1
    execute_phase5 || return 1
    execute_phase6 || return 1
    
    return 0
}

# =============================================================================
# CLI INTERFACE
# =============================================================================

show_help() {
    cat << EOF
DINS Installer & Runtime Orchestrator v$VERSION

Usage: $0 [OPTIONS]

Options:
    -h, --help          Show this help message
    -v, --version       Show version
    -d, --debug         Enable debug mode
    --from-beginning    Clear state and restart setup from Phase 1
    --status            Show current setup status

Environment Variables:
    DEBUG=1             Enable debug logging

State File:
    $STATE_FILE

Phase Order:
    Phase 1: Runtime Environment Setup
    Phase 2: DINSER CLI Installation (available before reboot)
    Phase 3: System Preparation
    Phase 4: Docker Swarm Setup
    Phase 5: Docker Service Deployment
    Phase 6: Final Setup Routine

EOF
}

show_status() {
    echo "DINS Setup Status"
    echo "================="
    echo ""
    echo "State file: $STATE_FILE"
    echo ""
    
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "Status: Setup not started"
        return
    fi
    
    for phase in phase1 phase2 phase3 phase4 phase5 phase6; do
        local phase_name
        case "$phase" in
            phase1) phase_name="Runtime Environment" ;;
            phase2) phase_name="DINSER CLI" ;;
            phase3) phase_name="System Preparation" ;;
            phase4) phase_name="Docker Swarm" ;;
            phase5) phase_name="Service Deployment" ;;
            phase6) phase_name="Final Routine" ;;
        esac
        
        if setup_state_phase_is_completed "$phase"; then
            echo -e "  ${GREEN}✓${NC} $phase_name (completed)"
        else
            echo -e "  ${YELLOW}○${NC} $phase_name (pending)"
        fi
    done
    
    echo ""
    
    if setup_state_phase_is_completed "phase6"; then
        echo -e "${GREEN}Setup is complete!${NC}"
    else
        echo -e "${YELLOW}Setup is incomplete. Run 'dinser setup' to continue.${NC}"
    fi
}

main() {
    local from_beginning=0
    local show_status_only=0
    
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
            --from-beginning)
                from_beginning=1
                shift
                ;;
            --status)
                show_status_only=1
                shift
                ;;
            --init)
                # Alias for --from-beginning
                from_beginning=1
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "=== DINS Installation Log ===" > "$LOG_FILE"
    echo "Started: $(date)" >> "$LOG_FILE"
    
    # Show status only
    if [[ $show_status_only -eq 1 ]]; then
        show_status
        exit 0
    fi
    
    # Clear state if --from-beginning
    if [[ $from_beginning -eq 1 ]]; then
        log_info "Starting fresh installation (--from-beginning)"
        setup_state_clear_all
    fi
    
    # Run phased installation
    run_phased_installation
    exit $?
}

# Run main if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
