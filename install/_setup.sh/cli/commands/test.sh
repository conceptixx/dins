#!/usr/bin/env bash
# =============================================================================
# dinser test - Run DINS test suite
# Location: /dins/install/_setup.sh/cli/commands/test.sh
# description: Run test suite for DINS components
# =============================================================================
# Implements PART 6.5.4: Testsuite integration with dinser
#
# Usage:
#   dinser test                    # Run all tests
#   dinser test --module cli       # Run specific module
#   dinser test --pre-deployment   # Pre-deployment validation
#   dinser test --help
# =============================================================================

# Find DINS root
DINS_ROOT="${DINS_ROOT:-$(dirname "$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")")}"
TESTSUITE_DIR="${DINS_ROOT}/testsuite"

# Colors
RED="${RED:-\033[0;31m}"
GREEN="${GREEN:-\033[0;32m}"
YELLOW="${YELLOW:-\033[1;33m}"
BLUE="${BLUE:-\033[0;34m}"
NC="${NC:-\033[0m}"

# =============================================================================
# COMMAND ENTRY POINT
# =============================================================================

cmd_test() {
    local args=("$@")
    
    # Check for help
    for arg in "${args[@]}"; do
        case "$arg" in
            --help|-h|help)
                cat << EOF
${BLUE}dinser test${NC} - Run DINS test suite

${YELLOW}Usage:${NC}
    dinser test [options]

${YELLOW}Options:${NC}
    --module, -m <name>   Run specific test module(s)
    --pre-deployment, -p  Run pre-deployment validation
    --continue-on-fail    Continue after failures
    --verbose, -v         Verbose output
    --list, -l            List available modules

${YELLOW}Examples:${NC}
    dinser test                         # Run all tests
    dinser test --module cli            # Run CLI tests only
    dinser test --module core webui     # Run multiple modules
    dinser test --pre-deployment        # Pre-deployment check
    dinser test --list                  # List modules

${YELLOW}Test Modules:${NC}
    core        Core system validation
    webui       WebUI component tests
    installer   Installer component tests
    cli         CLI tool tests
    web         Web endpoint tests

${YELLOW}Exit Codes:${NC}
    0   All tests passed
    1   One or more tests failed

EOF
                return 0
                ;;
        esac
    done
    
    # Check if testsuite exists
    if [[ ! -d "$TESTSUITE_DIR" ]]; then
        echo -e "${RED}[ERROR]${NC} Test suite directory not found: $TESTSUITE_DIR"
        return 1
    fi
    
    local testsuite_py="${TESTSUITE_DIR}/testsuite.py"
    
    if [[ ! -f "$testsuite_py" ]]; then
        echo -e "${RED}[ERROR]${NC} Test suite runner not found: $testsuite_py"
        return 1
    fi
    
    # Check for Python
    local python_cmd=""
    if command -v python3 &>/dev/null; then
        python_cmd="python3"
    elif command -v python &>/dev/null; then
        python_cmd="python"
    else
        echo -e "${RED}[ERROR]${NC} Python not found. Please install Python 3."
        return 1
    fi
    
    # Run the test suite
    echo -e "${GREEN}[INFO]${NC} Running DINS test suite..."
    echo ""
    
    cd "$TESTSUITE_DIR" || return 1
    "$python_cmd" testsuite.py "${args[@]}"
    local exit_code=$?
    
    return $exit_code
}
