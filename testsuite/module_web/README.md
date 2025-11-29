# DINS Test Suite - Web Module

This module provides tests for web-based parts of DINS as specified in PART5.

## Overview

The web test module validates:
- HTTP(S) endpoint reachability
- Expected responses and status codes
- Static and dynamic page accessibility
- API endpoint validation
- Error handling behavior (404, etc.)

## Test Categories

### Offline Tests (Always Run)

These tests validate static assets without requiring a running server:

| Test | Description |
|------|-------------|
| `test_static_files_exist` | Verifies index.html, common.css, common.js exist |
| `test_html_structure` | Validates HTML has DOCTYPE, html, head, body tags |
| `test_css_syntax` | Checks CSS file has balanced braces |
| `test_js_syntax` | Checks JavaScript has balanced braces/parentheses |
| `test_nginx_config_exists` | Verifies nginx configuration exists |
| `test_api_routes_defined` | Checks backend defines API routes |

### Online Tests (Server Required)

These tests require a running web server and are skipped if no server is detected:

| Test | Description |
|------|-------------|
| `test_server_reachable` | Checks if server responds on port 80 |
| `test_root_page_accessible` | Verifies / returns 200 |
| `test_api_health_endpoint` | Tests /api/health endpoint |
| `test_api_sections_endpoint` | Tests /api/sections returns valid JSON |
| `test_404_handling` | Verifies 404 for nonexistent pages |

## Usage

### Run as part of test suite

```bash
python testsuite.py --module web
```

### Run standalone

```bash
cd testsuite/module_web
python test_module_web.py --verbose
```

### Test against specific host

```bash
python test_module_web.py --host dins-setup.local --verbose
```

## Server Detection

The module automatically tries to detect a running server in this order:

1. `dins-setup.local` (mDNS/Avahi)
2. `localhost`
3. `127.0.0.1`

If no server is detected, online tests are skipped (marked as passed).

## Tested Endpoints

| Endpoint | Expected Status | Description |
|----------|-----------------|-------------|
| `/` | 200 | Main page |
| `/api/health` | 200 | Health check endpoint |
| `/api/sections` | 200 | Section listing (JSON) |
| `/nonexistent` | 404 | Error handling |

## Non-Destructive Testing

All tests are non-destructive:
- Only GET requests are made
- No data is modified
- Read-only operations only

## Environment Considerations

Per PART5 specification, web tests:
- Respect test vs production environments
- Use test endpoints where available
- Do not affect persistent state

## Adding New Web Tests

### Offline Test

```python
def test_my_offline_check(dins_root: Path) -> TestResult:
    start = time.time()
    name = "test_my_offline_check"
    # Validate files without network access
    return TestResult(name, True, (time.time() - start) * 1000)
```

### Online Test

```python
def test_my_endpoint(dins_root: Path, host: Optional[str] = None) -> TestResult:
    start = time.time()
    name = "test_my_endpoint"
    
    test_host = host or find_available_host()
    if not test_host:
        return TestResult(name, True, (time.time() - start) * 1000)  # Skip
    
    url = f"http://{test_host}:{DEFAULT_PORT}/my/endpoint"
    status, body, headers = http_get(url)
    
    # Validate response
    return TestResult(name, status == 200, (time.time() - start) * 1000)
```

## Related Documentation

- PART5: Test Methods for Web, CLI, and Other Mechanics
- WebUI Backend Documentation
- nginx Configuration
