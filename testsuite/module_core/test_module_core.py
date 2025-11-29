#!/usr/bin/env python3
"""
DINS Test Suite - Core Module Tests
Location: <DINS_ROOT>/testsuite/module_core/test_module_core.py

Tests for core DINS system components:
- Directory structure validation
- Configuration file integrity
- Index file validation
- Critical file existence checks
- Environment setup validation

This module should always pass before other modules are run.
"""

import json
import os
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Tuple


# =============================================================================
# IMPORT TEST SUITE UTILITIES
# =============================================================================

# Add parent directory to path for imports
TESTSUITE_DIR = Path(__file__).parent.parent.resolve()
if str(TESTSUITE_DIR) not in sys.path:
    sys.path.insert(0, str(TESTSUITE_DIR))

from testsuite import ModuleResult, TestResult


# =============================================================================
# TEST CONFIGURATION
# =============================================================================

# Expected directory structure
EXPECTED_DIRS = [
    "install",
    "install/_setup.sh",
    "install/_webui.sh",
    "docs",
    "testsuite"
]

# Required files at DINS root
REQUIRED_ROOT_FILES = [
    "README.md",
    ".index"
]

# Required files in install directory
REQUIRED_INSTALL_FILES = [
    "setup.sh",
    "webui.sh",
    ".index"
]


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def validate_index_file(index_path: Path) -> Tuple[bool, Optional[str]]:
    """
    Validate an .index file structure.
    
    Index files should have:
    - META section with directory_path
    - Proper formatting
    
    Returns (valid, error_message)
    """
    if not index_path.exists():
        return False, f"Index file not found: {index_path}"
    
    try:
        content = index_path.read_text()
        
        # Check for META section
        if "### META" not in content:
            return False, "Missing ### META section"
        
        # Check for directory_path
        if "directory_path:" not in content:
            return False, "Missing directory_path in META section"
        
        return True, None
        
    except Exception as e:
        return False, f"Error reading index file: {e}"


def validate_json_file(json_path: Path) -> Tuple[bool, Optional[str]]:
    """
    Validate a JSON file for syntax correctness.
    
    Returns (valid, error_message)
    """
    if not json_path.exists():
        return False, f"JSON file not found: {json_path}"
    
    try:
        with open(json_path, 'r') as f:
            json.load(f)
        return True, None
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, f"Error reading file: {e}"


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_dins_root_exists(dins_root: Path) -> TestResult:
    """Test that DINS root directory exists and is accessible"""
    start = time.time()
    name = "test_dins_root_exists"
    
    try:
        if not dins_root.exists():
            return TestResult(name, False, (time.time() - start) * 1000, 
                            f"DINS root not found: {dins_root}")
        
        if not dins_root.is_dir():
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"DINS root is not a directory: {dins_root}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_directory_structure(dins_root: Path) -> TestResult:
    """Test that expected directory structure exists"""
    start = time.time()
    name = "test_directory_structure"
    missing = []
    
    try:
        for dir_path in EXPECTED_DIRS:
            full_path = dins_root / dir_path
            if not full_path.exists() or not full_path.is_dir():
                missing.append(dir_path)
        
        if missing:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Missing directories: {', '.join(missing)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_root_files(dins_root: Path) -> TestResult:
    """Test that required root files exist"""
    start = time.time()
    name = "test_root_files"
    missing = []
    
    try:
        for file_name in REQUIRED_ROOT_FILES:
            file_path = dins_root / file_name
            if not file_path.exists() or not file_path.is_file():
                missing.append(file_name)
        
        if missing:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Missing files: {', '.join(missing)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_install_files(dins_root: Path) -> TestResult:
    """Test that required install files exist"""
    start = time.time()
    name = "test_install_files"
    missing = []
    
    try:
        install_dir = dins_root / "install"
        
        for file_name in REQUIRED_INSTALL_FILES:
            file_path = install_dir / file_name
            if not file_path.exists():
                missing.append(file_name)
        
        if missing:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Missing install files: {', '.join(missing)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_root_index_valid(dins_root: Path) -> TestResult:
    """Test that root .index file is valid"""
    start = time.time()
    name = "test_root_index_valid"
    
    try:
        index_path = dins_root / ".index"
        valid, error = validate_index_file(index_path)
        
        if not valid:
            return TestResult(name, False, (time.time() - start) * 1000, error)
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_all_index_files(dins_root: Path) -> TestResult:
    """Test that all .index files in the project are valid"""
    start = time.time()
    name = "test_all_index_files"
    invalid = []
    
    try:
        # Find all .index files
        for index_file in dins_root.rglob(".index"):
            # Skip any in hidden directories
            if any(part.startswith('.') and part != '.index' 
                   for part in index_file.parts):
                continue
            
            valid, error = validate_index_file(index_file)
            if not valid:
                relative_path = index_file.relative_to(dins_root)
                invalid.append(f"{relative_path}: {error}")
        
        if invalid:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Invalid index files: {'; '.join(invalid[:5])}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_section_json_files(dins_root: Path) -> TestResult:
    """Test that all section.json files are valid JSON"""
    start = time.time()
    name = "test_section_json_files"
    invalid = []
    
    try:
        sections_dir = dins_root / "install" / "_webui.sh" / "backend" / "sections"
        
        if not sections_dir.exists():
            return TestResult(name, False, (time.time() - start) * 1000,
                            "Sections directory not found")
        
        for section_json in sections_dir.rglob("section.json"):
            valid, error = validate_json_file(section_json)
            if not valid:
                relative_path = section_json.relative_to(dins_root)
                invalid.append(f"{relative_path}: {error}")
        
        if invalid:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Invalid section.json files: {'; '.join(invalid[:3])}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_manifest_files_exist(dins_root: Path) -> TestResult:
    """Test that Manifest files exist in module directories"""
    start = time.time()
    name = "test_manifest_files_exist"
    missing = []
    
    try:
        install_dir = dins_root / "install"
        
        # Check for Manifest in directories starting with _
        for item in install_dir.iterdir():
            if item.is_dir() and item.name.startswith("_") and item.name.endswith(".sh"):
                manifest = item / "Manifest"
                if not manifest.exists():
                    missing.append(item.name)
        
        if missing:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Missing Manifests in: {', '.join(missing)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_shell_scripts_syntax(dins_root: Path) -> TestResult:
    """Test that critical shell scripts have valid syntax (shebang check)"""
    start = time.time()
    name = "test_shell_scripts_syntax"
    issues = []
    
    try:
        # Critical shell scripts to check
        scripts = [
            dins_root / "install" / "setup.sh",
            dins_root / "install" / "webui.sh",
        ]
        
        for script in scripts:
            if not script.exists():
                continue
                
            content = script.read_text()
            
            # Check for shebang
            if not content.startswith("#!/"):
                issues.append(f"{script.name}: missing shebang")
        
        if issues:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Script issues: {'; '.join(issues)}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_python_files_syntax(dins_root: Path) -> TestResult:
    """Test that critical Python files can be parsed"""
    start = time.time()
    name = "test_python_files_syntax"
    issues = []
    
    try:
        # Critical Python files to check
        backend_dir = dins_root / "install" / "_webui.sh" / "backend"
        
        if backend_dir.exists():
            for py_file in backend_dir.rglob("*.py"):
                try:
                    # Use compile to check syntax without executing
                    compile(py_file.read_text(), py_file, 'exec')
                except SyntaxError as e:
                    relative_path = py_file.relative_to(dins_root)
                    issues.append(f"{relative_path}: {e.msg} at line {e.lineno}")
        
        if issues:
            return TestResult(name, False, (time.time() - start) * 1000,
                            f"Python syntax errors: {'; '.join(issues[:3])}")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all core module tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_core")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_dins_root_exists, dins_root),
        (test_directory_structure, dins_root),
        (test_root_files, dins_root),
        (test_install_files, dins_root),
        (test_root_index_valid, dins_root),
        (test_all_index_files, dins_root),
        (test_section_json_files, dins_root),
        (test_manifest_files_exist, dins_root),
        (test_shell_scripts_syntax, dins_root),
        (test_python_files_syntax, dins_root),
    ]
    
    # Run each test
    for test_func, arg in tests:
        test_result = test_func(arg)
        result.add_result(test_result)
        
        # Print progress if verbose
        if config.get("verbose"):
            status = "✓" if test_result.passed else "✗"
            print(f"  {status} {test_result.name}")
    
    return result


# =============================================================================
# STANDALONE EXECUTION
# =============================================================================

if __name__ == "__main__":
    # Allow running this module directly for debugging
    import argparse
    
    parser = argparse.ArgumentParser(description="Run core module tests")
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
    
    print(f"\nCore Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
