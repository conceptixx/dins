# Example Service Template
# =========================

This is a template service directory demonstrating the canonical structure
required for all DINS/DINSER services per PART 9.

## Directory Structure

```
_example/
├── service.yaml     # Service descriptor (required)
├── Dockerfile       # Container build file (for local-build mode)
├── src/             # Source code
├── config/          # Default configuration templates
├── docs/            # Documentation
│   └── README.md    # This file
└── tests/           # Service-specific tests
```

## Creating a New Service

1. Copy this directory:
   ```bash
   cp -r services/_example services/my-service
   ```

2. Edit `service.yaml`:
   - Set unique `name`
   - Set appropriate `type` and `category`
   - Configure `image.mode` (local-build, remote-build, or prebuilt)
   - Define `runtime` settings (ports, volumes, environment)
   - List any `dependencies`

3. Add your code to `src/` (if using local-build)

4. Create `Dockerfile` (if using local-build)

5. Add configuration templates to `config/`

6. Write tests in `tests/`

7. Build and deploy:
   ```bash
   dinser service build my-service
   dinser service deploy my-service
   ```

## Build Modes

### local-build
- Uses local Dockerfile and source files
- Best for services developed within DINS

### remote-build
- Clones from git repository to temp directory
- Builds image, then deletes temp files
- Best for external repositories

### prebuilt
- Uses existing image from registry
- Best for third-party services

## Secrets

NEVER put secrets in:
- service.yaml
- Dockerfile
- Build arguments
- Source code

Secrets go in `/dins/system/secrets/<service-name>/` and are injected at runtime.

## Testing

Run service-specific tests:
```bash
dinser service check my-service
dinser test service
```
