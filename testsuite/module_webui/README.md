# Module: WebUI Tests

This module contains tests for the DINS WebUI components, including both the FastAPI backend and the JavaScript frontend.

## Purpose

The WebUI module tests ensure:

1. **Directory Structure** - WebUI directories exist with proper organization
2. **Backend Completeness** - All required backend files are present
3. **Frontend Completeness** - All required frontend files are present
4. **Section Integrity** - All configuration sections have matching backend/frontend
5. **Configuration Validity** - section.json files are properly structured
6. **Docker Configuration** - Container setup files are present

## Test Functions

### `test_webui_directory_exists`

Verifies the WebUI base directory exists at `install/_webui.sh/`.

### `test_backend_structure`

Checks for required backend files:
- `app.py` - Main FastAPI application
- `sections/` - Section modules directory

### `test_frontend_structure`

Checks for required frontend files:
- `index.html` - Main HTML entry point
- `common.css` - Shared styles
- `common.js` - Shared JavaScript
- `sections/` - Section pages directory

### `test_app_py_syntax`

Validates that `app.py` has no Python syntax errors.

### `test_sections_exist`

Ensures at least one configuration section is defined.

### `test_backend_sections_complete`

For each section, validates required backend files:
- `routes.py` - API route definitions
- `section.json` - Section metadata
- `.index` - Section index file

### `test_frontend_sections_complete`

For each section, validates required frontend files:
- `page.html` - Section HTML template
- `page.js` - Section JavaScript
- `.index` - Section index file

### `test_section_json_valid`

Validates `section.json` file structure:
- Has `id` field (string)
- Has `label` field (string)
- Has `order` field (number)
- Has `group` field (string)

### `test_routes_have_router`

Checks that each `routes.py` defines an API router.

**Checks:**
- File contains "router" reference
- File imports APIRouter or Router

### `test_docker_files_exist`

Validates Docker configuration files:
- `Dockerfile.webui`
- `docker-compose.webui.yml`
- `entrypoint.sh`

### `test_frontend_html_valid`

Basic HTML validation for `index.html`:
- Has DOCTYPE declaration
- Has `<html>` tag
- Has `<head>` tag
- Has `<body>` tag

### `test_manifest_exists`

Checks that the WebUI Manifest file exists and is not empty.

### `test_section_count_matches`

Ensures backend and frontend have the same sections defined.

## Usage

### From Test Suite

```bash
python testsuite.py --module webui
```

### Standalone

```bash
cd testsuite/module_webui
python test_module_webui.py --verbose
```

### With Custom DINS Root

```bash
python test_module_webui.py --dins-root /path/to/dins --verbose
```

## Configuration

The module receives configuration from the test suite:

```python
config = {
    "dins_root": "/path/to/dins",
    "verbose": False,
    "pre_deployment": False
}
```

## Section Structure

The WebUI expects this section structure:

```
backend/sections/<section_name>/
├── routes.py      # FastAPI router with API endpoints
├── section.json   # Section metadata
└── .index         # Section index file

frontend/sections/<section_name>/
├── page.html      # Section HTML template
├── page.js        # Section JavaScript
└── .index         # Section index file
```

### section.json Format

```json
{
    "id": "example_section",
    "label": "Example Section",
    "order": 10,
    "group": "settings",
    "frontend": {
        "path": "/sections/example_section/page.html"
    },
    "backend": {
        "router_prefix": "/example_section"
    }
}
```

## Dependencies

- Python 3.8+
- No external packages required (uses standard library only)

## Safety Notes

This module is **read-only** and does not:
- Modify any files
- Start any servers
- Execute any code beyond syntax checking

It is safe to run at any time.

## Current Sections

The WebUI includes these configuration sections:

| Section | Description |
|---------|-------------|
| admin_security | Admin user and security settings |
| audio_stack | Audio service configuration |
| cluster_swarm | Docker Swarm cluster settings |
| devices_audio | Audio device management |
| devices_bluetooth | Bluetooth device management |
| devices_video | Video device management |
| devices_other | Other device types |
| enhancements_stack | Enhancement services |
| llm_cloud | Cloud LLM provider configuration |
| llm_local | Local LLM provider configuration |
| mobile_stack | Mobile integration services |
| network_ssh | SSH and network settings |
| nodes_selection | Cluster node management |
| stt_engine | Speech-to-text engine selection |
| stt_input | STT input configuration |
| tts_routing | Text-to-speech output routing |
| vpn_mesh_stack | VPN/mesh network services |
| web_stack | Web services configuration |

## Adding New Tests

To add a new test:

1. Create a function following the test pattern:
   ```python
   def test_your_feature(dins_root: Path) -> TestResult:
       start = time.time()
       name = "test_your_feature"
       
       try:
           # Your test logic here
           return TestResult(name, True, (time.time() - start) * 1000)
       except Exception as e:
           return TestResult(name, False, (time.time() - start) * 1000, str(e))
   ```

2. Add to the `tests` list in `run_tests()`

3. Update this README with the test description
