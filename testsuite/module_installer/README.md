# Module: Installer Tests

This module contains tests for the DINS Installer system, including Manifest parsing, shell modules, validators, and CLI tools.

## Purpose

The installer module tests ensure:

1. **Directory Structure** - Installer directories exist with proper organization
2. **Manifest Validity** - Manifest files can be parsed and have valid operations
3. **Shell Modules** - Operation scripts exist and have valid syntax
4. **Validators** - Parameter validation scripts are present
5. **CLI Tools** - The dinser CLI tool is properly structured
6. **Docker Setup** - Container configuration for setup is valid

## Test Functions

### `test_install_directory_exists`

Verifies the install directory exists at `install/`.

### `test_setup_module_exists`

Checks that the `_setup.sh` module directory exists.

### `test_setup_manifest_exists`

Verifies `_setup.sh/Manifest` file is present.

### `test_setup_manifest_valid`

Parses the Manifest file and ensures it's syntactically correct.

**Manifest Format:**
```
OPERATION: copy
SOURCE: /path/to/source
TARGET: /path/to/target
MODE: 0755
```

### `test_manifest_operations_valid`

Validates each operation in the Manifest has required fields:
- `OPERATION` (required for all)
- `TARGET` (required for most operations)

### `test_operation_scripts_exist`

Checks for expected operation scripts:
- `_copy.sh`
- `_mkdir.sh`
- `_chmod.sh`
- `_chuser.sh`
- `_chgroup.sh`
- `_symlink.sh`
- `_template.sh`
- `_echo.sh`
- `_run_cmd.sh`
- `_set_var.sh`

### `test_operation_scripts_valid`

Validates shell script syntax:
- Has shebang (`#!/bin/bash` or similar)
- Contains executable code

### `test_validator_scripts_exist`

Checks for expected validator scripts:
- `_validate_path.sh`
- `_validate_file.sh`
- `_validate_string.sh`
- `_validate_boolean.sh`
- `_validate_chmod_mode.sh`
- `_validate_user.sh`
- `_validate_group.sh`

### `test_cli_directory_exists`

Verifies the CLI tools directory exists at `_setup.sh/cli/`.

### `test_dinser_cli_exists`

Checks that the `dinser` CLI tool is present.

### `test_dinser_cli_valid`

Validates dinser shell script syntax.

### `test_docker_setup_exists`

Checks for Docker setup files:
- `Dockerfile.setup`
- `docker-compose.setup.yml`

### `test_main_scripts_exist`

Verifies main installer scripts:
- `setup.sh`
- `webui.sh`

### `test_main_scripts_valid`

Validates main script syntax.

### `test_all_manifests_parseable`

Recursively finds and parses all Manifest files in the install directory.

## Usage

### From Test Suite

```bash
python testsuite.py --module installer
```

### Standalone

```bash
cd testsuite/module_installer
python test_module_installer.py --verbose
```

### With Custom DINS Root

```bash
python test_module_installer.py --dins-root /path/to/dins --verbose
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

## Manifest Syntax

The DINS installer uses Manifest files to define installation operations:

```
# Comment lines start with #

OPERATION: copy
SOURCE: ${DINS_INSTALL_DIR}/files/config.json
TARGET: ${DINS_BASE_DIR}/config/config.json
MODE: 0644
OWNER: root
GROUP: dins-system

OPERATION: mkdir
TARGET: ${DINS_BASE_DIR}/logs
MODE: 0755

OPERATION: template
SOURCE: ${DINS_INSTALL_DIR}/templates/nginx.conf.tpl
TARGET: /etc/nginx/sites-available/dins
VARS: PORT=8080,HOST=localhost

OPERATION: echo
MESSAGE: Installation complete!
```

### Supported Operations

| Operation | Description | Required Fields |
|-----------|-------------|-----------------|
| `copy` | Copy a file | SOURCE, TARGET |
| `mkdir` | Create directory | TARGET |
| `chmod` | Change permissions | TARGET, MODE |
| `chuser` | Change owner | TARGET, OWNER |
| `chgroup` | Change group | TARGET, GROUP |
| `symlink` | Create symlink | SOURCE, TARGET |
| `template` | Process template | SOURCE, TARGET |
| `echo` | Print message | MESSAGE |
| `run_cmd` | Run command | CMD |
| `set_var` | Set variable | NAME, VALUE |

## Dependencies

- Python 3.8+
- No external packages required (uses standard library only)

## Safety Notes

This module is **read-only** and does not:
- Execute any installation operations
- Modify system files
- Run shell scripts (only checks syntax)

It is safe to run at any time.

## Installer Structure

```
install/
├── setup.sh              # Main installer entry point
├── webui.sh              # WebUI installer entry point
├── .index                # Directory index
├── _setup.sh/            # Setup module
│   ├── Manifest          # Installation operations
│   ├── _copy.sh          # Copy operation
│   ├── _mkdir.sh         # Mkdir operation
│   ├── ...               # Other operations
│   ├── _validate_*.sh    # Validators
│   ├── cli/              # CLI tools
│   │   └── dinser        # Main CLI tool
│   └── docker/           # Docker setup
│       ├── Dockerfile.setup
│       └── docker-compose.setup.yml
└── _webui.sh/            # WebUI module
    ├── Manifest
    ├── backend/
    ├── frontend/
    └── docker/
```

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
