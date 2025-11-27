# DINS - Distributed Intelligent Network Services

## Overview

DINS (Distributed Intelligent Network Services) is a manifest-driven installation and runtime orchestration system. It provides a flexible, modular approach to system setup and service management.

## Components

### DINSER - DINS Execution Resolver

DINSER is the command-line interface for DINS. Once installed, it can be invoked from anywhere:

```bash
dinser setup <parameters>
dinser status
dinser help
```

## Installation

### Prerequisites

- Bash 4.x or later
- curl, wget, git, jq (for basic operations)
- Docker (for containerized services)
- Root/sudo access (for system-level operations)

### Quick Start

1. Clone the repository:
   ```bash
   git clone https://github.com/conceptixx/dins.git
   cd dins
   ```

2. Run the installer:
   ```bash
   sudo ./install/setup.sh
   ```

3. Verify installation:
   ```bash
   dinser status
   ```

### Installation Options

```bash
# Standard installation
sudo ./install/setup.sh

# Debug mode (verbose output)
DEBUG=1 sudo ./install/setup.sh

# Dry run (parse without executing)
sudo ./install/setup.sh --dry-run

# Use alternate manifest
sudo ./install/setup.sh --manifest /path/to/Manifest
```

## Repository Structure

```
dins/
├── install/
│   ├── setup.sh              # Main installer orchestrator
│   └── _setup.sh/
│       ├── Manifest          # Installation manifest
│       ├── _mkdir.sh         # Directory creation module
│       ├── _copy.sh          # File copy module
│       ├── _chmod.sh         # Permission change module
│       ├── _chuser.sh        # Owner change module
│       ├── _chgroup.sh       # Group change module
│       ├── _run_cmd.sh       # Command execution module
│       ├── _set_var.sh       # Variable setting module
│       ├── _symlink.sh       # Symlink creation module
│       ├── _template.sh      # Template processing module
│       ├── _echo.sh          # Message display module
│       ├── _validate_path.sh         # Path validator
│       ├── _validate_file.sh         # Filename validator
│       ├── _validate_chmod_mode.sh   # Permission mode validator
│       ├── _validate_boolean.sh      # Boolean validator
│       ├── _validate_string.sh       # String validator
│       ├── _validate_user.sh         # Username validator
│       ├── _validate_group.sh        # Group name validator
│       ├── _validate_regex_3_4digits.sh  # Numeric validator
│       ├── cli/
│       │   ├── dinser        # DINSER CLI executable
│       │   └── setup.sh      # DINSER setup script
│       └── docker/
│           ├── docker-compose.setup.yml  # Setup service compose
│           └── Dockerfile.setup          # Setup service Dockerfile
```

## Manifest Syntax

The Manifest file uses a custom syntax with sections, operations, and parameters.

### Comments

```
; this is a comment
# this is also a comment
```

### Sections

```
[SECTION_NAME:section_description]
```

### Operations

```
[mySection:description]
  operation_name:label
    param1="value1"
    param2="value2"
```

### Inline Parameters (Daisy-chained)

```
run_cmd:sudo:prompt="apt-get update -y"
```

### Placeholders

Placeholders use the format `{%NAME%}` and are expanded before passing to modules:

```
mkdir:create_dir
  path="{%BASE_DIR%}/scripts"
```

## Module Declaration

Each module begins with a declaration block:

```bash
# declaration
# location: {%BASE_DIR%}/scripts/system/fileinfo/_mkdir.sh
# input: PATH+
# input: MODE*=755
# validate: PATH=path
# validate: MODE=chmod_mode
# output: PATH:LAST
```

### Input Cardinality

- `.` - exactly one value required
- `*` - optional (zero or one)
- `+` - one or more required

### Validators

Validators are defined as `_validate_<ID>.sh` and referenced in declarations:

```bash
# validate: PATH=path
# validate: MODE=chmod_mode
```

## DINSER Commands

### Setup

```bash
# Initialize DINS system
dinser setup --init

# Setup CLI interface
dinser setup cli-ui

# Setup web interface
dinser setup web-ui

# Setup a specific service
dinser setup service myservice
```

### Status

```bash
# Show status
dinser status

# JSON output
dinser status --json
```

### Help

```bash
# General help
dinser help

# Command-specific help
dinser help setup
```

## Creating Custom Modules

### Function Module Template

```bash
#!/usr/bin/env bash
# declaration
# location: {%BASE_DIR%}/scripts/custom/_mymodule.sh
# input: PARAM1.
# input: PARAM2*=default
# validate: PARAM1=string
# output: RESULT:LAST

_mymodule() {
    local param1=""
    local param2="default"
    
    for arg in "$@"; do
        case "$arg" in
            PARAM1=*) param1="${arg#PARAM1=}" ;;
            PARAM2=*) param2="${arg#PARAM2=}" ;;
        esac
    done
    
    # Validation
    if [[ -z "$param1" ]]; then
        echo "ERROR: PARAM1 is required"
        return 1
    fi
    
    # Implementation
    # ...
    
    echo "RESULT=success"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _mymodule "$@"
fi
```

### Validator Module Template

```bash
#!/usr/bin/env bash
# declaration
# location: {%BASE_DIR%}/scripts/system/validate/_validate_mytype.sh
# input: VALUE.
# input: DEFAULT.*
# output: VALUE:VALIDATED

_validate_mytype() {
    local value="$1"
    local default="$2"
    
    if [[ -z "$value" ]]; then
        value="$default"
    fi
    
    # Validation logic
    if [[ ! "$value" =~ ^valid_pattern$ ]]; then
        echo "ERROR: Invalid value"
        return 1
    fi
    
    echo "$value"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    _validate_mytype "$@"
fi
```

## Exit Codes

- `0` - Success
- `1` - Configuration error (invalid parameters, missing required input)
- `2` - Runtime error (system failure, I/O, permissions)

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DINS_BASE_DIR` | Base directory for DINS installation |
| `DEBUG` | Set to `1` for debug output |
| `TMP_PATH` | Staging directory for dry-run |

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## Support

For issues and feature requests, please use the GitHub issue tracker.
