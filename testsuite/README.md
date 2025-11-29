# DINS Test Suite

The DINS Test Suite provides a comprehensive, extendable testing framework for validating all components of the DINS (Distributed Intelligent Network Services) system.

## Overview

The test suite is designed to:

- Test individual components in isolation
- Test logical groups of components (modules)
- Be extended without rewriting the framework
- Provide safe pre-deployment validation
- Support both automated and manual testing workflows

## Quick Start

### Run All Tests

```bash
cd testsuite
python testsuite.py
```

### Run Specific Module(s)

```bash
# Run only the core module
python testsuite.py --module core

# Run multiple modules
python testsuite.py --module core webui installer
```

### Pre-Deployment Validation

Before deploying changes to production, run the pre-deployment check:

```bash
python testsuite.py --pre-deployment
```

This mode:
- Prioritizes critical modules (core first)
- Stops immediately on any failure
- Validates system integrity

### List Available Modules

```bash
python testsuite.py --list
```

## Command-Line Options

| Option | Short | Description |
|--------|-------|-------------|
| `--module NAME [NAME...]` | `-m` | Run specific module(s) only |
| `--continue-on-fail` | `-c` | Continue running after failures |
| `--pre-deployment` | `-p` | Pre-deployment validation mode |
| `--verbose` | `-v` | Enable verbose output |
| `--list` | `-l` | List available test modules |

## Test Modules

The test suite discovers modules automatically. Each module resides in a `module_*` directory.

### Current Modules

| Module | Description |
|--------|-------------|
| `module_core` | Core system tests: directory structure, configuration, file integrity |
| `module_webui` | WebUI tests: backend API, frontend assets, section discovery |
| `module_installer` | Installer tests: Manifest parsing, module execution, CLI tools |
| `module_cli` | CLI tests: command callability, exit codes, help output (PART 5) |
| `module_web` | Web tests: HTTP endpoints, static assets, API validation (PART 5) |
| `module_check` | Check command tests: diagnostics validation (PART 6.3) |
| `module_setup` | Setup state tests: state file mechanics, MOTD (PART 6.1) |

### Module Structure

Each module directory contains:

```
module_<name>/
├── test_module_<name>.py   # Main test file with run_tests() function
├── README.md               # Module documentation
└── ...                     # Additional test files, fixtures, configs
```

## Writing New Tests

### Adding a New Module

1. Create a new directory: `testsuite/module_<name>/`
2. Create the test file: `test_module_<name>.py`
3. Implement the `run_tests(config)` function
4. Create a `README.md` documenting the tests

Example minimal module:

```python
# test_module_example.py
from testsuite import ModuleResult, TestResult
import time

def run_tests(config: dict) -> ModuleResult:
    """Run all tests for this module"""
    result = ModuleResult(name="module_example")
    
    # Test 1
    start = time.time()
    try:
        assert 1 + 1 == 2
        result.add_result(TestResult(
            name="test_basic_math",
            passed=True,
            duration_ms=(time.time() - start) * 1000
        ))
    except AssertionError as e:
        result.add_result(TestResult(
            name="test_basic_math",
            passed=False,
            duration_ms=(time.time() - start) * 1000,
            error=str(e)
        ))
    
    return result
```

### Adding Tests to Existing Modules

1. Add new test functions to the module's test file
2. Call them from `run_tests()`
3. Update the module's `README.md`

## Configuration

Tests receive a configuration dictionary:

```python
config = {
    "dins_root": "/path/to/dins",      # DINS root directory
    "testsuite_dir": "/path/to/testsuite",
    "pre_deployment": False,            # True if running pre-deployment check
    "verbose": False                    # True if verbose mode enabled
}
```

## Safety Guidelines

### Test Environments

Tests should use:
- Test configuration files (not production configs)
- Temporary directories for file operations
- Mock services where possible
- Sandboxed environments

### Non-Destructive Defaults

Tests should NOT:
- Delete user data
- Modify production configurations
- Shut down critical services
- Make permanent changes to the system

### Backup Compliance

If tests modify any DINS files:
- Create backups before changes
- Restore original state after tests
- Follow the backup rules in PART3_INDEX_AND_BACKUP_RULES.md

## Logging

Test logs are written to `testsuite/logs/` with timestamps:

```
logs/
├── testsuite_20250128_143022.log
├── testsuite_20250128_151547.log
└── ...
```

Logs include:
- Module start/end times
- Individual test results
- Error details and stack traces
- Configuration information

## Troubleshooting

### No Modules Found

Ensure modules follow the naming convention:
- Directory: `module_<name>/`
- Test file: `test_module_<name>.py`

### Import Errors

Check that:
- The testsuite directory is in Python's path
- All dependencies are installed
- Syntax errors in test files

### Permission Errors

Some tests may require elevated permissions. Run with appropriate privileges or configure test fixtures to use accessible locations.

### Test Timeouts

Long-running tests can be optimized by:
- Using mocks instead of real services
- Reducing dataset sizes for tests
- Parallelizing independent tests

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | All tests passed |
| 1 | One or more tests failed |

## Integration with CI/CD

The test suite can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions
- name: Run DINS Tests
  run: |
    cd dins/testsuite
    python testsuite.py --pre-deployment
```

## Contributing

When adding new tests:
1. Follow the module structure conventions
2. Write clear, focused test cases
3. Document tests in the module README
4. Ensure tests are repeatable and isolated
5. Keep test execution time reasonable
