"""
Audio Devices Section Routes
Handles audio device discovery and configuration
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


class AudioDevice(BaseModel):
    id: str
    host: str  # node_id
    type: str  # "mic", "array", "speaker"
    backend_id: str  # driver/device ID
    label: str
    enabled: bool = True
    channels: int = 1
    sample_rate: int = 16000


class AudioDeviceUpdate(BaseModel):
    enabled: bool
    label: Optional[str] = None
    channels: Optional[int] = None
    sample_rate: Optional[int] = None


@router.get("/")
async def get_devices():
    """Get all audio devices"""
    config = load_config()
    return config.get("devices", {}).get("audio", [])


@router.post("/scan")
async def scan_devices():
    """Scan for audio devices"""
    config = load_config()
    
    # Stub implementation - would use arecord -l or similar
    devices = []
    
    if "devices" not in config:
        config["devices"] = {}
    config["devices"]["audio"] = devices
    save_config(config)
    
    return {"status": "completed", "devices_found": len(devices), "devices": devices}


@router.put("/{device_id}")
async def update_device(device_id: str, update: AudioDeviceUpdate):
    """Update an audio device configuration"""
    config = load_config()
    devices = config.get("devices", {}).get("audio", [])
    
    for device in devices:
        if device.get("id") == device_id:
            device["enabled"] = update.enabled
            if update.label:
                device["label"] = update.label
            if update.channels:
                device["channels"] = update.channels
            if update.sample_rate:
                device["sample_rate"] = update.sample_rate
            break
    else:
        raise HTTPException(status_code=404, detail="Device not found")
    
    config["devices"]["audio"] = devices
    save_config(config)
    
    return {"status": "updated"}


@router.put("/")
async def update_all_devices(devices: List[AudioDevice]):
    """Update all audio devices"""
    config = load_config()
    
    if "devices" not in config:
        config["devices"] = {}
    
    config["devices"]["audio"] = [d.dict() for d in devices]
    save_config(config)
    
    return {"status": "updated"}
