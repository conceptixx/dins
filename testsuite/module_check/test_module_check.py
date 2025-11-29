#!/usr/bin/env python3
"""
DINS Test Suite - Check Command Module Tests
Location: <DINS_ROOT>/testsuite/module_check/test_module_check.py

Tests for the `dinser check` troubleshooting command per PART 6.3 and PART 6.5.4.
Validates:
- Command availability and help output
- Diagnostic check execution
- Exit codes for success/failure scenarios
- Output format and content

This module can simulate failure conditions for testing.
"""

import os
import subprocess
import sys
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

DINSER_PATH = "install/_setup.sh/cli/dinser"
CHECK_TARGETS = ["web-ui", "webui", "dins-setup.local"]


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def run_dinser_check(
    dins_root: Path,
    target: str,
    timeout: int = 30
) -> Tuple[int, str, str]:
    """
    Run dinser check command.
    
    Returns (exit_code, stdout, stderr)
    """
    dinser = dins_root / DINSER_PATH
    
    try:
        result = subprocess.run(
            [str(dinser), "check", target],
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=str(dins_root)
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except FileNotFoundError:
        return -2, "", f"dinser not found: {dinser}"
    except Exception as e:
        return -3, "", str(e)


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_check_command_exists(dins_root: Path) -> TestResult:
    """Test that check command module exists"""
    start = time.time()
    name = "test_check_command_exists"
    
    check_module = dins_root / "install/_setup.sh/cli/commands/check.sh"
    
    if not check_module.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"check.sh not found: {check_module}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_help(dins_root: Path) -> TestResult:
    """Test that dinser check --help works"""
    start = time.time()
    name = "test_check_help"
    
    dinser = dins_root / DINSER_PATH
    
    try:
        result = subprocess.run(
            [str(dinser), "check", "--help"],
            capture_output=True,
            text=True,
            timeout=10
        )
        
        if result.returncode != 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Exit code {result.returncode}")
        
        combined = result.stdout + result.stderr
        
        # Check for expected content
        if "web-ui" not in combined.lower():
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Help output missing 'web-ui' target")
        
        if "usage" not in combined.lower():
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Help output missing 'usage' section")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_check_webui_runs(dins_root: Path) -> TestResult:
    """Test that dinser check web-ui executes without crashing"""
    start = time.time()
    name = "test_check_webui_runs"
    
    exit_code, stdout, stderr = run_dinser_check(dins_root, "web-ui")
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Command failed to run: {stderr}")
    
    # Command should produce output
    combined = stdout + stderr
    if not combined:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "No output produced")
    
    # Should contain diagnostic checks
    if "check" not in combined.lower() and "status" not in combined.lower():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Output doesn't appear to contain diagnostic info")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_produces_summary(dins_root: Path) -> TestResult:
    """Test that check command produces a summary"""
    start = time.time()
    name = "test_check_produces_summary"
    
    exit_code, stdout, stderr = run_dinser_check(dins_root, "web-ui")
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Command failed: {stderr}")
    
    combined = stdout + stderr
    
    # Should contain STATUS summary
    if "status:" not in combined.lower():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Output missing STATUS summary")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_unknown_target(dins_root: Path) -> TestResult:
    """Test that check command handles unknown target gracefully"""
    start = time.time()
    name = "test_check_unknown_target"
    
    exit_code, stdout, stderr = run_dinser_check(dins_root, "nonexistent-target-xyz")
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Command crashed: {stderr}")
    
    # Should return non-zero for unknown target
    if exit_code == 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Should return non-zero for unknown target")
    
    combined = stdout + stderr
    
    # Should provide helpful message
    if "unknown" not in combined.lower() and "error" not in combined.lower():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Missing error message for unknown target")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_targets_equivalent(dins_root: Path) -> TestResult:
    """Test that web-ui and dins-setup.local are equivalent"""
    start = time.time()
    name = "test_check_targets_equivalent"
    
    # Run both targets
    exit1, stdout1, stderr1 = run_dinser_check(dins_root, "web-ui")
    exit2, stdout2, stderr2 = run_dinser_check(dins_root, "dins-setup.local")
    
    if exit1 < 0 or exit2 < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "One or both commands failed to run")
    
    # Exit codes should match (both succeed or both fail based on environment)
    if exit1 != exit2:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Exit codes differ: web-ui={exit1}, dins-setup.local={exit2}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_exit_codes(dins_root: Path) -> TestResult:
    """Test that check command uses proper exit codes"""
    start = time.time()
    name = "test_check_exit_codes"
    
    exit_code, stdout, stderr = run_dinser_check(dins_root, "web-ui")
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Command failed: {stderr}")
    
    combined = stdout + stderr
    
    # Per PART 6.3.5: 0 = all passed, non-zero = failures
    # Check that exit code matches STATUS in output
    if "status: ok" in combined.lower():
        if exit_code != 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"STATUS OK but exit code is {exit_code}")
    elif "status: failed" in combined.lower():
        if exit_code == 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             "STATUS FAILED but exit code is 0")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_check_module_syntax(dins_root: Path) -> TestResult:
    """Test that check.sh has valid bash syntax"""
    start = time.time()
    name = "test_check_module_syntax"
    
    check_module = dins_root / "install/_setup.sh/cli/commands/check.sh"
    
    if not check_module.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "check.sh not found")
    
    try:
        result = subprocess.run(
            ["bash", "-n", str(check_module)],
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


def test_check_has_description(dins_root: Path) -> TestResult:
    """Test that check.sh has description comment for help"""
    start = time.time()
    name = "test_check_has_description"
    
    check_module = dins_root / "install/_setup.sh/cli/commands/check.sh"
    
    if not check_module.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "check.sh not found")
    
    try:
        content = check_module.read_text()
        
        if "# description:" not in content:
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Missing # description: comment")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all check command tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_check")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_check_command_exists, dins_root),
        (test_check_module_syntax, dins_root),
        (test_check_has_description, dins_root),
        (test_check_help, dins_root),
        (test_check_webui_runs, dins_root),
        (test_check_produces_summary, dins_root),
        (test_check_unknown_target, dins_root),
        (test_check_targets_equivalent, dins_root),
        (test_check_exit_codes, dins_root),
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
    
    parser = argparse.ArgumentParser(description="Run check command tests")
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
    
    print(f"\nCheck Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
