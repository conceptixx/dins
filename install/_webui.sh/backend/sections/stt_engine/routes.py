"""
STT Engines Section Routes
Handles STT engine selection and configuration
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


class STTEngine(BaseModel):
    id: str
    label: str
    type: str  # "local" or "cloud"
    api_url: Optional[str] = None
    languages: List[str] = []
    realtime: bool = True
    quality: str = "medium"
    latency_profile: str = "medium"
    pay_to_use: bool = False
    enabled: bool = True


class STTModeUpdate(BaseModel):
    mode: str  # "local", "cloud", "hybrid"
    selected_engine_id: Optional[str] = None


@router.get("/")
async def get_engines():
    """Get all STT engines"""
    config = load_config()
    return config.get("stt", {}).get("engines", [])


@router.get("/selected")
async def get_selected():
    """Get current STT mode and selected engine"""
    config = load_config()
    stt = config.get("stt", {})
    return {
        "mode": stt.get("mode", "local"),
        "selected_engine_id": stt.get("selected_engine_id")
    }


@router.post("/select")
async def select_engine(update: STTModeUpdate):
    """Set STT mode and select engine"""
    config = load_config()
    
    if "stt" not in config:
        config["stt"] = {}
    
    if update.mode not in ["local", "cloud", "hybrid"]:
        raise HTTPException(status_code=400, detail="Invalid mode")
    
    config["stt"]["mode"] = update.mode
    if update.selected_engine_id:
        config["stt"]["selected_engine_id"] = update.selected_engine_id
    
    save_config(config)
    
    return {"status": "updated", "mode": update.mode, "selected_engine_id": update.selected_engine_id}


@router.put("/{engine_id}")
async def update_engine(engine_id: str, engine: STTEngine):
    """Update an STT engine configuration"""
    config = load_config()
    engines = config.get("stt", {}).get("engines", [])
    
    found = False
    for i, eng in enumerate(engines):
        if eng.get("id") == engine_id:
            engines[i] = engine.dict()
            found = True
            break
    
    if not found:
        # Add new engine
        engines.append(engine.dict())
    
    if "stt" not in config:
        config["stt"] = {}
    config["stt"]["engines"] = engines
    save_config(config)
    
    return {"status": "updated"}


@router.delete("/{engine_id}")
async def delete_engine(engine_id: str):
    """Delete an STT engine"""
    config = load_config()
    engines = config.get("stt", {}).get("engines", [])
    
    original_len = len(engines)
    engines = [e for e in engines if e.get("id") != engine_id]
    
    if len(engines) == original_len:
        raise HTTPException(status_code=404, detail="Engine not found")
    
    config["stt"]["engines"] = engines
    save_config(config)
    
    return {"status": "deleted"}


@router.get("/local")
async def get_local_engines():
    """Get only local STT engines"""
    config = load_config()
    engines = config.get("stt", {}).get("engines", [])
    return [e for e in engines if e.get("type") == "local"]


@router.get("/cloud")
async def get_cloud_engines():
    """Get only cloud STT engines"""
    config = load_config()
    engines = config.get("stt", {}).get("engines", [])
    return [e for e in engines if e.get("type") == "cloud"]
