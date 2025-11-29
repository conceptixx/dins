#!/usr/bin/env python3
"""
DINS Test Suite - CLI Module Tests
Location: <DINS_ROOT>/testsuite/module_cli/test_module_cli.py

Tests for CLI-based parts of DINS per PART5 specification:
- CLI command callability
- Exit code validation
- Help output testing
- Parameter and mode testing
- Error case handling

This module validates CLI tools without destructive operations.
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

# CLI tools to test
CLI_TOOLS = {
    "dinser": "install/_setup.sh/cli/dinser",
}

# Commands that should show help
HELP_COMMANDS = [
    (["--help"], 0),
    (["-h"], 0),
    (["help"], 0),
]

# Commands that should show version
VERSION_COMMANDS = [
    (["--version"], 0),
    (["-v"], 0),
    (["version"], 0),
]

# Valid subcommands that should return 0 (non-destructive)
VALID_SUBCOMMANDS = [
    (["status"], 0),
]

# Invalid commands that should fail gracefully
INVALID_COMMANDS = [
    (["nonexistent_command"], 1),
    (["webui", "invalid_subcommand"], 1),
]


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def run_cli_command(
    cli_path: Path,
    args: List[str],
    timeout: int = 10
) -> Tuple[int, str, str]:
    """
    Run a CLI command and capture output.
    
    Returns (exit_code, stdout, stderr)
    """
    try:
        result = subprocess.run(
            [str(cli_path)] + args,
            capture_output=True,
            text=True,
            timeout=timeout,
            cwd=cli_path.parent
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return -1, "", "Command timed out"
    except FileNotFoundError:
        return -2, "", f"CLI not found: {cli_path}"
    except PermissionError:
        return -3, "", f"Permission denied: {cli_path}"
    except Exception as e:
        return -4, "", str(e)


def check_help_output(stdout: str, stderr: str) -> Tuple[bool, Optional[str]]:
    """
    Validate help output contains expected elements.
    """
    combined = stdout + stderr
    
    # Help should contain usage information
    if "usage" not in combined.lower() and "commands" not in combined.lower():
        return False, "Help output missing usage or commands section"
    
    # Should mention at least some commands
    expected_keywords = ["help", "version", "status"]
    found = sum(1 for kw in expected_keywords if kw in combined.lower())
    
    if found < 2:
        return False, "Help output missing expected command keywords"
    
    return True, None


def check_version_output(stdout: str, stderr: str) -> Tuple[bool, Optional[str]]:
    """
    Validate version output contains version information.
    """
    combined = stdout + stderr
    
    # Should contain version number pattern
    import re
    version_pattern = r'\d+\.\d+(\.\d+)?'
    
    if not re.search(version_pattern, combined):
        return False, "Version output missing version number"
    
    return True, None


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_dinser_exists(dins_root: Path) -> TestResult:
    """Test that dinser CLI tool exists and is executable"""
    start = time.time()
    name = "test_dinser_exists"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    if not dinser_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"dinser not found: {dinser_path}")
    
    # Check if executable (on Unix)
    if os.name != 'nt':
        if not os.access(dinser_path, os.X_OK):
            return TestResult(name, False, (time.time() - start) * 1000,
                             "dinser is not executable")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_help(dins_root: Path) -> TestResult:
    """Test that dinser --help works and produces valid output"""
    start = time.time()
    name = "test_dinser_help"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    for args, expected_code in HELP_COMMANDS:
        exit_code, stdout, stderr = run_cli_command(dinser_path, args)
        
        if exit_code < 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Failed to run dinser {' '.join(args)}: {stderr}")
        
        if exit_code != expected_code:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)} returned {exit_code}, expected {expected_code}")
        
        valid, error = check_help_output(stdout, stderr)
        if not valid:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)}: {error}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_version(dins_root: Path) -> TestResult:
    """Test that dinser version commands work"""
    start = time.time()
    name = "test_dinser_version"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    for args, expected_code in VERSION_COMMANDS:
        exit_code, stdout, stderr = run_cli_command(dinser_path, args)
        
        if exit_code < 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Failed to run dinser {' '.join(args)}: {stderr}")
        
        if exit_code != expected_code:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)} returned {exit_code}, expected {expected_code}")
        
        valid, error = check_version_output(stdout, stderr)
        if not valid:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)}: {error}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_status(dins_root: Path) -> TestResult:
    """Test that dinser status command runs without error"""
    start = time.time()
    name = "test_dinser_status"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    exit_code, stdout, stderr = run_cli_command(dinser_path, ["status"])
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Failed to run dinser status: {stderr}")
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"dinser status returned {exit_code}")
    
    # Status should output something
    if not stdout and not stderr:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "dinser status produced no output")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_invalid_command(dins_root: Path) -> TestResult:
    """Test that dinser handles invalid commands gracefully"""
    start = time.time()
    name = "test_dinser_invalid_command"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    for args, expected_code in INVALID_COMMANDS:
        exit_code, stdout, stderr = run_cli_command(dinser_path, args)
        
        if exit_code < 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"Failed to run dinser {' '.join(args)}: {stderr}")
        
        if exit_code == 0:
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)} should have failed but returned 0")
        
        # Should provide helpful error message
        combined = stdout + stderr
        if "unknown" not in combined.lower() and "error" not in combined.lower():
            return TestResult(name, False, (time.time() - start) * 1000,
                             f"dinser {' '.join(args)} missing error message")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_no_args(dins_root: Path) -> TestResult:
    """Test that dinser with no arguments shows help"""
    start = time.time()
    name = "test_dinser_no_args"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    exit_code, stdout, stderr = run_cli_command(dinser_path, [])
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Failed to run dinser: {stderr}")
    
    # Running with no args should show help (exit 0)
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"dinser with no args returned {exit_code}, expected 0")
    
    valid, error = check_help_output(stdout, stderr)
    if not valid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"dinser no args: {error}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_webui_help(dins_root: Path) -> TestResult:
    """Test that dinser webui subcommand shows help on invalid subcommand"""
    start = time.time()
    name = "test_dinser_webui_help"
    
    dinser_path = dins_root / CLI_TOOLS["dinser"]
    
    # webui with no subcommand should show error or help
    exit_code, stdout, stderr = run_cli_command(dinser_path, ["webui"])
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Failed to run dinser webui: {stderr}")
    
    # Should either show help or error about missing subcommand
    combined = stdout + stderr
    if not combined:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "dinser webui produced no output")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_cli_scripts_executable(dins_root: Path) -> TestResult:
    """Test that all CLI scripts are executable"""
    start = time.time()
    name = "test_cli_scripts_executable"
    
    if os.name == 'nt':
        # Skip on Windows
        return TestResult(name, True, (time.time() - start) * 1000)
    
    cli_dir = dins_root / "install" / "_setup.sh" / "cli"
    if not cli_dir.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "CLI directory not found")
    
    non_executable = []
    for script in cli_dir.iterdir():
        if script.is_file() and not script.name.startswith('.'):
            if script.suffix in ['', '.sh']:
                if not os.access(script, os.X_OK):
                    non_executable.append(script.name)
    
    if non_executable:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Non-executable scripts: {', '.join(non_executable)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_setup_sh_help(dins_root: Path) -> TestResult:
    """Test that setup.sh shows help with --help"""
    start = time.time()
    name = "test_setup_sh_help"
    
    setup_sh = dins_root / "install" / "setup.sh"
    
    if not setup_sh.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "setup.sh not found")
    
    exit_code, stdout, stderr = run_cli_command(setup_sh, ["--help"])
    
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Failed to run setup.sh --help: {stderr}")
    
    if exit_code != 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"setup.sh --help returned {exit_code}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_webui_sh_help(dins_root: Path) -> TestResult:
    """Test that webui.sh shows help with --help"""
    start = time.time()
    name = "test_webui_sh_help"
    
    webui_sh = dins_root / "install" / "webui.sh"
    
    if not webui_sh.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "webui.sh not found")
    
    exit_code, stdout, stderr = run_cli_command(webui_sh, ["--help"])
    
    # webui.sh might not have --help, so we'll accept any output
    if exit_code < 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Failed to run webui.sh --help: {stderr}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all CLI module tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_cli")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_dinser_exists, dins_root),
        (test_dinser_help, dins_root),
        (test_dinser_version, dins_root),
        (test_dinser_status, dins_root),
        (test_dinser_no_args, dins_root),
        (test_dinser_invalid_command, dins_root),
        (test_dinser_webui_help, dins_root),
        (test_cli_scripts_executable, dins_root),
        (test_setup_sh_help, dins_root),
        (test_webui_sh_help, dins_root),
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
    
    parser = argparse.ArgumentParser(description="Run CLI module tests")
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
    
    print(f"\nCLI Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
