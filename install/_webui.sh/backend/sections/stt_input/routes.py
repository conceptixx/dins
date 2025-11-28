"""
STT Input & Sync Section Routes
Handles logical microphone array configuration and synchronization
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


class AudioSource(BaseModel):
    device_ref: str
    node_id: str
    channel: int = 0
    offset_ms: int = 0


class SyncConfig(BaseModel):
    mode: str = "auto"  # "auto" or "manual"
    max_skew_ms: int = 20
    drift_correction_ms: int = 2


class BufferingConfig(BaseModel):
    frame_ms: int = 20
    jitter_buffer_ms: int = 60


class LogicalInput(BaseModel):
    id: str
    label: str
    sources: List[AudioSource] = []
    sync: SyncConfig = SyncConfig()
    buffering: BufferingConfig = BufferingConfig()


class LogicalInputUpdate(BaseModel):
    label: Optional[str] = None
    sources: Optional[List[AudioSource]] = None
    sync: Optional[SyncConfig] = None
    buffering: Optional[BufferingConfig] = None


@router.get("/")
async def get_logical_inputs():
    """Get all logical STT inputs"""
    config = load_config()
    return config.get("stt", {}).get("logical_inputs", [])


@router.post("/")
async def create_logical_input(input_config: LogicalInput):
    """Create a new logical input"""
    config = load_config()
    
    if "stt" not in config:
        config["stt"] = {}
    if "logical_inputs" not in config["stt"]:
        config["stt"]["logical_inputs"] = []
    
    config["stt"]["logical_inputs"].append(input_config.dict())
    save_config(config)
    
    return {"status": "created", "input": input_config.dict()}


@router.put("/{input_id}")
async def update_logical_input(input_id: str, update: LogicalInputUpdate):
    """Update a logical input configuration"""
    config = load_config()
    inputs = config.get("stt", {}).get("logical_inputs", [])
    
    for inp in inputs:
        if inp.get("id") == input_id:
            if update.label:
                inp["label"] = update.label
            if update.sources is not None:
                inp["sources"] = [s.dict() for s in update.sources]
            if update.sync:
                inp["sync"] = update.sync.dict()
            if update.buffering:
                inp["buffering"] = update.buffering.dict()
            break
    else:
        raise HTTPException(status_code=404, detail="Logical input not found")
    
    config["stt"]["logical_inputs"] = inputs
    save_config(config)
    
    return {"status": "updated"}


@router.delete("/{input_id}")
async def delete_logical_input(input_id: str):
    """Delete a logical input"""
    config = load_config()
    inputs = config.get("stt", {}).get("logical_inputs", [])
    
    original_len = len(inputs)
    inputs = [i for i in inputs if i.get("id") != input_id]
    
    if len(inputs) == original_len:
        raise HTTPException(status_code=404, detail="Logical input not found")
    
    config["stt"]["logical_inputs"] = inputs
    save_config(config)
    
    return {"status": "deleted"}


@router.post("/{input_id}/sources")
async def add_source(input_id: str, source: AudioSource):
    """Add a source to a logical input"""
    config = load_config()
    inputs = config.get("stt", {}).get("logical_inputs", [])
    
    for inp in inputs:
        if inp.get("id") == input_id:
            if "sources" not in inp:
                inp["sources"] = []
            inp["sources"].append(source.dict())
            break
    else:
        raise HTTPException(status_code=404, detail="Logical input not found")
    
    config["stt"]["logical_inputs"] = inputs
    save_config(config)
    
    return {"status": "added"}


@router.put("/{input_id}/sync")
async def update_sync(input_id: str, sync: SyncConfig):
    """Update sync configuration for a logical input"""
    config = load_config()
    inputs = config.get("stt", {}).get("logical_inputs", [])
    
    for inp in inputs:
        if inp.get("id") == input_id:
            inp["sync"] = sync.dict()
            break
    else:
        raise HTTPException(status_code=404, detail="Logical input not found")
    
    config["stt"]["logical_inputs"] = inputs
    save_config(config)
    
    return {"status": "updated"}
