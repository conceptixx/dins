# DINS Test Suite - Check Command Module

This module provides tests for the `dinser check` troubleshooting command per PART 6.3 and PART 6.5.4.

## Overview

The check command module validates:
- Command availability and help output
- Diagnostic check execution
- Exit codes for success/failure scenarios
- Output format and summary content

## Tests

| Test | Description |
|------|-------------|
| `test_check_command_exists` | Verifies check.sh module exists |
| `test_check_module_syntax` | Validates bash syntax |
| `test_check_has_description` | Checks for description comment |
| `test_check_help` | Validates help output |
| `test_check_webui_runs` | Tests command execution |
| `test_check_produces_summary` | Verifies STATUS output |
| `test_check_unknown_target` | Tests graceful error handling |
| `test_check_targets_equivalent` | Confirms web-ui = dins-setup.local |
| `test_check_exit_codes` | Validates exit code semantics |

## Usage

### Run as part of test suite

```bash
python testsuite.py --module check
```

### Run standalone

```bash
cd testsuite/module_check
python test_module_check.py --verbose
```

## Tested Command

```bash
dinser check web-ui
dinser check dins-setup.local
dinser check --help
```

## Expected Behavior (per PART 6.3)

The check command should:

1. Perform diagnostic checks:
   - DNS resolution
   - Network reachability
   - Port availability
   - HTTP response
   - Docker service status

2. Output a summary with STATUS: OK or STATUS: FAILED

3. Use exit codes:
   - 0: All checks passed
   - Non-zero: One or more checks failed

4. Provide troubleshooting suggestions on failure

## Related Documentation

- PART 6.3: Troubleshooting mechanic via `dinser check`
- PART 6.5.4: Testsuite requirements
