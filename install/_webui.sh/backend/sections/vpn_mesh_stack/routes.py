"""
VPN & Mesh Network Services Stack Section Routes
Handles VPN/mesh service configuration (Tailscale, Zerotier, WireGuard, etc.)
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import json
from pathlib import Path

router = APIRouter()

DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", "/opt/dins/config")
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


class Service(BaseModel):
    id: str
    label: str
    group: str = "vpn_mesh"
    enabled: bool = True
    control_mode: str = "external"  # VPN services often external
    api_url: Optional[str] = None
    api_type: str = "rest"
    docker_service_name: Optional[str] = None
    notes: str = ""
    config: Dict[str, Any] = {}


class ServiceUpdate(BaseModel):
    enabled: Optional[bool] = None
    control_mode: Optional[str] = None
    api_url: Optional[str] = None
    docker_service_name: Optional[str] = None
    notes: Optional[str] = None
    config: Optional[Dict[str, Any]] = None


@router.get("/")
async def get_services():
    config = load_config()
    return config.get("services", {}).get("vpn_mesh", [])


@router.post("/")
async def add_service(service: Service):
    config = load_config()
    if "services" not in config:
        config["services"] = {}
    if "vpn_mesh" not in config["services"]:
        config["services"]["vpn_mesh"] = []
    config["services"]["vpn_mesh"].append(service.dict())
    save_config(config)
    return {"status": "added"}


@router.put("/{service_id}")
async def update_service(service_id: str, update: ServiceUpdate):
    config = load_config()
    services = config.get("services", {}).get("vpn_mesh", [])
    for service in services:
        if service.get("id") == service_id:
            if update.enabled is not None:
                service["enabled"] = update.enabled
            if update.control_mode:
                service["control_mode"] = update.control_mode
            if update.api_url:
                service["api_url"] = update.api_url
            if update.docker_service_name:
                service["docker_service_name"] = update.docker_service_name
            if update.notes is not None:
                service["notes"] = update.notes
            if update.config:
                service["config"] = {**service.get("config", {}), **update.config}
            break
    else:
        raise HTTPException(status_code=404, detail="Service not found")
    config["services"]["vpn_mesh"] = services
    save_config(config)
    return {"status": "updated"}


@router.delete("/{service_id}")
async def delete_service(service_id: str):
    config = load_config()
    services = config.get("services", {}).get("vpn_mesh", [])
    original_len = len(services)
    services = [s for s in services if s.get("id") != service_id]
    if len(services) == original_len:
        raise HTTPException(status_code=404, detail="Service not found")
    config["services"]["vpn_mesh"] = services
    save_config(config)
    return {"status": "deleted"}


@router.put("/")
async def update_all_services(services: List[Service]):
    config = load_config()
    if "services" not in config:
        config["services"] = {}
    config["services"]["vpn_mesh"] = [s.dict() for s in services]
    save_config(config)
    return {"status": "updated"}
