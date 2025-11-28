"""
Other Devices Section Routes
Handles miscellaneous device configuration
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Any, Dict
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


class OtherDevice(BaseModel):
    id: str
    host: str
    type: str
    label: str
    enabled: bool = True
    config: Dict[str, Any] = {}


class OtherDeviceUpdate(BaseModel):
    enabled: bool
    label: Optional[str] = None
    config: Optional[Dict[str, Any]] = None


@router.get("/")
async def get_devices():
    """Get all other devices"""
    config = load_config()
    return config.get("devices", {}).get("other", [])


@router.post("/")
async def add_device(device: OtherDevice):
    """Add a new device"""
    config = load_config()
    
    if "devices" not in config:
        config["devices"] = {}
    if "other" not in config["devices"]:
        config["devices"]["other"] = []
    
    config["devices"]["other"].append(device.dict())
    save_config(config)
    
    return {"status": "added", "device": device.dict()}


@router.put("/{device_id}")
async def update_device(device_id: str, update: OtherDeviceUpdate):
    """Update a device configuration"""
    config = load_config()
    devices = config.get("devices", {}).get("other", [])
    
    for device in devices:
        if device.get("id") == device_id:
            device["enabled"] = update.enabled
            if update.label:
                device["label"] = update.label
            if update.config:
                device["config"] = update.config
            break
    else:
        raise HTTPException(status_code=404, detail="Device not found")
    
    config["devices"]["other"] = devices
    save_config(config)
    
    return {"status": "updated"}


@router.delete("/{device_id}")
async def delete_device(device_id: str):
    """Delete a device"""
    config = load_config()
    devices = config.get("devices", {}).get("other", [])
    
    original_len = len(devices)
    devices = [d for d in devices if d.get("id") != device_id]
    
    if len(devices) == original_len:
        raise HTTPException(status_code=404, detail="Device not found")
    
    config["devices"]["other"] = devices
    save_config(config)
    
    return {"status": "deleted"}


@router.put("/")
async def update_all_devices(devices: List[OtherDevice]):
    """Update all other devices"""
    config = load_config()
    
    if "devices" not in config:
        config["devices"] = {}
    
    config["devices"]["other"] = [d.dict() for d in devices]
    save_config(config)
    
    return {"status": "updated"}
