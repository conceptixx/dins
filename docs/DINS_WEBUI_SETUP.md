# DINS WebUI Setup Documentation

## Overview

The DINS (Distributed Intelligent Network Services) Setup WebUI provides a web-based interface for configuring and managing your DINS cluster. It guides users through the initial setup process including:

- Admin account configuration with email verification and 2FA
- Network and SSH discovery of Raspberry Pi nodes
- Docker Swarm cluster initialization
- Device configuration (Bluetooth, Audio, Video)
- STT/TTS/LLM service configuration
- Service stack management

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Network access to Raspberry Pi devices (for cluster setup)
- A hostname entry for `dins-setup.local` pointing to your DINS master

### Installation

1. **Run the manifest to prepare directories:**
   ```bash
   ./install/webui.sh manifest
   ```

2. **Start the WebUI:**
   ```bash
   ./install/webui.sh up
   ```

3. **Access the WebUI:**
   Open your browser and navigate to: `http://dins-setup.local`

### Using DINSER CLI

The WebUI can also be managed through the DINSER CLI:

```bash
dinser webui manifest    # Prepare directories and configs
dinser webui up          # Start the WebUI
dinser webui down        # Stop the WebUI
dinser webui status      # Check container status
```

## Configuration

### Configuration File Location

The main configuration file is located at:
```
${DINS_CONFIG_DIR}/dins_config.json
```

Default: `/opt/dins/config/dins_config.json`

### Secret Files

Sensitive data (passwords, API keys) are stored in separate files:
```
/opt/dins/secrets/admin_password
/opt/dins/secrets/ssh_pi_password
/opt/dins/secrets/llm_*_api_key
```

These files have restricted permissions (600) and are never included in the JSON config.

### File Permissions

All DINS WebUI files are owned by `root:dins-system` with the following permissions:
- Directories: 750
- Files: 640
- Secrets: 600

## Hostname Requirement

**IMPORTANT:** The WebUI is ONLY accessible via the hostname `dins-setup.local`. 

Requests to any other hostname (including IP addresses) will be rejected with HTTP 444.

### Setting Up the Hostname

Add an entry to `/etc/hosts` on any machine that needs to access the WebUI:

```
192.168.1.50  dins-setup.local
```

Replace `192.168.1.50` with the actual IP address of your DINS master node.

## Setup Wizard Steps

### 1. Admin & Security

Configure the master admin account:
- **Username**: Set the admin username (min 3 characters)
- **Email Verification**: Enter email and verify with OTP code
- **Password**: Set a strong password (min 8 characters)
- **2FA**: Enable two-factor authentication (email OTP required)

Setup is not considered complete until all these steps are finished.

### 2. Cluster & Swarm Setup

Initialize the Docker Swarm cluster:
- **Rename Host**: Rename the current Pi to `dins-main`
- **Initialize Swarm**: Create Docker Swarm with this node as manager
- **Plan Hostnames**: Assign `dins-node01`, `dins-node02`, etc. to discovered nodes

### 3. Network & SSH Discovery

Configure network scanning:
- **Permissions**: Enable/disable network and SSH scanning
- **SSH Password**: Set the password for 'pi' user on Raspberry Pis
- **Scan Ranges**: Configure CIDR ranges to scan
- **Run Scans**: Execute network and SSH discovery

### 4. Node Selection

Select and configure discovered nodes:
- Choose which Pis will be DINS nodes
- Assign roles: `worker` or `lead`
- Install DINS on selected nodes remotely

### 5. Device Configuration

Configure discovered devices:
- **Bluetooth**: Enable/disable Bluetooth devices
- **Audio**: Configure microphones and speakers
- **Video**: Configure cameras
- **Other**: Miscellaneous devices

### 6. AI Services

#### STT (Speech-to-Text)
- **Input Config**: Configure logical microphone arrays with sync settings
- **Engines**: Select local or cloud STT engines

#### TTS (Text-to-Speech)
- **Engines**: Select TTS engine (Coqui, OpenTTS, cloud providers)
- **Outputs**: Configure audio output targets (speakers, streams, mobile)

#### LLM (Large Language Models)
- **Cloud Providers**: Configure cloud AI services (OpenAI, Anthropic, etc.)
- **Local Providers**: Configure local LLM servers (Ollama, llama.cpp, etc.)

### 7. Service Stacks

Configure service groups:
- **Audio Stack**: Janus, Jitsi, Asterisk, etc.
- **Enhancements**: STT/TTS helpers, dashboards
- **Mobile Stack**: WebRTC, mobile proxies
- **VPN/Mesh**: Tailscale, Zerotier, WireGuard
- **Web Stack**: Nginx, Traefik, Kong

## Architecture

### Modular Design

The WebUI uses a modular architecture:

**Backend Sections** (`/backend/sections/`)
- Each section has its own directory with `section.json` metadata and `routes.py`
- Sections are dynamically discovered at startup
- New sections can be added without modifying core code

**Frontend Sections** (`/frontend/sections/`)
- Each section has `page.html` and `page.js`
- Sections are loaded dynamically based on navigation
- Navigation is built from `/api/ui/sections` endpoint

### Adding New Sections

To add a new configuration section:

1. Create backend directory: `/backend/sections/my_section/`
2. Add `section.json`:
   ```json
   {
     "id": "my_section",
     "label": "My Section",
     "order": 100,
     "group": "custom",
     "frontend": {
       "path": "/sections/my_section/page.html"
     },
     "backend": {
       "router_module": "sections.my_section.routes",
       "router_prefix": "/my-section"
     }
   }
   ```
3. Add `routes.py` with FastAPI router
4. Create frontend directory: `/frontend/sections/my_section/`
5. Add `page.html` and `page.js`

## API Reference

### Core Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/config` | GET | Get full configuration |
| `/api/config` | PUT | Update configuration |
| `/api/ui/sections` | GET | Get available sections |

### Admin Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/setup/send-verification-email` | POST | Send email verification code |
| `/api/setup/verify-email` | POST | Verify email with code |
| `/api/setup/admin-password` | POST | Set admin password |
| `/api/admin/status` | GET | Get admin setup status |

### Cluster Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/cluster/local-info` | GET | Get local host info |
| `/api/cluster/rename-local` | POST | Rename to dins-main |
| `/api/cluster/init-swarm` | POST | Initialize Docker Swarm |
| `/api/cluster/status` | GET | Get swarm status |

### Discovery Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/discovery/network` | POST | Run network scan |
| `/api/discovery/ssh` | POST | Run SSH scan |
| `/api/discovery/nodes` | GET | Get discovered nodes |

## Troubleshooting

### WebUI Not Accessible

1. Check container is running: `./install/webui.sh status`
2. Verify hostname resolution: `ping dins-setup.local`
3. Check nginx logs: `docker logs dins-setup`

### Container Won't Start

1. Check for port conflicts on port 80
2. Verify Docker is running: `docker info`
3. Check disk space: `df -h`

### API Errors

1. Check backend logs: `docker logs dins-setup`
2. Verify config file permissions
3. Check secrets directory permissions

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DINS_BASE_DIR` | `/opt/dins` | Base directory |
| `DINS_CONFIG_DIR` | `/opt/dins/config` | Config directory |
| `DINS_LOG_DIR` | `/opt/dins/logs` | Log directory |
| `DINS_SECRETS_DIR` | `/opt/dins/secrets` | Secrets directory |
| `DINS_WEBUI_DIR` | `/opt/dins/webui` | WebUI files directory |

## Security Considerations

1. **Host-based Access Control**: Only `dins-setup.local` hostname is allowed
2. **Password Storage**: Passwords stored in separate files, not in JSON
3. **File Permissions**: Restricted to root:dins-system
4. **2FA Required**: Two-factor authentication mandatory for admin
5. **Secret Files**: 600 permissions on sensitive files

## Commands Reference

```bash
# WebUI management
./install/webui.sh manifest     # Prepare directories
./install/webui.sh up           # Start WebUI
./install/webui.sh down         # Stop WebUI
./install/webui.sh restart      # Restart WebUI
./install/webui.sh status       # Show status
./install/webui.sh logs         # View logs
./install/webui.sh logs -f      # Follow logs
./install/webui.sh build        # Build images
./install/webui.sh shell        # Open container shell
./install/webui.sh config-path  # Show config file path

# DINSER CLI
dinser webui manifest
dinser webui up
dinser webui down
dinser webui status
```

## Version History

- **1.0.0**: Initial release with full setup wizard
