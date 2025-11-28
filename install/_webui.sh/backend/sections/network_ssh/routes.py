"""
Network & SSH Discovery Section Routes
Handles network scanning permissions and SSH discovery for Raspberry Pis
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import os
import json
import subprocess
from pathlib import Path

router = APIRouter()

DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", "/opt/dins/config")
DINS_SECRETS_DIR = os.environ.get("DINS_SECRETS_DIR", "/opt/dins/secrets")
CONFIG_FILE = Path(DINS_CONFIG_DIR) / "dins_config.json"


def load_config():
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}


def save_config(config):
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)


class PermissionsUpdate(BaseModel):
    allow_network_scan: bool
    allow_ssh_scan: bool


class ScanRangesUpdate(BaseModel):
    scan_ranges: List[str]


class SSHPasswordRequest(BaseModel):
    password: str


class NetworkScanResult(BaseModel):
    status: str
    ranges_scanned: List[str]
    hosts_found: int
    hosts: List[dict]


class SSHScanResult(BaseModel):
    status: str
    nodes_found: int
    nodes: List[dict]


@router.get("/permissions")
async def get_permissions():
    """Get current network/SSH scan permissions"""
    config = load_config()
    permissions = config.get("security", {}).get("permissions", {})
    return {
        "allow_network_scan": permissions.get("allow_network_scan", False),
        "allow_ssh_scan": permissions.get("allow_ssh_scan", False)
    }


@router.post("/permissions")
async def update_permissions(request: PermissionsUpdate):
    """Update network/SSH scan permissions"""
    config = load_config()
    
    if "security" not in config:
        config["security"] = {}
    if "permissions" not in config["security"]:
        config["security"]["permissions"] = {}
    
    config["security"]["permissions"]["allow_network_scan"] = request.allow_network_scan
    config["security"]["permissions"]["allow_ssh_scan"] = request.allow_ssh_scan
    
    save_config(config)
    return {"status": "updated"}


@router.get("/scan-ranges")
async def get_scan_ranges():
    """Get configured scan ranges"""
    config = load_config()
    return {
        "scan_ranges": config.get("discovery", {}).get("scan_ranges", ["192.168.0.0/24"])
    }


@router.post("/scan-ranges")
async def update_scan_ranges(request: ScanRangesUpdate):
    """Update scan ranges"""
    config = load_config()
    
    if "discovery" not in config:
        config["discovery"] = {}
    
    config["discovery"]["scan_ranges"] = request.scan_ranges
    save_config(config)
    
    return {"status": "updated", "scan_ranges": request.scan_ranges}


@router.post("/ssh-password")
async def set_ssh_password(request: SSHPasswordRequest):
    """Set the SSH password for Pi user discovery"""
    config = load_config()
    ssh_defaults = config.get("discovery", {}).get("ssh_defaults", {})
    secret_file = Path(ssh_defaults.get("password_secret_file", f"{DINS_SECRETS_DIR}/ssh_pi_password"))
    
    # Ensure secrets directory exists
    secret_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Write password with restricted permissions
    with open(secret_file, 'w') as f:
        f.write(request.password)
    
    os.chmod(secret_file, 0o600)
    
    return {"status": "stored"}


@router.post("/scan")
async def run_network_scan() -> NetworkScanResult:
    """Run network scan"""
    config = load_config()
    
    if not config.get("security", {}).get("permissions", {}).get("allow_network_scan", False):
        raise HTTPException(status_code=403, detail="Network scanning not permitted")
    
    scan_ranges = config.get("discovery", {}).get("scan_ranges", ["192.168.0.0/24"])
    
    # Stub implementation - in production use nmap or arp-scan
    hosts = []
    
    # Simple arp-scan attempt
    try:
        for range_cidr in scan_ranges:
            result = subprocess.run(
                ["arp-scan", "--localnet", "-q"],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                for line in result.stdout.strip().split('\n'):
                    parts = line.split('\t')
                    if len(parts) >= 2:
                        hosts.append({
                            "ip": parts[0],
                            "mac": parts[1] if len(parts) > 1 else "",
                            "hostname": ""
                        })
    except Exception as e:
        # Fallback: return empty results
        pass
    
    return NetworkScanResult(
        status="completed",
        ranges_scanned=scan_ranges,
        hosts_found=len(hosts),
        hosts=hosts
    )


@router.post("/ssh-scan")
async def run_ssh_scan() -> SSHScanResult:
    """Run SSH scan to discover Raspberry Pis"""
    config = load_config()
    
    if not config.get("security", {}).get("permissions", {}).get("allow_ssh_scan", False):
        raise HTTPException(status_code=403, detail="SSH scanning not permitted")
    
    ssh_defaults = config.get("discovery", {}).get("ssh_defaults", {})
    username = ssh_defaults.get("username", "pi")
    
    # Get password from secret file
    password_file = Path(ssh_defaults.get("password_secret_file", ""))
    if not password_file.exists():
        raise HTTPException(status_code=400, detail="SSH password not configured")
    
    # Stub implementation
    nodes = []
    
    # Update config with discovered nodes
    if "discovery" not in config:
        config["discovery"] = {}
    config["discovery"]["nodes"] = nodes
    save_config(config)
    
    return SSHScanResult(
        status="completed",
        nodes_found=len(nodes),
        nodes=nodes
    )
