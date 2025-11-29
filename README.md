# DINS - Distributed Intelligent Network Services

<!-- Documentation Strategy: Strategy B - Root README as main entry per PART 6.2 -->

## Overview

DINS (Distributed Intelligent Network Services) is a manifest-driven installation and runtime orchestration system for Raspberry Pi clusters. It provides a flexible, modular approach to system setup, service management, and troubleshooting.

## Quick Start

```bash
# Clone the repository
git clone https://github.com/conceptixx/dins.git
cd dins

# Run the installer
sudo ./install/setup.sh

# Check status
dinser status

# If setup was interrupted, resume it
dinser setup
```

## Documentation Index

### Installation & Setup

| Document | Description |
|----------|-------------|
| [Installation Guide](install/README.md) | Detailed installation instructions |
| [WebUI Setup](docs/DINS_WEBUI_SETUP.md) | Web interface configuration |

### Architecture & Components

| Document | Description |
|----------|-------------|
| [Installer Modules](install/_setup.sh/README.md) | Setup module documentation |
| [WebUI Backend](install/_webui.sh/backend/README.md) | API server documentation |
| [WebUI Frontend](install/_webui.sh/frontend/README.md) | Frontend documentation |

### Testing

| Document | Description |
|----------|-------------|
| [Test Suite](testsuite/README.md) | Testing framework and usage |
| [Core Tests](testsuite/module_core/README.md) | Core system validation |
| [CLI Tests](testsuite/module_cli/README.md) | CLI tool testing |
| [Web Tests](testsuite/module_web/README.md) | Web endpoint testing |

### Troubleshooting

| Command | Description |
|---------|-------------|
| `dinser check web-ui` | Diagnose WebUI issues |
| `dinser status` | View system status |
| `dinser test` | Run test suite |

---

## DINSER CLI

DINSER is the command-line interface for DINS operations:

```bash
# Core commands
dinser help              # Show help
dinser version           # Show version
dinser status            # System status
dinser setup             # Run/resume setup
dinser setup --init      # Fresh installation

# WebUI management
dinser webui up          # Start WebUI
dinser webui down        # Stop WebUI
dinser webui status      # WebUI status
dinser webui logs        # View logs

# Troubleshooting
dinser check web-ui      # Diagnose WebUI
dinser test              # Run tests
dinser test --module cli # Test specific module
```

## Repository Structure

```
dins/
├── install/                    # Installation system
│   ├── setup.sh               # Main installer
│   ├── webui.sh               # WebUI management
│   ├── _setup.sh/             # Setup modules
│   │   ├── Manifest           # Installation steps
│   │   ├── cli/               # DINSER CLI
│   │   │   ├── dinser         # Main CLI
│   │   │   └── commands/      # Modular commands
│   │   └── docker/            # Docker configs
│   └── _webui.sh/             # WebUI system
│       ├── backend/           # FastAPI server
│       ├── frontend/          # HTML/JS frontend
│       └── docker/            # Container configs
├── testsuite/                  # Test framework
│   ├── testsuite.py           # Main runner
│   ├── module_core/           # Core tests
│   ├── module_cli/            # CLI tests
│   ├── module_web/            # Web tests
│   └── ...
├── docs/                       # Documentation
├── state/                      # State tracking
└── instructions/               # AI instructions
```

## Installation Options

```bash
# Standard installation
sudo ./install/setup.sh

# Debug mode
DEBUG=1 sudo ./install/setup.sh

# Dry run (no changes)
sudo ./install/setup.sh --dry-run

# Resume after reboot
dinser setup

# Restart from beginning
dinser setup --from-beginning
```

## Setup Phases

The installation proceeds through these phases (per PART 6.1):

1. **Runtime Environment** - Packages, Python, Docker
2. **CLI Installation** - dinser available before reboot
3. **System Preparation** - Hostname, network, system tweaks
4. **Docker Swarm** - Swarm init, networks, labels
5. **Service Deployment** - Deploy DINS services
6. **Final Routine** - Cleanup, verification

If interrupted, `dinser setup` resumes from the last incomplete phase.

## Testing

```bash
# Run all tests
dinser test

# Run specific module
dinser test --module cli

# Pre-deployment validation
dinser test --pre-deployment

# List available modules
dinser test --list
```

## Troubleshooting

### WebUI not accessible

```bash
# Run diagnostics
dinser check web-ui

# This checks:
# - DNS resolution
# - Network reachability
# - Port availability
# - Docker services
# - HTTP responses
```

### View system status

```bash
dinser status
```

### Check logs

```bash
dinser webui logs
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `DEBUG` | Set to `1` for verbose output |
| `DINS_ROOT` | Override DINS base directory |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Configuration/validation error |
| 2 | Runtime error |

## Prerequisites

- Raspberry Pi OS or Debian-based Linux
- Bash 4.x+
- Docker (installed automatically)
- Python 3.x (for test suite)

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `dinser test`
4. Submit a pull request

## Support

For issues and feature requests, use the GitHub issue tracker.
