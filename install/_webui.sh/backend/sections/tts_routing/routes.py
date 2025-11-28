"""
TTS & Audio Output Section Routes
Handles TTS engine selection and audio output routing
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


class TTSEngine(BaseModel):
    id: str
    label: str
    type: str  # "local" or "cloud"
    api_url: Optional[str] = None
    voices: List[str] = []
    quality: str = "medium"
    pay_to_use: bool = False


class TTSOutput(BaseModel):
    id: str
    label: str
    type: str  # local_speaker, headphones, bluetooth_device, mobile_client, etc.
    node_id: Optional[str] = None
    transport: str  # alsa, bluetooth, webrtc, websocket, http, sip, etc.
    target_ref: str
    enabled: bool = True
    priority: int = 50


class TTSOutputUpdate(BaseModel):
    enabled: Optional[bool] = None
    label: Optional[str] = None
    priority: Optional[int] = None


@router.get("/engines")
async def get_engines():
    """Get all TTS engines"""
    config = load_config()
    return config.get("tts", {}).get("engines", [])


@router.get("/selected-engine")
async def get_selected_engine():
    """Get currently selected TTS engine"""
    config = load_config()
    return {"engine": config.get("tts", {}).get("engine")}


@router.post("/select-engine")
async def select_engine(engine_id: str):
    """Select TTS engine"""
    config = load_config()
    
    if "tts" not in config:
        config["tts"] = {}
    
    config["tts"]["engine"] = engine_id
    save_config(config)
    
    return {"status": "updated", "engine": engine_id}


@router.get("/outputs")
async def get_outputs():
    """Get all TTS output targets"""
    config = load_config()
    return config.get("tts", {}).get("outputs", [])


@router.put("/outputs/{output_id}")
async def update_output(output_id: str, update: TTSOutputUpdate):
    """Update a TTS output configuration"""
    config = load_config()
    outputs = config.get("tts", {}).get("outputs", [])
    
    for output in outputs:
        if output.get("id") == output_id:
            if update.enabled is not None:
                output["enabled"] = update.enabled
            if update.label:
                output["label"] = update.label
            if update.priority is not None:
                output["priority"] = update.priority
            break
    else:
        raise HTTPException(status_code=404, detail="Output not found")
    
    config["tts"]["outputs"] = outputs
    save_config(config)
    
    return {"status": "updated"}


@router.put("/outputs")
async def update_all_outputs(outputs: List[TTSOutput]):
    """Update all TTS outputs"""
    config = load_config()
    
    if "tts" not in config:
        config["tts"] = {}
    
    config["tts"]["outputs"] = [o.dict() for o in outputs]
    save_config(config)
    
    return {"status": "updated"}


@router.post("/outputs")
async def add_output(output: TTSOutput):
    """Add a new TTS output"""
    config = load_config()
    
    if "tts" not in config:
        config["tts"] = {}
    if "outputs" not in config["tts"]:
        config["tts"]["outputs"] = []
    
    config["tts"]["outputs"].append(output.dict())
    save_config(config)
    
    return {"status": "added"}


@router.delete("/outputs/{output_id}")
async def delete_output(output_id: str):
    """Delete a TTS output"""
    config = load_config()
    outputs = config.get("tts", {}).get("outputs", [])
    
    original_len = len(outputs)
    outputs = [o for o in outputs if o.get("id") != output_id]
    
    if len(outputs) == original_len:
        raise HTTPException(status_code=404, detail="Output not found")
    
    config["tts"]["outputs"] = outputs
    save_config(config)
    
    return {"status": "deleted"}


@router.get("/outputs/enabled")
async def get_enabled_outputs():
    """Get only enabled outputs, sorted by priority"""
    config = load_config()
    outputs = config.get("tts", {}).get("outputs", [])
    enabled = [o for o in outputs if o.get("enabled", True)]
    return sorted(enabled, key=lambda x: x.get("priority", 50), reverse=True)
