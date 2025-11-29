#!/usr/bin/env python3
"""
DINS Test Suite - WebUI Module Tests
Location: <DINS_ROOT>/testsuite/module_webui/test_module_webui.py

Tests for the DINS WebUI components:
- Backend API structure and configuration
- Frontend asset integrity
- Section discovery and loading
- Docker configuration validity
- API endpoint availability (when running)

This module validates the WebUI without requiring a running server.
"""

import json
import os
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

# WebUI base paths (relative to DINS root)
WEBUI_BASE = "install/_webui.sh"
BACKEND_PATH = f"{WEBUI_BASE}/backend"
FRONTEND_PATH = f"{WEBUI_BASE}/frontend"
DOCKER_PATH = f"{WEBUI_BASE}/docker"

# Required backend files
REQUIRED_BACKEND_FILES = [
    "app.py",
    "sections"
]

# Required frontend files
REQUIRED_FRONTEND_FILES = [
    "index.html",
    "common.css",
    "common.js",
    "sections"
]

# Required section structure
SECTION_REQUIRED_FILES = {
    "backend": ["routes.py", "section.json", ".index"],
    "frontend": ["page.html", "page.js", ".index"]
}

# Docker files
REQUIRED_DOCKER_FILES = [
    "Dockerfile.webui",
    "docker-compose.webui.yml",
    "entrypoint.sh"
]


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def get_sections(dins_root: Path) -> List[str]:
    """Get list of section names from backend"""
    sections_dir = dins_root / BACKEND_PATH / "sections"
    if not sections_dir.exists():
        return []
    
    return [d.name for d in sections_dir.iterdir() 
            if d.is_dir() and not d.name.startswith('.')]


def validate_section_json(section_json: Path) -> Tuple[bool, Optional[str]]:
    """
    Validate a section.json file structure.
    
    Required fields: id, label, order, group
    """
    try:
        with open(section_json, 'r') as f:
            data = json.load(f)
        
        required = ["id", "label", "order", "group"]
        missing = [f for f in required if f not in data]
        
        if missing:
            return False, f"Missing fields: {', '.join(missing)}"
        
        # Validate order is a number
        if not isinstance(data.get("order"), (int, float)):
            return False, "Field 'order' must be a number"
        
        return True, None
        
    except json.JSONDecodeError as e:
        return False, f"Invalid JSON: {e}"
    except Exception as e:
        return False, str(e)


def check_python_imports(py_file: Path) -> Tuple[bool, Optional[str]]:
    """
    Check if a Python file has the expected imports for a routes file.
    This is a basic check without executing the code.
    """
    try:
        content = py_file.read_text()
        
        # Check for FastAPI router pattern
        if "router" not in content.lower():
            return False, "No 'router' found - may not define API routes"
        
        if "APIRouter" not in content and "Router" not in content:
            return False, "No Router import found"
        
        return True, None
        
    except Exception as e:
        return False, str(e)


# =============================================================================
# TEST FUNCTIONS
# =============================================================================

def test_webui_directory_exists(dins_root: Path) -> TestResult:
    """Test that WebUI directory exists"""
    start = time.time()
    name = "test_webui_directory_exists"
    
    webui_path = dins_root / WEBUI_BASE
    if not webui_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"WebUI directory not found: {webui_path}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_backend_structure(dins_root: Path) -> TestResult:
    """Test that backend has required files"""
    start = time.time()
    name = "test_backend_structure"
    missing = []
    
    backend_path = dins_root / BACKEND_PATH
    
    for file_name in REQUIRED_BACKEND_FILES:
        if not (backend_path / file_name).exists():
            missing.append(file_name)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing backend files: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_frontend_structure(dins_root: Path) -> TestResult:
    """Test that frontend has required files"""
    start = time.time()
    name = "test_frontend_structure"
    missing = []
    
    frontend_path = dins_root / FRONTEND_PATH
    
    for file_name in REQUIRED_FRONTEND_FILES:
        if not (frontend_path / file_name).exists():
            missing.append(file_name)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing frontend files: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_app_py_syntax(dins_root: Path) -> TestResult:
    """Test that app.py has valid Python syntax"""
    start = time.time()
    name = "test_app_py_syntax"
    
    app_py = dins_root / BACKEND_PATH / "app.py"
    
    if not app_py.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "app.py not found")
    
    try:
        compile(app_py.read_text(), app_py, 'exec')
        return TestResult(name, True, (time.time() - start) * 1000)
    except SyntaxError as e:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Syntax error at line {e.lineno}: {e.msg}")


def test_sections_exist(dins_root: Path) -> TestResult:
    """Test that at least one section exists"""
    start = time.time()
    name = "test_sections_exist"
    
    sections = get_sections(dins_root)
    
    if not sections:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "No sections found")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_backend_sections_complete(dins_root: Path) -> TestResult:
    """Test that each backend section has required files"""
    start = time.time()
    name = "test_backend_sections_complete"
    incomplete = []
    
    sections_dir = dins_root / BACKEND_PATH / "sections"
    sections = get_sections(dins_root)
    
    for section in sections:
        section_path = sections_dir / section
        missing = []
        
        for required_file in SECTION_REQUIRED_FILES["backend"]:
            if not (section_path / required_file).exists():
                missing.append(required_file)
        
        if missing:
            incomplete.append(f"{section} (missing: {', '.join(missing)})")
    
    if incomplete:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Incomplete sections: {'; '.join(incomplete[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_frontend_sections_complete(dins_root: Path) -> TestResult:
    """Test that each frontend section has required files"""
    start = time.time()
    name = "test_frontend_sections_complete"
    incomplete = []
    
    backend_sections = get_sections(dins_root)
    frontend_sections_dir = dins_root / FRONTEND_PATH / "sections"
    
    for section in backend_sections:
        section_path = frontend_sections_dir / section
        
        if not section_path.exists():
            incomplete.append(f"{section} (directory missing)")
            continue
        
        missing = []
        for required_file in SECTION_REQUIRED_FILES["frontend"]:
            if not (section_path / required_file).exists():
                missing.append(required_file)
        
        if missing:
            incomplete.append(f"{section} (missing: {', '.join(missing)})")
    
    if incomplete:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Incomplete frontend sections: {'; '.join(incomplete[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_section_json_valid(dins_root: Path) -> TestResult:
    """Test that all section.json files are valid"""
    start = time.time()
    name = "test_section_json_valid"
    invalid = []
    
    sections_dir = dins_root / BACKEND_PATH / "sections"
    sections = get_sections(dins_root)
    
    for section in sections:
        section_json = sections_dir / section / "section.json"
        if section_json.exists():
            valid, error = validate_section_json(section_json)
            if not valid:
                invalid.append(f"{section}: {error}")
    
    if invalid:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid section.json: {'; '.join(invalid[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_routes_have_router(dins_root: Path) -> TestResult:
    """Test that routes.py files define routers"""
    start = time.time()
    name = "test_routes_have_router"
    issues = []
    
    sections_dir = dins_root / BACKEND_PATH / "sections"
    sections = get_sections(dins_root)
    
    for section in sections:
        routes_py = sections_dir / section / "routes.py"
        if routes_py.exists():
            valid, error = check_python_imports(routes_py)
            if not valid:
                issues.append(f"{section}: {error}")
    
    if issues:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Router issues: {'; '.join(issues[:3])}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_docker_files_exist(dins_root: Path) -> TestResult:
    """Test that Docker configuration files exist"""
    start = time.time()
    name = "test_docker_files_exist"
    missing = []
    
    docker_path = dins_root / DOCKER_PATH
    
    if not docker_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Docker directory not found")
    
    for file_name in REQUIRED_DOCKER_FILES:
        if not (docker_path / file_name).exists():
            missing.append(file_name)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing Docker files: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_frontend_html_valid(dins_root: Path) -> TestResult:
    """Test that index.html has basic HTML structure"""
    start = time.time()
    name = "test_frontend_html_valid"
    
    index_html = dins_root / FRONTEND_PATH / "index.html"
    
    if not index_html.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "index.html not found")
    
    try:
        content = index_html.read_text()
        
        # Basic HTML checks
        checks = [
            ("<!DOCTYPE" in content or "<!doctype" in content, "Missing DOCTYPE"),
            ("<html" in content, "Missing <html> tag"),
            ("<head" in content, "Missing <head> tag"),
            ("<body" in content, "Missing <body> tag"),
        ]
        
        for check, error in checks:
            if not check:
                return TestResult(name, False, (time.time() - start) * 1000, error)
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_manifest_exists(dins_root: Path) -> TestResult:
    """Test that WebUI Manifest file exists"""
    start = time.time()
    name = "test_manifest_exists"
    
    manifest = dins_root / WEBUI_BASE / "Manifest"
    
    if not manifest.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Manifest file not found")
    
    # Check Manifest is not empty
    if manifest.stat().st_size == 0:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Manifest file is empty")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_section_count_matches(dins_root: Path) -> TestResult:
    """Test that backend and frontend have matching sections"""
    start = time.time()
    name = "test_section_count_matches"
    
    backend_sections = set(get_sections(dins_root))
    
    frontend_sections_dir = dins_root / FRONTEND_PATH / "sections"
    if not frontend_sections_dir.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "Frontend sections directory not found")
    
    frontend_sections = set(d.name for d in frontend_sections_dir.iterdir()
                           if d.is_dir() and not d.name.startswith('.'))
    
    # Check for mismatches
    backend_only = backend_sections - frontend_sections
    frontend_only = frontend_sections - backend_sections
    
    if backend_only or frontend_only:
        issues = []
        if backend_only:
            issues.append(f"Backend only: {', '.join(backend_only)}")
        if frontend_only:
            issues.append(f"Frontend only: {', '.join(frontend_only)}")
        
        return TestResult(name, False, (time.time() - start) * 1000,
                         "; ".join(issues))
    
    return TestResult(name, True, (time.time() - start) * 1000)


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all WebUI module tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_webui")
    dins_root = Path(config["dins_root"])
    
    # Define all tests in order
    tests = [
        (test_webui_directory_exists, dins_root),
        (test_backend_structure, dins_root),
        (test_frontend_structure, dins_root),
        (test_app_py_syntax, dins_root),
        (test_sections_exist, dins_root),
        (test_backend_sections_complete, dins_root),
        (test_frontend_sections_complete, dins_root),
        (test_section_json_valid, dins_root),
        (test_routes_have_router, dins_root),
        (test_docker_files_exist, dins_root),
        (test_frontend_html_valid, dins_root),
        (test_manifest_exists, dins_root),
        (test_section_count_matches, dins_root),
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
    
    parser = argparse.ArgumentParser(description="Run WebUI module tests")
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
    
    print(f"\nWebUI Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
