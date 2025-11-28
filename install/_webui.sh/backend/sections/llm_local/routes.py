"""
LLM Local Providers Section Routes
Handles local LLM provider configuration
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


class LocalProvider(BaseModel):
    id: str
    label: str
    base_url: str
    openai_compatible: bool = False
    enabled: bool = True
    model: Optional[str] = None
    config: Dict[str, Any] = {}


class LocalProviderUpdate(BaseModel):
    enabled: Optional[bool] = None
    base_url: Optional[str] = None
    model: Optional[str] = None
    config: Optional[Dict[str, Any]] = None


@router.get("/")
async def get_providers():
    """Get all local LLM providers"""
    config = load_config()
    return config.get("llm", {}).get("local_providers", [])


@router.get("/selected")
async def get_selected():
    """Get selected local provider and local config"""
    config = load_config()
    llm = config.get("llm", {})
    return {
        "selected_local_provider_id": llm.get("selected_local_provider_id"),
        "local_enabled": llm.get("local", {}).get("enabled", True),
        "local_config": llm.get("local", {})
    }


@router.post("/select")
async def select_provider(provider_id: str):
    """Select a local provider as the default"""
    config = load_config()
    
    if "llm" not in config:
        config["llm"] = {}
    
    config["llm"]["selected_local_provider_id"] = provider_id
    
    # Update local enabled flag
    if "local" not in config["llm"]:
        config["llm"]["local"] = {}
    config["llm"]["local"]["enabled"] = True
    
    save_config(config)
    
    return {"status": "selected", "provider_id": provider_id}


@router.put("/{provider_id}")
async def update_provider(provider_id: str, update: LocalProviderUpdate):
    """Update a local provider configuration"""
    config = load_config()
    providers = config.get("llm", {}).get("local_providers", [])
    
    for provider in providers:
        if provider.get("id") == provider_id:
            if update.enabled is not None:
                provider["enabled"] = update.enabled
            if update.base_url:
                provider["base_url"] = update.base_url
            if update.model:
                provider["model"] = update.model
            if update.config:
                if "config" not in provider:
                    provider["config"] = {}
                provider["config"].update(update.config)
            break
    else:
        raise HTTPException(status_code=404, detail="Provider not found")
    
    config["llm"]["local_providers"] = providers
    save_config(config)
    
    return {"status": "updated"}


@router.post("/")
async def add_provider(provider: LocalProvider):
    """Add a new local provider"""
    config = load_config()
    
    if "llm" not in config:
        config["llm"] = {}
    if "local_providers" not in config["llm"]:
        config["llm"]["local_providers"] = []
    
    config["llm"]["local_providers"].append(provider.dict())
    save_config(config)
    
    return {"status": "added"}


@router.delete("/{provider_id}")
async def delete_provider(provider_id: str):
    """Delete a local provider"""
    config = load_config()
    providers = config.get("llm", {}).get("local_providers", [])
    
    original_len = len(providers)
    providers = [p for p in providers if p.get("id") != provider_id]
    
    if len(providers) == original_len:
        raise HTTPException(status_code=404, detail="Provider not found")
    
    config["llm"]["local_providers"] = providers
    save_config(config)
    
    return {"status": "deleted"}


@router.get("/enabled")
async def get_enabled_providers():
    """Get only enabled local providers"""
    config = load_config()
    providers = config.get("llm", {}).get("local_providers", [])
    return [p for p in providers if p.get("enabled", True)]


@router.post("/{provider_id}/test")
async def test_provider(provider_id: str):
    """Test connection to a local provider"""
    config = load_config()
    providers = config.get("llm", {}).get("local_providers", [])
    
    provider = None
    for p in providers:
        if p.get("id") == provider_id:
            provider = p
            break
    
    if not provider:
        raise HTTPException(status_code=404, detail="Provider not found")
    
    # Stub implementation - would test actual connection
    return {
        "status": "tested",
        "provider_id": provider_id,
        "reachable": False,
        "message": "Connection test not implemented"
    }
