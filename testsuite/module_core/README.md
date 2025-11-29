# Module: Core Tests

This module contains tests for the fundamental DINS system components. It validates that the basic structure and configuration of DINS is correct before testing any higher-level functionality.

## Purpose

The core module tests ensure:

1. **Directory Structure** - Required directories exist and are accessible
2. **Critical Files** - Essential files are present (README, .index, setup.sh, etc.)
3. **Index File Integrity** - All .index files follow the correct format
4. **Configuration Validity** - JSON configuration files are syntactically correct
5. **Script Syntax** - Shell and Python scripts have no syntax errors

## Test Functions

### `test_dins_root_exists`

Verifies that the DINS root directory exists and is accessible.

**Checks:**
- Directory exists
- Is a valid directory (not a file)

### `test_directory_structure`

Validates the expected directory hierarchy.

**Expected directories:**
- `install/`
- `install/_setup.sh/`
- `install/_webui.sh/`
- `docs/`
- `testsuite/`

### `test_root_files`

Checks for required files at the DINS root level.

**Required files:**
- `README.md`
- `.index`

### `test_install_files`

Validates required files in the install directory.

**Required files:**
- `setup.sh`
- `webui.sh`
- `.index`

### `test_root_index_valid`

Validates the root `.index` file structure.

**Checks:**
- File exists
- Contains `### META` section
- Contains `directory_path:` field

### `test_all_index_files`

Recursively validates all `.index` files in the project.

**Checks:**
- Each .index file has proper META section
- Each .index file has directory_path field

### `test_section_json_files`

Validates all `section.json` files in the WebUI backend.

**Checks:**
- Files are valid JSON
- No syntax errors

### `test_manifest_files_exist`

Ensures Manifest files exist in installation module directories.

**Checks:**
- Each `_*.sh` directory has a Manifest file

### `test_shell_scripts_syntax`

Basic syntax validation for critical shell scripts.

**Checks:**
- Scripts have proper shebang (`#!/...`)

### `test_python_files_syntax`

Validates Python file syntax in the backend.

**Checks:**
- All .py files can be compiled without syntax errors

## Usage

### From Test Suite

```bash
python testsuite.py --module core
```

### Standalone

```bash
cd testsuite/module_core
python test_module_core.py --verbose
```

### With Custom DINS Root

```bash
python test_module_core.py --dins-root /path/to/dins --verbose
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

## Dependencies

- Python 3.8+
- No external packages required (uses standard library only)

## Safety Notes

This module is **read-only** and does not modify any files. It is safe to run at any time, including in production environments.

## Adding New Tests

To add a new test:

1. Create a function following the pattern:
   ```python
   def test_your_feature(dins_root: Path) -> TestResult:
       start = time.time()
       name = "test_your_feature"
       
       try:
           # Your test logic here
           if some_condition:
               return TestResult(name, True, (time.time() - start) * 1000)
           else:
               return TestResult(name, False, (time.time() - start) * 1000, 
                               "Error description")
       except Exception as e:
           return TestResult(name, False, (time.time() - start) * 1000, str(e))
   ```

2. Add the test to the `tests` list in `run_tests()`:
   ```python
   tests = [
       ...
       (test_your_feature, dins_root),
   ]
   ```

3. Update this README with the test description.
