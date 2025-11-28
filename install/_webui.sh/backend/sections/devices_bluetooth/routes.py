"""
Bluetooth Devices Section Routes
Handles Bluetooth device discovery and configuration
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


class BluetoothDevice(BaseModel):
    id: str
    name: str
    address: str
    reachable_by: List[str] = []
    enabled: bool = True
    label: Optional[str] = None


class BluetoothDeviceUpdate(BaseModel):
    enabled: bool
    label: Optional[str] = None


@router.get("/")
async def get_devices():
    """Get all Bluetooth devices"""
    config = load_config()
    return config.get("devices", {}).get("bluetooth", [])


@router.post("/scan")
async def scan_devices():
    """Scan for Bluetooth devices"""
    config = load_config()
    
    # Stub implementation - would use bluetoothctl or similar
    devices = []
    
    # Update config
    if "devices" not in config:
        config["devices"] = {}
    config["devices"]["bluetooth"] = devices
    save_config(config)
    
    return {"status": "completed", "devices_found": len(devices), "devices": devices}


@router.put("/{device_id}")
async def update_device(device_id: str, update: BluetoothDeviceUpdate):
    """Update a Bluetooth device configuration"""
    config = load_config()
    devices = config.get("devices", {}).get("bluetooth", [])
    
    for device in devices:
        if device.get("id") == device_id:
            device["enabled"] = update.enabled
            if update.label:
                device["label"] = update.label
            break
    else:
        raise HTTPException(status_code=404, detail="Device not found")
    
    config["devices"]["bluetooth"] = devices
    save_config(config)
    
    return {"status": "updated"}


@router.put("/")
async def update_all_devices(devices: List[BluetoothDevice]):
    """Update all Bluetooth devices"""
    config = load_config()
    
    if "devices" not in config:
        config["devices"] = {}
    
    config["devices"]["bluetooth"] = [d.dict() for d in devices]
    save_config(config)
    
    return {"status": "updated"}
