# DINS Test Suite - CLI Module

This module provides tests for CLI-based parts of DINS as specified in PART5.

## Overview

The CLI test module validates:
- CLI command callability and exit codes
- Help output correctness
- Version information display
- Parameter and mode testing
- Error case handling (graceful failures)

## Tested Components

| Component | Description |
|-----------|-------------|
| `dinser` | Main DINS CLI tool |
| `setup.sh` | Installation orchestrator |
| `webui.sh` | WebUI management script |

## Tests

### dinser CLI Tests

| Test | Description |
|------|-------------|
| `test_dinser_exists` | Verifies dinser exists and is executable |
| `test_dinser_help` | Validates --help, -h, and help commands |
| `test_dinser_version` | Validates --version, -v, and version commands |
| `test_dinser_status` | Tests the status command runs without error |
| `test_dinser_no_args` | Ensures no arguments shows help |
| `test_dinser_invalid_command` | Checks graceful handling of unknown commands |
| `test_dinser_webui_help` | Tests webui subcommand behavior |

### Script Tests

| Test | Description |
|------|-------------|
| `test_cli_scripts_executable` | Verifies all CLI scripts are executable |
| `test_setup_sh_help` | Tests setup.sh --help works |
| `test_webui_sh_help` | Tests webui.sh --help works |

## Usage

### Run as part of test suite

```bash
python testsuite.py --module cli
```

### Run standalone

```bash
cd testsuite/module_cli
python test_module_cli.py --verbose
```

## Non-Destructive Testing

All tests in this module are non-destructive:
- Commands that would modify system state are NOT executed
- Only read-only operations (help, version, status) are tested
- No actual installation or deployment operations are triggered

## Exit Codes Tested

| Code | Meaning |
|------|---------|
| 0 | Command succeeded |
| 1 | Command failed (expected for invalid input) |
| Other | Unexpected error condition |

## Adding New CLI Tests

To add tests for new CLI commands:

1. Add the command to `CLI_TOOLS` if it's a new tool
2. Create a test function following the pattern:
   ```python
   def test_<command>_<aspect>(dins_root: Path) -> TestResult:
       start = time.time()
       name = "test_<command>_<aspect>"
       # Test logic
       return TestResult(name, passed, duration_ms, error)
   ```
3. Add the test to the `tests` list in `run_tests()`
4. Update this README

## Related Documentation

- PART5: Test Methods for Web, CLI, and Other Mechanics
- dinser CLI Documentation
