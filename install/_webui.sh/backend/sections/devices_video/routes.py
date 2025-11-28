"""
Video Devices Section Routes
Handles video device discovery and configuration
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional
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


class VideoDevice(BaseModel):
    id: str
    host: str  # node_id
    backend_id: str  # /dev/video0, etc.
    label: str
    enabled: bool = True
    resolution: str = "1920x1080"
    fps: int = 30


class VideoDeviceUpdate(BaseModel):
    enabled: bool
    label: Optional[str] = None
    resolution: Optional[str] = None
    fps: Optional[int] = None


@router.get("/")
async def get_devices():
    """Get all video devices"""
    config = load_config()
    return config.get("devices", {}).get("video", [])


@router.post("/scan")
async def scan_devices():
    """Scan for video devices"""
    config = load_config()
    
    # Stub implementation - would use v4l2-ctl --list-devices
    devices = []
    
    if "devices" not in config:
        config["devices"] = {}
    config["devices"]["video"] = devices
    save_config(config)
    
    return {"status": "completed", "devices_found": len(devices), "devices": devices}


@router.put("/{device_id}")
async def update_device(device_id: str, update: VideoDeviceUpdate):
    """Update a video device configuration"""
    config = load_config()
    devices = config.get("devices", {}).get("video", [])
    
    for device in devices:
        if device.get("id") == device_id:
            device["enabled"] = update.enabled
            if update.label:
                device["label"] = update.label
            if update.resolution:
                device["resolution"] = update.resolution
            if update.fps:
                device["fps"] = update.fps
            break
    else:
        raise HTTPException(status_code=404, detail="Device not found")
    
    config["devices"]["video"] = devices
    save_config(config)
    
    return {"status": "updated"}


@router.put("/")
async def update_all_devices(devices: List[VideoDevice]):
    """Update all video devices"""
    config = load_config()
    
    if "devices" not in config:
        config["devices"] = {}
    
    config["devices"]["video"] = [d.dict() for d in devices]
    save_config(config)
    
    return {"status": "updated"}
