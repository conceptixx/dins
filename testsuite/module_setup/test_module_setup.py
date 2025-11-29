#!/usr/bin/env python3
"""
DINS Test Suite - Setup State Module Tests
Location: <DINS_ROOT>/testsuite/module_setup/test_module_setup.py

Tests for the setup state management per PART 6.1:
- State file mechanics
- Phase tracking
- MOTD handling
- State library functions

This module validates state management without running actual setup.
"""

import os
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


# =============================================================================
# IMPORT TEST SUITE UTILITIES
# =============================================================================

TESTSUITE_DIR = Path(__file__).parent.parent.resolve()
if str(TESTSUITE_DIR) not in sys.path:
    sys.path.insert(0, str(TESTSUITE_DIR))

from testsuite import ModuleResult, TestResult


# =============================================================================
# TEST CONFIGURATION
# =============================================================================

STATE_LIB_PATH = "install/_setup.sh/lib/state.sh"


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def run_bash_function(
    dins_root: Path,
    function_call: str,
    env_vars: Dict[str, str] = None,
    timeout: int = 10
) -> Tuple[int, str, str]:
    """
    Run a bash function from state.sh and capture output.
    
    Returns (exit_code, stdout, stderr)
    """
    state_lib = dins_root / STATE_LIB_PATH
    
    if not state_lib.exists():
        return -1, "", f"state.sh not found: {state_lib}"
    
    # Create a temporary state directory for testing
    with tempfile.TemporaryDirectory() as tmpdir:
        script = f"""
        set -e
        export STATE_DIR="{tmpdir}"
        export STATE_FILE="{tmpdir}/setup_state"
        source "{state_lib}"
        {function_call}
        """
        
        env = os.environ.copy()
        if env_vars:
            env.update(env_vars)
        
        try:
            result = subprocess.run(
                ["bash", "-c", script],
                capture_output=True,
                text=True,
                timeout=timeout,
                env=env
            )
            return result.returncode, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            return -2, "", "Command timed out"
        except Exception as e:
            return -3, "", str(e)


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_state_lib_exists(dins_root: Path) -> TestResult:
    """Test that state library exists"""
    start = time.time()
    name = "test_state_lib_exists"
    
    state_lib = dins_root / STATE_LIB_PATH
    
    if not state_lib.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"state.sh not found: {state_lib}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_state_lib_syntax(dins_root: Path) -> TestResult:
    """Test that state.sh has valid bash syntax"""
    start = time.time()
    name = "test_state_lib_syntax"
    
    state_lib = dins_root / STATE_LIB_PATH
    
    if not state_lib.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "state.sh not found")
    
    try:
        result = subprocess.run(
            ["bash", "-n", str(state_lib)],
            capture_output=True,
            text=True,
            timeout=5
        )
        
        if result.returncode != 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Syntax error: {result.stderr}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_state_set_get(dins_root: Path) -> TestResult:
    """Test setup_state_set and setup_state_get functions"""
    start = time.time()
    name = "test_state_set_get"
    
    # Test setting and getting state
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        setup_state_set "phase1" "test_step" "completed"
        result=$(setup_state_get "phase1" "test_step")
        echo "RESULT=$result"
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "RESULT=completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Expected RESULT=completed, got: {stdout}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_state_is_completed(dins_root: Path) -> TestResult:
    """Test setup_state_is_completed function"""
    start = time.time()
    name = "test_state_is_completed"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        setup_state_set "phase1" "step1" "completed"
        setup_state_set "phase1" "step2" "start"
        
        if setup_state_is_completed "phase1" "step1"; then
            echo "STEP1=completed"
        else
            echo "STEP1=not_completed"
        fi
        
        if setup_state_is_completed "phase1" "step2"; then
            echo "STEP2=completed"
        else
            echo "STEP2=not_completed"
        fi
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "STEP1=completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "step1 should be completed")
    
    if "STEP2=not_completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "step2 should not be completed")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_state_phase_completed(dins_root: Path) -> TestResult:
    """Test setup_state_phase_is_completed function"""
    start = time.time()
    name = "test_state_phase_completed"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        # Set all steps in phase1 as completed
        setup_state_set "phase1" "step1" "completed"
        setup_state_set "phase1" "step2" "completed"
        
        # Set phase2 with incomplete step
        setup_state_set "phase2" "step1" "completed"
        setup_state_set "phase2" "step2" "start"
        
        if setup_state_phase_is_completed "phase1"; then
            echo "PHASE1=completed"
        else
            echo "PHASE1=not_completed"
        fi
        
        if setup_state_phase_is_completed "phase2"; then
            echo "PHASE2=completed"
        else
            echo "PHASE2=not_completed"
        fi
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "PHASE1=completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "phase1 should be completed")
    
    if "PHASE2=not_completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "phase2 should not be completed")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_state_clear_all(dins_root: Path) -> TestResult:
    """Test setup_state_clear_all function"""
    start = time.time()
    name = "test_state_clear_all"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        setup_state_set "phase1" "step1" "completed"
        setup_state_clear_all
        
        result=$(setup_state_get "phase1" "step1")
        if [[ -z "$result" ]]; then
            echo "CLEARED=yes"
        else
            echo "CLEARED=no"
        fi
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "CLEARED=yes" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "State should be cleared")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_state_file_format(dins_root: Path) -> TestResult:
    """Test that state file follows expected format"""
    start = time.time()
    name = "test_state_file_format"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        setup_state_set "phase1" "install_packages" "completed"
        setup_state_set "phase2" "install_cli" "start"
        setup_state_set "phase3" "configure_network" "warning"
        
        cat "$STATE_FILE"
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    # Check format: phaseN:step_id:status
    expected_patterns = [
        "phase1:install_packages:completed",
        "phase2:install_cli:start",
        "phase3:configure_network:warning"
    ]
    
    for pattern in expected_patterns:
        if pattern not in stdout:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Missing expected entry: {pattern}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_run_step_helper(dins_root: Path) -> TestResult:
    """Test run_step helper function"""
    start = time.time()
    name = "test_run_step_helper"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        # Test run_step with successful command
        run_step "phase1" "test_success" "Test successful step" true
        
        # Check the state
        result=$(setup_state_get "phase1" "test_success")
        echo "RESULT=$result"
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "RESULT=completed" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Step should be marked completed")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_skip_step_helper(dins_root: Path) -> TestResult:
    """Test skip_step helper function"""
    start = time.time()
    name = "test_skip_step_helper"
    
    exit_code, stdout, stderr = run_bash_function(dins_root, """
        skip_step "phase1" "optional_step" "Not needed"
        
        result=$(setup_state_get "phase1" "optional_step")
        echo "RESULT=$result"
    """)
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Function failed: {stderr}")
    
    if "RESULT=skipped" not in stdout:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Step should be marked skipped")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_functions_defined(dins_root: Path) -> TestResult:
    """Test that all required functions are defined"""
    start = time.time()
    name = "test_functions_defined"
    
    required_functions = [
        "setup_state_init",
        "setup_state_set",
        "setup_state_get",
        "setup_state_is_completed",
        "setup_state_phase_is_completed",
        "setup_state_get_last_completed_phase",
        "setup_state_clear_all",
        "setup_state_is_fully_completed",
        "motd_add_reminder",
        "motd_remove_reminder",
        "run_step",
        "skip_step"
    ]
    
    state_lib = dins_root / STATE_LIB_PATH
    
    try:
        content = state_lib.read_text()
        
        missing = []
        for func in required_functions:
            if f"{func}()" not in content:
                missing.append(func)
        
        if missing:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Missing functions: {', '.join(missing)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all setup state tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_setup")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_state_lib_exists, dins_root),
        (test_state_lib_syntax, dins_root),
        (test_functions_defined, dins_root),
        (test_state_set_get, dins_root),
        (test_state_is_completed, dins_root),
        (test_state_phase_completed, dins_root),
        (test_state_clear_all, dins_root),
        (test_state_file_format, dins_root),
        (test_run_step_helper, dins_root),
        (test_skip_step_helper, dins_root),
    ]
    
    # Run each test
    for test_func, arg in tests:
        test_result = test_func(arg)
        result.add_result(test_result)
        
        if config.get("verbose"):
            status = "✓" if test_result.passed else "✗"
            print(f"  {status} {test_result.name}")
    
    return result


# =============================================================================
# STANDALONE EXECUTION
# =============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Run setup state tests")
    parser.add_argument("--dins-root", type=str,
                       default=str(Path(__file__).parent.parent.parent),
                       help="DINS root directory")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Verbose output")
    
    args = parser.parse_args()
    
    config = {
        "dins_root": args.dins_root,
        "verbose": args.verbose
    }
    
    result = run_tests(config)
    
    print(f"\nSetup State Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
