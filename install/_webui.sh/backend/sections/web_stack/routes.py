"""
Web Services Stack Section Routes
Handles web service configuration (nginx, traefik, kong, etc.)
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
    group: str = "web"
    enabled: bool = True
    control_mode: str = "docker"  # Web services often docker-managed
    api_url: Optional[str] = None
    api_type: str = "rest"
    docker_service_name: Optional[str] = None
    is_primary: bool = False  # Primary reverse proxy
    notes: str = ""
    config: Dict[str, Any] = {}


class ServiceUpdate(BaseModel):
    enabled: Optional[bool] = None
    control_mode: Optional[str] = None
    api_url: Optional[str] = None
    docker_service_name: Optional[str] = None
    is_primary: Optional[bool] = None
    notes: Optional[str] = None
    config: Optional[Dict[str, Any]] = None


@router.get("/")
async def get_services():
    config = load_config()
    return config.get("services", {}).get("web", [])


@router.post("/")
async def add_service(service: Service):
    config = load_config()
    if "services" not in config:
        config["services"] = {}
    if "web" not in config["services"]:
        config["services"]["web"] = []
    config["services"]["web"].append(service.dict())
    save_config(config)
    return {"status": "added"}


@router.put("/{service_id}")
async def update_service(service_id: str, update: ServiceUpdate):
    config = load_config()
    services = config.get("services", {}).get("web", [])
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
            if update.is_primary is not None:
                service["is_primary"] = update.is_primary
            if update.notes is not None:
                service["notes"] = update.notes
            if update.config:
                service["config"] = {**service.get("config", {}), **update.config}
            break
    else:
        raise HTTPException(status_code=404, detail="Service not found")
    config["services"]["web"] = services
    save_config(config)
    return {"status": "updated"}


@router.delete("/{service_id}")
async def delete_service(service_id: str):
    config = load_config()
    services = config.get("services", {}).get("web", [])
    original_len = len(services)
    services = [s for s in services if s.get("id") != service_id]
    if len(services) == original_len:
        raise HTTPException(status_code=404, detail="Service not found")
    config["services"]["web"] = services
    save_config(config)
    return {"status": "deleted"}


@router.put("/")
async def update_all_services(services: List[Service]):
    config = load_config()
    if "services" not in config:
        config["services"] = {}
    config["services"]["web"] = [s.dict() for s in services]
    save_config(config)
    return {"status": "updated"}


@router.get("/primary")
async def get_primary_proxy():
    """Get the primary reverse proxy service"""
    config = load_config()
    services = config.get("services", {}).get("web", [])
    for service in services:
        if service.get("is_primary", False):
            return service
    return None


@router.post("/{service_id}/set-primary")
async def set_primary_proxy(service_id: str):
    """Set a service as the primary reverse proxy"""
    config = load_config()
    services = config.get("services", {}).get("web", [])
    found = False
    for service in services:
        if service.get("id") == service_id:
            service["is_primary"] = True
            found = True
        else:
            service["is_primary"] = False
    if not found:
        raise HTTPException(status_code=404, detail="Service not found")
    config["services"]["web"] = services
    save_config(config)
    return {"status": "updated"}
