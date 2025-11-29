#!/usr/bin/env bash
# =============================================================================
# DINS Setup State Management Library
# Location: /dins/install/_setup.sh/lib/state.sh
# =============================================================================
# Implements PART 6.1.3: State file mechanics for phases and steps
#
# State file location: /var/lib/dins/setup_state (production)
# Fallback location: $SCRIPT_DIR/../state/setup_state (development)
#
# Format: phaseN:step_id:status
# Status values: start, completed, warning, skipped, not_assigned
# =============================================================================

# State file location
STATE_DIR="${STATE_DIR:-/var/lib/dins}"
STATE_FILE="${STATE_FILE:-${STATE_DIR}/setup_state}"

# Fallback for development/non-root
if [[ ! -d "$STATE_DIR" ]] && [[ $EUID -ne 0 ]]; then
    STATE_DIR="${SCRIPT_DIR:-$(dirname "$0")}/../state"
    STATE_FILE="${STATE_DIR}/setup_state"
fi

# =============================================================================
# STATE FILE FUNCTIONS
# =============================================================================

# Initialize state directory and file if needed
setup_state_init() {
    if [[ ! -d "$STATE_DIR" ]]; then
        mkdir -p "$STATE_DIR" 2>/dev/null || sudo mkdir -p "$STATE_DIR"
    fi
    
    if [[ ! -f "$STATE_FILE" ]]; then
        touch "$STATE_FILE" 2>/dev/null || sudo touch "$STATE_FILE"
        echo "# DINS Setup State File" >> "$STATE_FILE"
        echo "# Created: $(date -Iseconds)" >> "$STATE_FILE"
    fi
}

# Set state for a phase:step
# Usage: setup_state_set <phase> <step_id> <status>
# Example: setup_state_set "phase1" "install_packages" "completed"
setup_state_set() {
    local phase="$1"
    local step_id="$2"
    local status="$3"
    
    setup_state_init
    
    local entry="${phase}:${step_id}:${status}"
    local pattern="^${phase}:${step_id}:"
    
    # Remove existing entry for this phase:step
    if grep -q "$pattern" "$STATE_FILE" 2>/dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        grep -v "$pattern" "$STATE_FILE" > "$tmp_file"
        mv "$tmp_file" "$STATE_FILE" 2>/dev/null || sudo mv "$tmp_file" "$STATE_FILE"
    fi
    
    # Append new entry
    echo "$entry" >> "$STATE_FILE" 2>/dev/null || echo "$entry" | sudo tee -a "$STATE_FILE" > /dev/null
    
    # Log the state change
    log_debug "State: $entry" 2>/dev/null || true
}

# Get state for a phase:step
# Usage: setup_state_get <phase> <step_id>
# Returns: status string or empty if not found
setup_state_get() {
    local phase="$1"
    local step_id="$2"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        echo ""
        return 1
    fi
    
    local pattern="^${phase}:${step_id}:"
    local line
    line=$(grep "$pattern" "$STATE_FILE" 2>/dev/null | tail -1)
    
    if [[ -n "$line" ]]; then
        echo "${line##*:}"
        return 0
    fi
    
    echo ""
    return 1
}

# Check if a step is completed
# Usage: setup_state_is_completed <phase> <step_id>
# Returns: 0 if completed, 1 otherwise
setup_state_is_completed() {
    local phase="$1"
    local step_id="$2"
    
    local status
    status=$(setup_state_get "$phase" "$step_id")
    
    [[ "$status" == "completed" ]]
}

# Check if entire phase is completed
# Usage: setup_state_phase_is_completed <phase>
# Returns: 0 if all steps in phase are completed, 1 otherwise
setup_state_phase_is_completed() {
    local phase="$1"
    
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi
    
    # Check if phase has any non-completed entries
    local pattern="^${phase}:"
    local incomplete
    incomplete=$(grep "$pattern" "$STATE_FILE" 2>/dev/null | grep -v ":completed$" | grep -v ":skipped$" | head -1)
    
    # If no entries at all, phase not started
    if ! grep -q "$pattern" "$STATE_FILE" 2>/dev/null; then
        return 1
    fi
    
    # If any incomplete, return false
    [[ -z "$incomplete" ]]
}

# Get the last completed phase number
# Usage: setup_state_get_last_completed_phase
# Returns: phase number (1-6) or 0 if none completed
setup_state_get_last_completed_phase() {
    local last_phase=0
    
    for i in {1..6}; do
        if setup_state_phase_is_completed "phase${i}"; then
            last_phase=$i
        else
            break
        fi
    done
    
    echo "$last_phase"
}

# Clear all state (for --from-beginning)
# Usage: setup_state_clear_all
setup_state_clear_all() {
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE" 2>/dev/null || sudo rm -f "$STATE_FILE"
        echo "Setup state cleared" >&2
    fi
}

# Check if setup is fully completed
# Usage: setup_state_is_fully_completed
# Returns: 0 if phase6 final step is completed
setup_state_is_fully_completed() {
    local status
    status=$(setup_state_get "phase6" "final_cleanup")
    [[ "$status" == "completed" ]]
}

# =============================================================================
# MOTD MANAGEMENT (Raspberry Pi specific)
# =============================================================================

MOTD_FILE="/etc/motd"
MOTD_BACKUP="/etc/motd.dins-backup"
DINS_MOTD_MARKER="### DINS SETUP ###"

# Add DINS reminder to MOTD
# Note: This is Raspberry-Pi-specific and may differ on other Linux distributions
motd_add_reminder() {
    # Skip if not root
    if [[ $EUID -ne 0 ]]; then
        echo "MOTD: Skipping (not root)" >&2
        return 0
    fi
    
    # Backup original MOTD if not already done
    if [[ -f "$MOTD_FILE" ]] && [[ ! -f "$MOTD_BACKUP" ]]; then
        cp "$MOTD_FILE" "$MOTD_BACKUP"
        echo "MOTD: Backed up original to $MOTD_BACKUP" >&2
    fi
    
    # Check if already has DINS marker
    if grep -q "$DINS_MOTD_MARKER" "$MOTD_FILE" 2>/dev/null; then
        echo "MOTD: DINS reminder already present" >&2
        return 0
    fi
    
    # Append DINS reminder
    cat >> "$MOTD_FILE" << EOF

$DINS_MOTD_MARKER
╔════════════════════════════════════════════════════════════════╗
║  DINS setup is not finished. To resume, run:                   ║
║                                                                ║
║      dinser setup                                              ║
║                                                                ║
║  For troubleshooting: dinser check web-ui                      ║
╚════════════════════════════════════════════════════════════════╝
$DINS_MOTD_MARKER
EOF
    
    echo "MOTD: Added setup reminder" >&2
}

# Remove DINS reminder from MOTD
motd_remove_reminder() {
    # Skip if not root
    if [[ $EUID -ne 0 ]]; then
        echo "MOTD: Skipping removal (not root)" >&2
        return 0
    fi
    
    # If backup exists, restore it
    if [[ -f "$MOTD_BACKUP" ]]; then
        mv "$MOTD_BACKUP" "$MOTD_FILE"
        echo "MOTD: Restored original from backup" >&2
        return 0
    fi
    
    # Otherwise, try to remove the DINS section
    if [[ -f "$MOTD_FILE" ]] && grep -q "$DINS_MOTD_MARKER" "$MOTD_FILE" 2>/dev/null; then
        local tmp_file
        tmp_file=$(mktemp)
        # Remove everything between DINS markers
        sed "/$DINS_MOTD_MARKER/,/$DINS_MOTD_MARKER/d" "$MOTD_FILE" > "$tmp_file"
        mv "$tmp_file" "$MOTD_FILE"
        echo "MOTD: Removed DINS reminder" >&2
    fi
}

# =============================================================================
# PHASE EXECUTION HELPERS
# =============================================================================

# Execute a step with state tracking
# Usage: run_step <phase> <step_id> <description> <command...>
run_step() {
    local phase="$1"
    local step_id="$2"
    local description="$3"
    shift 3
    
    # Check if already completed
    if setup_state_is_completed "$phase" "$step_id"; then
        echo "[$phase] Skipping (already completed): $description" >&2
        return 0
    fi
    
    # Mark as started
    setup_state_set "$phase" "$step_id" "start"
    echo "[$phase] Starting: $description" >&2
    
    # Execute the command
    if "$@"; then
        setup_state_set "$phase" "$step_id" "completed"
        echo "[$phase] Completed: $description" >&2
        return 0
    else
        local exit_code=$?
        setup_state_set "$phase" "$step_id" "warning"
        echo "[$phase] Warning (exit $exit_code): $description" >&2
        return $exit_code
    fi
}

# Skip a step (mark as skipped)
# Usage: skip_step <phase> <step_id> <reason>
skip_step() {
    local phase="$1"
    local step_id="$2"
    local reason="$3"
    
    setup_state_set "$phase" "$step_id" "skipped"
    echo "[$phase] Skipped: $reason" >&2
}
