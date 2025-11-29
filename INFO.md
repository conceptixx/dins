Only when this setup routine and its separation of generalized images vs. externalized configuration is implemented for all relevant services, MAY you consider the setup aspect of PART 10 – Service Library & Out-of-the-Box Integrations as complete.

### 10.15 Service setup routines (interactive configuration, externalized parameters)

You (the generator) MUST implement a **generic, consistent “service setup” mechanism** for all DINS/DINSER services.  
Goal: **every service is built as a generalized, reusable image**, and **all environment-/user-specific information is injected from outside** via DINS/DINSER at deploy time.

This section defines:

- how ports, credentials, and linked services are collected,
- where that information is stored (outside the service image),
- and how it is injected into Docker/Swarm services.

---

#### 10.15.1 Setup entry points

You MUST provide setup entry points for services:

1. **CLI**

   - Command (example):

     ```bash
     dinser service setup <service_name>
     ```

   - Behavior:
     - Interactively collects all required information for `<service_name>`.
     - Validates existing config (if any), offers to update/keep.
     - Checks for port conflicts and missing secrets.
     - Produces/updates a **service configuration file** and associated **secrets** (see 10.15.3).

2. **Web-UI**

   - Provide a “Setup” or “Configure” button per service in the Service Library.
   - Launches a step-by-step wizard equivalent to `dinser service setup`:
     - Ports → Credentials → Related services → Other parameters.
   - Changes are stored in the same config/secrets locations as the CLI setup routine.

---

#### 10.15.2 Service descriptor requirements for setup

Each `service.yaml` / `service.json` MUST declare what information the setup routine must collect.  
Add a `setup` section (example):

```yaml
setup:
  requires_ports:
    - name: http
      default: 8080
      description: "Public HTTP port for this service."
      min: 1
      max: 65535
  requires_secrets:
    - name: TAILSCALE_AUTHKEY
      description: "Auth key for Tailscale (if used)."
    - name: API_TOKEN
      description: "API token for external STT/TTS/LLM (if applicable)."
  requires_services:
    - name: vpn_backend
      category: vpn/mesh/tunnel
      description: "VPN/mesh service used to access this service (e.g. tailscale, wireguard, ...)."
    - name: web_gateway
      category: web/gateway/proxy
      description: "HTTP gateway or reverse proxy in front of this service (e.g. nginx, traefik)."
  requires_params:
    - name: LOG_LEVEL
      type: string
      default: info
      description: "Logging level (debug, info, warning, error)."
    - name: MAX_CLIENTS
      type: integer
      default: 10
      min: 1
      max: 1000
      description: "Maximum number of simultaneous clients."
```

The generator MUST:

- use `requires_ports` to drive port prompts and conflict checks,
- use `requires_secrets` to drive credential prompts,
- use `requires_services` to select linked services from the Service Catalog,
- use `requires_params` to gather additional runtime parameters.

---

#### 10.15.3 Storage of setup information (outside the Swarm service)

All information collected by `dinser service setup` MUST be stored outside the Swarm/Docker images and stacks.

You MUST implement at least the following separation:

1. **Non-secret service config**

   - Suggested path:

     - `dins/config/services/<service_name>.json` (or `.yaml`)

   - Contains:
     - Port mappings (logical names → port numbers),
     - Service references (e.g. chosen `vpn_backend`, `web_gateway`),
     - Non-sensitive parameters (`LOG_LEVEL`, `MAX_CLIENTS`, feature toggles, etc.).
   - This file MAY be versioned in Git if it does not contain environment-specific or user-private data (depending on policy), but SHOULD be treated as runtime config rather than as build artifact.

2. **Secrets**

   - MUST be stored under the secure secrets path (as defined in earlier PARTs), e.g.:

     - `dins/system/secrets/<service_name>.json`
     - or multiple per-secret files.

   - Properties:
     - Owned by `root` and/or the dedicated DINS system user.
     - No other users/groups can read these files.
     - NEVER committed to Git.
   - Each secret entry MUST be referenced via a logical name (matching `requires_secrets.name`) and used at deploy time as:
     - Docker secrets,
     - Environment variables,
     - Or mounted files (depending on service descriptor).

3. **No secrets inside images**

   - You MUST ensure:
     - Docker builds (local/remote) NEVER embed secrets.
     - All credentials are supplied only via:
       - environment variables,
       - secrets files,
       - config volumes created at deploy time.

---

#### 10.15.4 Setup workflow (ports, credentials, linked services, parameters)

The setup routine for a service MUST perform at least the following steps:

1. **Port selection and conflict check**

   - Read `requires_ports` from `service.yaml`.
   - For each required port:
     - Suggest the `default` value.
     - Scan:
       - Current DINS/DINSER config (`dins/config/services/*.json`),
       - Currently running services/stacks (if accessible),
       - to detect port conflicts.
     - If conflict detected:
       - Display which service uses the port,
       - Propose an alternative port,
       - Allow user override (explicit confirmation).

2. **Credentials (secrets) collection**

   - For each entry in `requires_secrets`:
     - Prompt user for a value (with secure input in CLI; masked in Web-UI).
     - Store it in `dins/system/secrets/<service_name>.json` under the logical name.
   - If a secret is already present:
     - Offer to keep existing value or update it.
   - NEVER display secret values back in plain text once stored.

3. **Linked services (service references)**

   - For each entry in `requires_services`:
     - Show a filtered list of available services from the Service Catalog that match the requested category.
     - Allow:
       - Selecting one existing service (e.g. `tailscale`, `wireguard`, `nordvpn` for `vpn_backend`),
       - Or “none” if optional.
   - Store the selected references in `dins/config/services/<service_name>.json`, e.g.:

     ```json
     {
       "linked_services": {
         "vpn_backend": "tailscale",
         "web_gateway": "nginx"
       }
     }
     ```

4. **Additional parameters**

   - For each entry in `requires_params`:
     - Prompt user with default, type constraints, and description.
   - Validate input based on `type`, `min`, `max`, allowed values (if defined).
   - Store in the same config file (`<service_name>.json`) under a `params` key.

---

#### 10.15.5 Build vs. deploy: generalized images, externalized runtime config

You MUST design the system such that:

1. **Image build does NOT require setup values**

   - `dinser service build <service_name>` MUST be able to:
     - Build the Docker image (local or remote) for the service,
     - Without requiring:
       - Ports,
       - Secrets,
       - Linked services,
       - or environment-specific parameters.
   - The image MUST be **generic**:
     - Accepts configuration via environment variables / config files at runtime.
     - No user-specific or cluster-specific logic is baked into the image.

2. **Deploy uses setup values**

   - `dinser service deploy <service_name>` MUST:
     - Read:
       - `dins/config/services/<service_name>.json` (non-secret config),
       - `dins/system/secrets/<service_name>.json` (secrets),
       - and applied Service Catalog metadata.
     - Construct:
       - Environment variable sets,
       - Secret injections,
       - Config files to mount,
       - Port mappings.
   - The Swarm service (or Docker stack) MUST be created with:
     - `env` entries,
     - `secrets` references,
     - `volumes` for configuration,
     - port mappings from the config file.

3. **Runtime-only injection**

   - All setup-derived values MUST be injected:
     - At **deploy** time (`docker service create`, `docker stack deploy`, etc.),
     - Or at **update** time (when reconfiguring an existing service).
   - Container images MUST remain unchanged when:
     - Changing ports,
     - Rotating secrets,
     - Switching linked services (e.g. swapping `tailscale` for `wireguard`),
     - or modifying runtime parameters.

---

#### 10.15.6 Re-running setup, validation, and tests

You MUST support **re-running the setup** and validating configurations:

1. **Re-running setup**

   - `dinser service setup <service_name>` MAY be run multiple times:
     - Existing values are used as defaults.
     - User can change ports, linked services, or parameters.
     - Secrets can be rotated.

2. **Validation before deploy**

   - `dinser service deploy <service_name>` MUST validate:
     - All required ports are defined and not conflicting (or conflict explicitly accepted).
     - All `requires_secrets` are present in the secrets store.
     - All `requires_services` are resolved to existing, known services.
   - If validation fails:
     - Deployment MUST be aborted or blocked.
     - User MUST be told to run `dinser service setup <service_name>` first.

3. **Testsuite integration**

   - Tests MUST include:
     - A scenario where:
       - A service has `requires_ports` / `requires_secrets` / `requires_services`,
       - No config is present → `deploy` fails with a clear message.
       - After running `setup` and providing values → `deploy` succeeds.
     - A scenario where port conflicts are detected and alternative ports are recommended.
   - The testsuite MAY use “dummy secrets” and in-memory configs (no real secrets) to verify behavior.

Only when this setup routine and its separation of generalized images vs. externalized configuration is implemented for all relevant services, MAY you consider the setup aspect of PART 10 – Service Library & Out-of-the-Box Integrations as complete.
