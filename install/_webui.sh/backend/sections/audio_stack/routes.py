"""
Audio Services Stack Section Routes
Handles audio service configuration (janus, jitsi, asterisk, etc.)
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
    group: str = "audio"
    enabled: bool = True
    control_mode: str = "none"  # "none", "api", "docker", "external"
    api_url: Optional[str] = None
    api_type: str = "rest"  # "rest", "websocket", "webrtc", "grpc"
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
    """Get all audio services"""
    config = load_config()
    return config.get("services", {}).get("audio", [])


@router.post("/")
async def add_service(service: Service):
    """Add a new audio service"""
    config = load_config()
    
    if "services" not in config:
        config["services"] = {}
    if "audio" not in config["services"]:
        config["services"]["audio"] = []
    
    config["services"]["audio"].append(service.dict())
    save_config(config)
    
    return {"status": "added"}


@router.put("/{service_id}")
async def update_service(service_id: str, update: ServiceUpdate):
    """Update an audio service configuration"""
    config = load_config()
    services = config.get("services", {}).get("audio", [])
    
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
                if "config" not in service:
                    service["config"] = {}
                service["config"].update(update.config)
            break
    else:
        raise HTTPException(status_code=404, detail="Service not found")
    
    config["services"]["audio"] = services
    save_config(config)
    
    return {"status": "updated"}


@router.delete("/{service_id}")
async def delete_service(service_id: str):
    """Delete an audio service"""
    config = load_config()
    services = config.get("services", {}).get("audio", [])
    
    original_len = len(services)
    services = [s for s in services if s.get("id") != service_id]
    
    if len(services) == original_len:
        raise HTTPException(status_code=404, detail="Service not found")
    
    config["services"]["audio"] = services
    save_config(config)
    
    return {"status": "deleted"}


@router.put("/")
async def update_all_services(services: List[Service]):
    """Update all audio services"""
    config = load_config()
    
    if "services" not in config:
        config["services"] = {}
    
    config["services"]["audio"] = [s.dict() for s in services]
    save_config(config)
    
    return {"status": "updated"}


@router.get("/enabled")
async def get_enabled_services():
    """Get only enabled audio services"""
    config = load_config()
    services = config.get("services", {}).get("audio", [])
    return [s for s in services if s.get("enabled", True)]
