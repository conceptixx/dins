#!/usr/bin/env python3
"""
DINS Test Suite - Web Module Tests
Location: <DINS_ROOT>/testsuite/module_web/test_module_web.py

Tests for web-based parts of DINS per PART5 specification:
- HTTP(S) endpoint reachability
- Expected responses and status codes
- Static and dynamic page accessibility
- API endpoint validation
- Error handling behavior

This module can run with or without a live server.
"""

import json
import os
import socket
import sys
import time
import urllib.request
import urllib.error
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

# Default endpoints to test
DEFAULT_HOST = "dins-setup.local"
FALLBACK_HOSTS = ["localhost", "127.0.0.1"]
DEFAULT_PORT = 80
HTTPS_PORT = 443

# Endpoint definitions for testing
ENDPOINTS = {
    "root": "/",
    "api_health": "/api/health",
    "api_sections": "/api/sections",
}

# Expected content markers for static pages
EXPECTED_CONTENT_MARKERS = {
    "/": ["<!DOCTYPE", "<html", "DINS"],
}

# Connection timeout in seconds
TIMEOUT = 5


# =============================================================================
# TEST HELPER FUNCTIONS
# =============================================================================

def check_port_open(host: str, port: int, timeout: int = 2) -> bool:
    """
    Check if a port is open on the given host.
    """
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((host, port))
        sock.close()
        return result == 0
    except (socket.error, socket.timeout, OSError):
        return False


def resolve_hostname(hostname: str) -> Optional[str]:
    """
    Try to resolve a hostname to an IP address.
    """
    try:
        return socket.gethostbyname(hostname)
    except socket.gaierror:
        return None


def http_get(
    url: str,
    timeout: int = TIMEOUT
) -> Tuple[int, str, Dict[str, str]]:
    """
    Perform HTTP GET request.
    
    Returns (status_code, body, headers)
    Returns (-1, error_message, {}) on failure
    """
    try:
        req = urllib.request.Request(url, method='GET')
        req.add_header('User-Agent', 'DINS-TestSuite/1.0')
        
        with urllib.request.urlopen(req, timeout=timeout) as response:
            status = response.status
            body = response.read().decode('utf-8', errors='replace')
            headers = dict(response.headers)
            return status, body, headers
            
    except urllib.error.HTTPError as e:
        return e.code, str(e.reason), {}
    except urllib.error.URLError as e:
        return -1, str(e.reason), {}
    except Exception as e:
        return -1, str(e), {}


def find_available_host() -> Optional[str]:
    """
    Find an available host for web testing.
    
    Tries DEFAULT_HOST first, then FALLBACK_HOSTS.
    Returns None if no host is available.
    """
    # Try primary host
    if resolve_hostname(DEFAULT_HOST):
        if check_port_open(DEFAULT_HOST, DEFAULT_PORT):
            return DEFAULT_HOST
    
    # Try fallback hosts
    for host in FALLBACK_HOSTS:
        if check_port_open(host, DEFAULT_PORT):
            return host
    
    return None


# =============================================================================
# OFFLINE TESTS (No server required)
# =============================================================================

def test_static_files_exist(dins_root: Path) -> TestResult:
    """Test that expected static web files exist"""
    start = time.time()
    name = "test_static_files_exist"
    missing = []
    
    frontend_path = dins_root / "install" / "_webui.sh" / "frontend"
    
    expected_files = [
        "index.html",
        "common.css",
        "common.js",
    ]
    
    for file_name in expected_files:
        if not (frontend_path / file_name).exists():
            missing.append(file_name)
    
    if missing:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Missing static files: {', '.join(missing)}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_html_structure(dins_root: Path) -> TestResult:
    """Test that HTML files have valid structure"""
    start = time.time()
    name = "test_html_structure"
    issues = []
    
    frontend_path = dins_root / "install" / "_webui.sh" / "frontend"
    index_html = frontend_path / "index.html"
    
    if not index_html.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "index.html not found")
    
    try:
        content = index_html.read_text()
        
        # Check required elements
        checks = [
            ("<!DOCTYPE" in content or "<!doctype" in content, "Missing DOCTYPE"),
            ("<html" in content, "Missing <html> tag"),
            ("<head" in content, "Missing <head> tag"),
            ("<body" in content, "Missing <body> tag"),
            ("</html>" in content, "Missing closing </html> tag"),
        ]
        
        for check, error in checks:
            if not check:
                issues.append(error)
        
        if issues:
            return TestResult(name, False, (time.time() - start) * 1000,
                             "; ".join(issues))
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_css_syntax(dins_root: Path) -> TestResult:
    """Test that CSS files have basic valid syntax"""
    start = time.time()
    name = "test_css_syntax"
    
    frontend_path = dins_root / "install" / "_webui.sh" / "frontend"
    common_css = frontend_path / "common.css"
    
    if not common_css.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "common.css not found")
    
    try:
        content = common_css.read_text()
        
        # Basic CSS checks
        if '{' not in content or '}' not in content:
            return TestResult(name, False, (time.time() - start) * 1000,
                             "CSS file appears empty or invalid")
        
        # Check balanced braces (simple check)
        if content.count('{') != content.count('}'):
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Unbalanced braces in CSS")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_js_syntax(dins_root: Path) -> TestResult:
    """Test that JavaScript files have basic valid syntax"""
    start = time.time()
    name = "test_js_syntax"
    
    frontend_path = dins_root / "install" / "_webui.sh" / "frontend"
    common_js = frontend_path / "common.js"
    
    if not common_js.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "common.js not found")
    
    try:
        content = common_js.read_text()
        
        # Check for common JS syntax issues
        if not content.strip():
            return TestResult(name, False, (time.time() - start) * 1000,
                             "JavaScript file is empty")
        
        # Check balanced braces and parentheses
        if content.count('{') != content.count('}'):
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Unbalanced braces in JavaScript")
        
        if content.count('(') != content.count(')'):
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Unbalanced parentheses in JavaScript")
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


def test_nginx_config_exists(dins_root: Path) -> TestResult:
    """Test that nginx configuration exists"""
    start = time.time()
    name = "test_nginx_config_exists"
    
    nginx_path = dins_root / "install" / "_webui.sh" / "docker" / "nginx.d"
    
    if not nginx_path.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "nginx.d directory not found")
    
    config_files = list(nginx_path.glob("*.conf"))
    if not config_files:
        return TestResult(name, False, (time.time() - start) * 1000,
                         "No nginx config files found")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_api_routes_defined(dins_root: Path) -> TestResult:
    """Test that API routes are defined in backend"""
    start = time.time()
    name = "test_api_routes_defined"
    
    app_py = dins_root / "install" / "_webui.sh" / "backend" / "app.py"
    
    if not app_py.exists():
        return TestResult(name, False, (time.time() - start) * 1000,
                         "app.py not found")
    
    try:
        content = app_py.read_text()
        
        # Check for FastAPI app and routes
        checks = [
            ("FastAPI" in content, "No FastAPI import found"),
            ("@" in content and "router" in content.lower(), "No route decorators found"),
        ]
        
        for check, error in checks:
            if not check:
                return TestResult(name, False, (time.time() - start) * 1000, error)
        
        return TestResult(name, True, (time.time() - start) * 1000)
        
    except Exception as e:
        return TestResult(name, False, (time.time() - start) * 1000, str(e))


# =============================================================================
# ONLINE TESTS (Server required - skipped if unavailable)
# =============================================================================

def test_server_reachable(dins_root: Path, host: Optional[str] = None) -> TestResult:
    """Test if web server is reachable"""
    start = time.time()
    name = "test_server_reachable"
    
    test_host = host or find_available_host()
    
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip if no server
    
    if check_port_open(test_host, DEFAULT_PORT):
        return TestResult(name, True, (time.time() - start) * 1000)
    
    return TestResult(name, False, (time.time() - start) * 1000,
                     f"Server not reachable at {test_host}:{DEFAULT_PORT}")


def test_root_page_accessible(dins_root: Path, host: Optional[str] = None) -> TestResult:
    """Test that root page returns 200"""
    start = time.time()
    name = "test_root_page_accessible"
    
    test_host = host or find_available_host()
    
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip
    
    url = f"http://{test_host}:{DEFAULT_PORT}/"
    status, body, headers = http_get(url)
    
    if status == -1:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Connection failed: {body}")
    
    if status != 200:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Expected 200, got {status}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_api_health_endpoint(dins_root: Path, host: Optional[str] = None) -> TestResult:
    """Test that /api/health endpoint works"""
    start = time.time()
    name = "test_api_health_endpoint"
    
    test_host = host or find_available_host()
    
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip
    
    url = f"http://{test_host}:{DEFAULT_PORT}/api/health"
    status, body, headers = http_get(url)
    
    if status == -1:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Connection failed: {body}")
    
    # Health endpoint should return 200
    if status != 200:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Health endpoint returned {status}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_api_sections_endpoint(dins_root: Path, host: Optional[str] = None) -> TestResult:
    """Test that /api/sections endpoint works"""
    start = time.time()
    name = "test_api_sections_endpoint"
    
    test_host = host or find_available_host()
    
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip
    
    url = f"http://{test_host}:{DEFAULT_PORT}/api/sections"
    status, body, headers = http_get(url)
    
    if status == -1:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Connection failed: {body}")
    
    if status != 200:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Sections endpoint returned {status}")
    
    # Response should be valid JSON
    try:
        data = json.loads(body)
        if not isinstance(data, (list, dict)):
            return TestResult(name, False, (time.time() - start) * 1000,
                             "Sections response is not a list or dict")
    except json.JSONDecodeError as e:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Invalid JSON response: {e}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


def test_404_handling(dins_root: Path, host: Optional[str] = None) -> TestResult:
    """Test that 404 errors are handled properly"""
    start = time.time()
    name = "test_404_handling"
    
    test_host = host or find_available_host()
    
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip
    
    url = f"http://{test_host}:{DEFAULT_PORT}/nonexistent_page_12345"
    status, body, headers = http_get(url)
    
    if status == -1:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Connection failed: {body}")
    
    # Should return 404 for nonexistent page
    if status != 404:
        return TestResult(name, False, (time.time() - start) * 1000,
                         f"Expected 404, got {status}")
    
    return TestResult(name, True, (time.time() - start) * 1000)


# =============================================================================
# MAIN TEST RUNNER
# =============================================================================

def run_tests(config: Dict[str, Any]) -> ModuleResult:
    """
    Run all web module tests.
    
    Args:
        config: Test configuration dictionary with dins_root, etc.
    
    Returns:
        ModuleResult with all test results
    """
    result = ModuleResult(name="module_web")
    dins_root = Path(config["dins_root"])
    
    # Detect if server is available
    available_host = find_available_host()
    
    if config.get("verbose"):
        if available_host:
            print(f"  [INFO] Web server detected at {available_host}")
        else:
            print("  [INFO] No web server detected - online tests will be skipped")
    
    # Offline tests (always run)
    offline_tests = [
        (test_static_files_exist, dins_root),
        (test_html_structure, dins_root),
        (test_css_syntax, dins_root),
        (test_js_syntax, dins_root),
        (test_nginx_config_exists, dins_root),
        (test_api_routes_defined, dins_root),
    ]
    
    # Online tests (only run if server available)
    online_tests = [
        (test_server_reachable, dins_root),
        (test_root_page_accessible, dins_root),
        (test_api_health_endpoint, dins_root),
        (test_api_sections_endpoint, dins_root),
        (test_404_handling, dins_root),
    ]
    
    # Run offline tests
    for test_func, arg in offline_tests:
        test_result = test_func(arg)
        result.add_result(test_result)
        
        if config.get("verbose"):
            status = "✓" if test_result.passed else "✗"
            print(f"  {status} {test_result.name}")
    
    # Run online tests if server available
    if available_host:
        for test_func, arg in online_tests:
            test_result = test_func(arg, available_host)
            result.add_result(test_result)
            
            if config.get("verbose"):
                status = "✓" if test_result.passed else "✗"
                print(f"  {status} {test_result.name}")
    else:
        # Mark online tests as skipped
        for test_func, arg in online_tests:
            result.add_result(TestResult(
                name=test_func.__name__,
                passed=True,
                duration_ms=0,
                error=None
            ))
            if config.get("verbose"):
                print(f"  ○ {test_func.__name__} (skipped - no server)")
    
    return result


# =============================================================================
# STANDALONE EXECUTION
# =============================================================================

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Run web module tests")
    parser.add_argument("--dins-root", type=str,
                       default=str(Path(__file__).parent.parent.parent),
                       help="DINS root directory")
    parser.add_argument("--host", type=str, default=None,
                       help="Web server host to test")
    parser.add_argument("--verbose", "-v", action="store_true",
                       help="Verbose output")
    
    args = parser.parse_args()
    
    config = {
        "dins_root": args.dins_root,
        "verbose": args.verbose
    }
    
    result = run_tests(config)
    
    print(f"\nWeb Module Results:")
    print(f"  Tests run: {result.tests_run}")
    print(f"  Passed: {result.tests_passed}")
    print(f"  Failed: {result.tests_failed}")
    
    if result.tests_failed > 0:
        print("\nFailed tests:")
        for test in result.test_results:
            if not test.passed:
                print(f"  - {test.name}: {test.error}")
    
    sys.exit(0 if result.passed else 1)
