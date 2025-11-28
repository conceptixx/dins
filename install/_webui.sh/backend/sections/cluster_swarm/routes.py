"""
Cluster & Swarm Setup Section Routes
Handles hostname configuration, node installation, and Docker Swarm setup
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import os
import json
import subprocess
import socket
from pathlib import Path

router = APIRouter()

# Configuration paths
DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", "/opt/dins/config")
DINS_SECRETS_DIR = os.environ.get("DINS_SECRETS_DIR", "/opt/dins/secrets")
CONFIG_FILE = Path(DINS_CONFIG_DIR) / "dins_config.json"


def load_config():
    """Load configuration from file"""
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}


def save_config(config):
    """Save configuration to file"""
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)


def run_command(cmd: List[str], check: bool = True) -> subprocess.CompletedProcess:
    """Run a shell command and return the result"""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            check=check
        )
        return result
    except subprocess.CalledProcessError as e:
        raise HTTPException(
            status_code=500,
            detail=f"Command failed: {e.stderr}"
        )


# =============================================================================
# MODELS
# =============================================================================

class HostnameRenameRequest(BaseModel):
    desired_hostname: Optional[str] = "dins-main"


class HostnameRenameResponse(BaseModel):
    status: str
    old: str
    new: str
    reboot_required: bool


class NodeHostnameEntry(BaseModel):
    node_id: str
    hostname: str
    ip: str
    final_hostname: Optional[str] = None


class NodeHostnamePlanRequest(BaseModel):
    nodes: List[NodeHostnameEntry]


class NodeInstallRequest(BaseModel):
    nodes: List[NodeHostnameEntry]


class NodeInstallProgress(BaseModel):
    node_id: str
    status: str  # connecting, running, completed, failed
    message: Optional[str] = None


class SwarmInitResponse(BaseModel):
    status: str
    manager_token: Optional[str] = None
    worker_token: Optional[str] = None
    join_command: Optional[str] = None


class SwarmJoinRequest(BaseModel):
    node_id: str
    ip: str
    role: str = "worker"


class SwarmStatus(BaseModel):
    enabled: bool
    manager_node: Optional[str] = None
    nodes: List[dict]
    is_manager: bool
    swarm_id: Optional[str] = None


class LocalHostInfo(BaseModel):
    current_hostname: str
    planned_hostname: str
    ip_addresses: List[str]
    is_dins_main: bool


# =============================================================================
# ROUTES
# =============================================================================

@router.get("/local-info")
async def get_local_host_info() -> LocalHostInfo:
    """Get information about the local host"""
    current_hostname = socket.gethostname()
    
    # Get IP addresses
    ip_addresses = []
    try:
        # Get all network interfaces
        result = run_command(["hostname", "-I"], check=False)
        if result.returncode == 0:
            ip_addresses = result.stdout.strip().split()
    except Exception:
        pass
    
    return LocalHostInfo(
        current_hostname=current_hostname,
        planned_hostname="dins-main",
        ip_addresses=ip_addresses,
        is_dins_main=(current_hostname == "dins-main")
    )


@router.post("/rename-local")
async def rename_local_hostname(request: HostnameRenameRequest) -> HostnameRenameResponse:
    """Rename the local Pi to dins-main"""
    current_hostname = socket.gethostname()
    new_hostname = request.desired_hostname or "dins-main"
    
    if current_hostname == new_hostname:
        return HostnameRenameResponse(
            status="unchanged",
            old=current_hostname,
            new=new_hostname,
            reboot_required=False
        )
    
    try:
        # Update /etc/hostname
        with open("/etc/hostname", "w") as f:
            f.write(new_hostname + "\n")
        
        # Update /etc/hosts
        with open("/etc/hosts", "r") as f:
            hosts_content = f.read()
        
        # Replace old hostname with new
        hosts_content = hosts_content.replace(current_hostname, new_hostname)
        
        # Ensure localhost entry exists
        if "127.0.1.1" not in hosts_content:
            hosts_content += f"\n127.0.1.1\t{new_hostname}\n"
        
        with open("/etc/hosts", "w") as f:
            f.write(hosts_content)
        
        # Set hostname immediately (may not take full effect until reboot)
        run_command(["hostnamectl", "set-hostname", new_hostname], check=False)
        
        return HostnameRenameResponse(
            status="changed",
            old=current_hostname,
            new=new_hostname,
            reboot_required=True
        )
        
    except PermissionError:
        raise HTTPException(
            status_code=403,
            detail="Permission denied. This operation requires root privileges."
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Failed to rename hostname: {str(e)}"
        )


@router.post("/plan-node-hostnames")
async def plan_node_hostnames(request: NodeHostnamePlanRequest) -> List[NodeHostnameEntry]:
    """Assign dins-nodeXX hostnames to selected nodes"""
    config = load_config()
    
    # Sort nodes by IP for consistent ordering
    sorted_nodes = sorted(request.nodes, key=lambda n: n.ip)
    
    result = []
    for idx, node in enumerate(sorted_nodes, start=1):
        final_hostname = f"dins-node{idx:02d}"
        
        node_entry = NodeHostnameEntry(
            node_id=node.node_id,
            hostname=node.hostname,
            ip=node.ip,
            final_hostname=final_hostname
        )
        result.append(node_entry)
    
    # Update discovery nodes in config with final hostnames
    discovery_nodes = config.get("discovery", {}).get("nodes", [])
    for node in result:
        for disc_node in discovery_nodes:
            if disc_node.get("ip") == node.ip:
                disc_node["final_hostname"] = node.final_hostname
    
    save_config(config)
    
    return result


@router.post("/install-nodes")
async def install_nodes(request: NodeInstallRequest) -> List[NodeInstallProgress]:
    """Install base DINS on selected nodes via SSH"""
    config = load_config()
    ssh_defaults = config.get("discovery", {}).get("ssh_defaults", {})
    
    username = ssh_defaults.get("username", "pi")
    password_file = ssh_defaults.get("password_secret_file", "")
    
    # Read SSH password
    password = ""
    if password_file and Path(password_file).exists():
        with open(password_file, 'r') as f:
            password = f.read().strip()
    
    results = []
    
    for node in request.nodes:
        progress = NodeInstallProgress(
            node_id=node.node_id,
            status="connecting",
            message=f"Connecting to {node.ip}..."
        )
        
        try:
            # In production, use paramiko or similar for SSH
            # For now, return a stub response
            progress.status = "completed"
            progress.message = f"Installation triggered on {node.ip} (stub)"
            
        except Exception as e:
            progress.status = "failed"
            progress.message = str(e)
        
        results.append(progress)
    
    return results


@router.post("/init-swarm")
async def init_swarm() -> SwarmInitResponse:
    """Initialize Docker Swarm on this node (dins-main)"""
    try:
        # Check if already in swarm
        result = run_command(["docker", "info", "--format", "{{.Swarm.LocalNodeState}}"], check=False)
        if result.stdout.strip() == "active":
            # Already in swarm, get tokens
            manager_token = run_command(
                ["docker", "swarm", "join-token", "-q", "manager"],
                check=False
            ).stdout.strip()
            
            worker_token = run_command(
                ["docker", "swarm", "join-token", "-q", "worker"],
                check=False
            ).stdout.strip()
            
            return SwarmInitResponse(
                status="already_initialized",
                manager_token=manager_token,
                worker_token=worker_token
            )
        
        # Initialize swarm
        result = run_command(["docker", "swarm", "init"], check=False)
        
        if result.returncode != 0:
            raise HTTPException(status_code=500, detail=f"Swarm init failed: {result.stderr}")
        
        # Get tokens
        manager_token = run_command(
            ["docker", "swarm", "join-token", "-q", "manager"],
            check=False
        ).stdout.strip()
        
        worker_token = run_command(
            ["docker", "swarm", "join-token", "-q", "worker"],
            check=False
        ).stdout.strip()
        
        # Update config
        config = load_config()
        if "cluster" not in config:
            config["cluster"] = {}
        if "swarm" not in config["cluster"]:
            config["cluster"]["swarm"] = {}
        
        config["cluster"]["swarm"]["enabled"] = True
        config["cluster"]["swarm"]["manager_node"] = "dins-main"
        
        save_config(config)
        
        return SwarmInitResponse(
            status="initialized",
            manager_token=manager_token,
            worker_token=worker_token
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/join-swarm")
async def join_swarm(request: SwarmJoinRequest):
    """Join a node to the swarm via SSH"""
    # This would use SSH to run docker swarm join on the target node
    # Stub implementation
    return {
        "status": "joined",
        "node_id": request.node_id,
        "role": request.role
    }


@router.get("/status")
async def get_swarm_status() -> SwarmStatus:
    """Get current Docker Swarm status"""
    config = load_config()
    swarm_config = config.get("cluster", {}).get("swarm", {})
    
    is_manager = False
    swarm_id = None
    nodes = []
    
    try:
        # Check swarm status
        result = run_command(["docker", "info", "--format", "{{.Swarm.LocalNodeState}}"], check=False)
        is_active = result.stdout.strip() == "active"
        
        if is_active:
            # Get node info
            result = run_command(["docker", "info", "--format", "{{.Swarm.ControlAvailable}}"], check=False)
            is_manager = result.stdout.strip().lower() == "true"
            
            result = run_command(["docker", "info", "--format", "{{.Swarm.Cluster.ID}}"], check=False)
            swarm_id = result.stdout.strip()
            
            if is_manager:
                # List nodes
                result = run_command(["docker", "node", "ls", "--format", "{{json .}}"], check=False)
                for line in result.stdout.strip().split('\n'):
                    if line:
                        try:
                            node_data = json.loads(line)
                            nodes.append(node_data)
                        except json.JSONDecodeError:
                            pass
    except Exception:
        pass
    
    return SwarmStatus(
        enabled=swarm_config.get("enabled", False),
        manager_node=swarm_config.get("manager_node"),
        nodes=nodes,
        is_manager=is_manager,
        swarm_id=swarm_id
    )
