# DINS Testsuite - Service Module

This module tests the DINS Swarm Service Construction system per PART 9.

## What It Tests

### Directory Structure
- `services/` directory exists with `.index`
- `config/` directory exists
- `swarm/` directory exists
- `system/secrets/` directory exists

### Example Service Template
- `_example` service template exists
- Has valid `service.yaml` descriptor
- Has all required fields (name, description, type, image, runtime)
- Has Dockerfile for local-build
- Has src/, config/, docs/, tests/ directories

### CLI Commands
- `service.sh` command module exists
- Has `cmd_service()` entry function
- Has description comment for help text

### Security
- No secrets in example descriptor
- Valid image.mode values

## Running Tests

```bash
# Via testsuite runner
python testsuite.py --module module_service

# Directly
cd module_service
python test_module_service.py
```

## Expected Results

All tests should pass for a properly configured DINS installation.
Failures indicate missing or misconfigured service infrastructure.
