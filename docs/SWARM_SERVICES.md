# DINS Swarm Service Construction

This document describes how DINS/DINSER builds and deploys Docker Swarm services.

## Overview

DINS uses a declarative service model where each service is defined in a `service.yaml` 
descriptor file. Services can be built from local files, remote repositories, or use 
prebuilt images from registries.

## Directory Structure

```
dins/
├── services/               # Service definitions
│   ├── _example/          # Template service
│   │   ├── service.yaml   # Service descriptor
│   │   ├── Dockerfile     # Build file
│   │   ├── src/           # Source code
│   │   ├── config/        # Config templates
│   │   ├── docs/          # Documentation
│   │   └── tests/         # Service tests
│   └── my-service/        # Your service
│
├── config/                 # Runtime configuration (non-secret)
├── swarm/                  # Generated stack files
├── system/
│   └── secrets/           # Secret storage (never in git)
└── logs/                   # Service logs
```

## Creating a Service

1. **Copy the template:**
   ```bash
   cp -r services/_example services/my-service
   ```

2. **Edit service.yaml:**
   ```yaml
   name: my-service
   description: My custom service
   type: core
   version: 1.0.0
   
   image:
     mode: local-build  # or remote-build, prebuilt
   
   runtime:
     replicas: 1
     ports:
       - target: 8080
         published: 8080
   ```

3. **Build the image:**
   ```bash
   dinser service build my-service
   ```

4. **Deploy to swarm:**
   ```bash
   dinser service deploy my-service
   ```

## Build Modes

### local-build
Uses local Dockerfile and source files from the service directory.

```yaml
image:
  mode: local-build

build:
  context: .
  dockerfile: Dockerfile
```

### remote-build
Clones from a git repository, builds, then deletes the temp files.

```yaml
image:
  mode: remote-build

source:
  repo_url: https://github.com/org/repo.git
  ref: main

build:
  context: .
  dockerfile: Dockerfile
```

### prebuilt
Uses an existing image from a container registry.

```yaml
image:
  mode: prebuilt
  registry: docker.io
  name: myorg/myservice
  tag: 1.0.0
```

## CLI Commands

| Command | Description |
|---------|-------------|
| `dinser service list` | List all services |
| `dinser service info <n>` | Show service details |
| `dinser service build <n>` | Build service image |
| `dinser service deploy <n>` | Deploy to swarm |
| `dinser service remove <n>` | Remove from swarm |
| `dinser service logs <n>` | View service logs |
| `dinser service status <n>` | Check deployment status |
| `dinser service check <n>` | Run diagnostics |

## Web-UI

The Web-UI at `dins-setup.local` includes a Services section where you can:
- View all defined services
- Build images
- Deploy/remove services
- View logs
- Run diagnostics

## Secrets

**NEVER** put secrets in:
- service.yaml
- Dockerfile
- Build arguments
- Source code

Secrets go in `/dins/system/secrets/` and are injected at runtime via:
- Environment variables
- Mounted volumes
- Docker secrets

## Testing

Run service tests:
```bash
dinser test service
# or
python testsuite/testsuite.py --module module_service
```

## Further Reading

- [DINS-PERSISTANT-RULES.md](../instructions/DINS-PERSISTANT-RULES.md) - Golden Rules
- [PART 9 Specification](../instructions/PART_9_DINS_SWARM_SERVICE_CONSTRUCTION.md)
