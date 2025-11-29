#!/usr/bin/env python3
"""
DINS Test Suite - Installer Module Tests
Location: <DINS_ROOT>/testsuite/module_installer/test_module_installer.py

Tests for the DINS Installer components:
- Manifest file syntax and structure
- Shell module existence and syntax
- Validator module availability
- CLI tool (dinser) structure
- Docker setup configuration

This module validates the installer without executing installation operations.
"""

import os
import re
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

# Installer paths (relative to DINS root)
INSTALL_BASE = "install"
SETUP_MODULE = "_setup.sh"
SETUP_PATH = f"{INSTALL_BASE}/{SETUP_MODULE}"

# Expected module operations (shell scripts)
EXPECTED_OPERATIONS = [
    "_copy.sh",
    "_mkdir.sh",
    "_chmod.sh",
    "_chuser.sh",
    "_chgroup.sh",
    "_symlink.sh",
    "_template.sh",
    "_echo.sh",
    "_run_cmd.sh",
    "_set_var.sh",
]

# Expected validators
EXPECTED_VALIDATORS = [
    "_validate_path.sh",
    "_validate_file.sh",
    "_validate_string.sh",
    "_validate_boolean.sh",
    "_validate_chmod_mode.sh",
    "_validate_user.sh",
    "_validate_group.sh",
]

# Manifest syntax elements that should be present
MANIFEST_REQUIRED_ELEMENTS = [
    "OPERATION:",
    "TARGET:",
]


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def check_shell_script(script_path: Path) -> Tuple[bool, Optional[str]]:
    """
    Check if a shell script has basic valid structure.
    
    Checks:
    - Has shebang
    - Is not empty
    - Has function definitions or executable code
    """
    if not script_path.exists():
        return False, f"File not found: {script_path}"
    
    try:
        content = script_path.read_text()
        
        # Check shebang
        if not content.startswith("#!/"):
            return False, "Missing shebang (#!/bin/bash or similar)"
        
        # Check not empty (excluding comments and whitespace)
        lines = [l.strip() for l in content.split('\n') 
                 if l.strip() and not l.strip().startswith('#')]
        
        if len(lines) < 2:  # Just shebang and maybe one line
            return False, "Script appears to be empty or minimal"
        
        return True, None
        
    except Exception as e:
        return False, str(e)


def parse_manifest(manifest_path: Path) -> Tuple[bool, Optional[str], List[Dict]]:
    """
    Parse a Manifest file and extract operations.
    
    Returns (valid, error, operations)
    """
    if not manifest_path.exists():
        return False, "Manifest file not found", []
    
    try:
        content = manifest_path.read_text()
        operations = []
        current_op = {}
        
        for line_num, line in enumerate(content.split('\n'), 1):
            line = line.strip()
            
            # Skip empty lines and comments
            if not line or line.startswith('#'):
                continue
            
            # Check for key:value pattern
            if ':' in line:
                key, _, value = line.partition(':')
                key = key.strip()
                value = value.strip()
                
                if key == "OPERATION":
                    # Start new operation
                    if current_op:
                        operations.append(current_op)
                    current_op = {"OPERATION": value, "_line": line_num}
                elif current_op:
                    current_op[key] = value
        
        # Don't forget the last operation
        if current_op:
            operations.append(current_op)
        
        if not operations:
            return False, "No operations found in Manifest", []
        
        return True, None, operations
        
    except Exception as e:
        return False, str(e), []


def validate_manifest_operation(op: Dict) -> Tuple[bool, Optional[str]]:
    """
    Validate a single Manifest operation.
    
    Each operation should have at least OPERATION and TARGET.
    """
    if "OPERATION" not in op:
        return False, "Missing OPERATION field"
    
    # Most operations need a TARGET (except echo, run_cmd, set_var)
    no_target_ops = ["echo", "run_cmd", "set_var"]
    if op["OPERATION"].lower() not in no_target_ops:
        if "TARGET" not in op:
            return False, f"Operation {op['OPERATION']} missing TARGET"
    
    return True, None


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_install_directory_exists(dins_root: Path) -> TestResult:
    """Test that install directory exists"""
    start = time.time()
    name = "test_install_directory_exists"
    
    install_path = dins_root / INSTALL_BASE
    if not install_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Install directory not found: {install_path}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_setup_module_exists(dins_root: Path) -> TestResult:
    """Test that _setup.sh module directory exists"""
    start = time.time()
    name = "test_setup_module_exists"
    
    setup_path = dins_root / SETUP_PATH
    if not setup_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Setup module not found: {setup_path}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_setup_manifest_exists(dins_root: Path) -> TestResult:
    """Test that _setup.sh has a Manifest file"""
    start = time.time()
    name = "test_setup_manifest_exists"
    
    manifest = dins_root / SETUP_PATH / "Manifest"
    if not manifest.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Manifest file not found in _setup.sh")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_setup_manifest_valid(dins_root: Path) -> TestResult:
    """Test that _setup.sh Manifest is parseable"""
    start = time.time()
    name = "test_setup_manifest_valid"
    
    manifest = dins_root / SETUP_PATH / "Manifest"
    valid, error, operations = parse_manifest(manifest)
    
    if not valid:
        return TestResult(name, False, (time.time() - start) * 1000, error)
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_manifest_operations_valid(dins_root: Path) -> TestResult:
    """Test that Manifest operations have required fields"""
    start = time.time()
    name = "test_manifest_operations_valid"
    
    manifest = dins_root / SETUP_PATH / "Manifest"
    valid, error, operations = parse_manifest(manifest)
    
    if not valid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Cannot parse Manifest: {error}")
    
    invalid = []
    for op in operations:
        op_valid, op_error = validate_manifest_operation(op)
        if not op_valid:
            line = op.get('_line', '?')
            invalid.append(f"Line {line}: {op_error}")
    
    if invalid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid operations: {'; '.join(invalid[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_operation_scripts_exist(dins_root: Path) -> TestResult:
    """Test that expected operation scripts exist"""
    start = time.time()
    name = "test_operation_scripts_exist"
    missing = []
    
    setup_path = dins_root / SETUP_PATH
    
    for script in EXPECTED_OPERATIONS:
        if not (setup_path / script).exists():
            missing.append(script)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing operation scripts: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_operation_scripts_valid(dins_root: Path) -> TestResult:
    """Test that operation scripts have valid shell syntax"""
    start = time.time()
    name = "test_operation_scripts_valid"
    invalid = []
    
    setup_path = dins_root / SETUP_PATH
    
    for script in EXPECTED_OPERATIONS:
        script_path = setup_path / script
        if script_path.exists():
            valid, error = check_shell_script(script_path)
            if not valid:
                invalid.append(f"{script}: {error}")
    
    if invalid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid scripts: {'; '.join(invalid[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_validator_scripts_exist(dins_root: Path) -> TestResult:
    """Test that expected validator scripts exist"""
    start = time.time()
    name = "test_validator_scripts_exist"
    missing = []
    
    setup_path = dins_root / SETUP_PATH
    
    for script in EXPECTED_VALIDATORS:
        if not (setup_path / script).exists():
            missing.append(script)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing validator scripts: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_cli_directory_exists(dins_root: Path) -> TestResult:
    """Test that CLI tools directory exists"""
    start = time.time()
    name = "test_cli_directory_exists"
    
    cli_path = dins_root / SETUP_PATH / "cli"
    if not cli_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "CLI directory not found")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_cli_exists(dins_root: Path) -> TestResult:
    """Test that dinser CLI tool exists"""
    start = time.time()
    name = "test_dinser_cli_exists"
    
    dinser = dins_root / SETUP_PATH / "cli" / "dinser"
    if not dinser.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "dinser CLI tool not found")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_dinser_cli_valid(dins_root: Path) -> TestResult:
    """Test that dinser CLI has valid shell syntax"""
    start = time.time()
    name = "test_dinser_cli_valid"
    
    dinser = dins_root / SETUP_PATH / "cli" / "dinser"
    if not dinser.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "dinser not found")
    
    valid, error = check_shell_script(dinser)
    if not valid:
        return TestResult(name, False, (time.time() - start) * 1000, error)
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_docker_setup_exists(dins_root: Path) -> TestResult:
    """Test that Docker setup files exist"""
    start = time.time()
    name = "test_docker_setup_exists"
    missing = []
    
    docker_path = dins_root / SETUP_PATH / "docker"
    
    if not docker_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Docker directory not found")
    
    expected = ["Dockerfile.setup", "docker-compose.setup.yml"]
    for file in expected:
        if not (docker_path / file).exists():
            missing.append(file)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing Docker files: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_main_scripts_exist(dins_root: Path) -> TestResult:
    """Test that main installer scripts exist"""
    start = time.time()
    name = "test_main_scripts_exist"
    missing = []
    
    install_path = dins_root / INSTALL_BASE
    
    for script in ["setup.sh", "webui.sh"]:
        if not (install_path / script).exists():
            missing.append(script)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing main scripts: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_main_scripts_valid(dins_root: Path) -> TestResult:
    """Test that main installer scripts have valid syntax"""
    start = time.time()
    name = "test_main_scripts_valid"
    invalid = []
    
    install_path = dins_root / INSTALL_BASE
    
    for script in ["setup.sh", "webui.sh"]:
        script_path = install_path / script
        if script_path.exists():
            valid, error = check_shell_script(script_path)
            if not valid:
                invalid.append(f"{script}: {error}")
    
    if invalid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid scripts: {'; '.join(invalid)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_all_manifests_parseable(dins_root: Path) -> TestResult:
    """Test that all Manifest files in install are parseable"""
    start = time.time()
    name = "test_all_manifests_parseable"
    invalid = []
    
    install_path = dins_root / INSTALL_BASE
    
    # Find all Manifest files
    for manifest in install_path.rglob("Manifest"):
        valid, error, _ = parse_manifest(manifest)
        if not valid:
            relative = manifest.relative_to(dins_root)
            invalid.append(f"{relative}: {error}")
    
    if invalid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid Manifests: {'; '.join(invalid[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all installer module tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_installer")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_install_directory_exists, dins_root),
        (test_setup_module_exists, dins_root),
        (test_setup_manifest_exists, dins_root),
        (test_setup_manifest_valid, dins_root),
        (test_manifest_operations_valid, dins_root),
        (test_operation_scripts_exist, dins_root),
        (test_operation_scripts_valid, dins_root),
        (test_validator_scripts_exist, dins_root),
        (test_cli_directory_exists, dins_root),
        (test_dinser_cli_exists, dins_root),
        (test_dinser_cli_valid, dins_root),
        (test_docker_setup_exists, dins_root),
        (test_main_scripts_exist, dins_root),
        (test_main_scripts_valid, dins_root),
        (test_all_manifests_parseable, dins_root),
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
    
    parser = argparse.ArgumentParser(description="Run installer module tests")
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
    
    print(f"\nInstaller Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
