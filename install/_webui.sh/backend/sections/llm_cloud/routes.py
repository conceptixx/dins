"""
LLM Cloud Providers Section Routes
Handles cloud LLM provider configuration
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import json
from pathlib import Path

router = APIRouter()

DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", "/opt/dins/config")
DINS_SECRETS_DIR = os.environ.get("DINS_SECRETS_DIR", "/opt/dins/secrets")
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


class CloudProvider(BaseModel):
    id: str
    label: str
    base_url: str
    pay_to_use: bool = True
    enabled: bool = False
    api_key_env_var: Optional[str] = None
    api_key_secret_file: Optional[str] = None
    config: Dict[str, Any] = {}


class CloudProviderUpdate(BaseModel):
    enabled: Optional[bool] = None
    api_key_env_var: Optional[str] = None
    config: Optional[Dict[str, Any]] = None


class LLMModeUpdate(BaseModel):
    mode: str  # "local_first", "cloud_only", "local_only"
    selected_cloud_provider_id: Optional[str] = None


class APIKeyRequest(BaseModel):
    api_key: str


@router.get("/")
async def get_providers():
    """Get all cloud LLM providers"""
    config = load_config()
    return config.get("llm", {}).get("cloud_providers", [])


@router.get("/selected")
async def get_selected():
    """Get current LLM mode and selected cloud provider"""
    config = load_config()
    llm = config.get("llm", {})
    return {
        "mode": llm.get("mode", "local_first"),
        "selected_cloud_provider_id": llm.get("selected_cloud_provider_id"),
        "cloud_enabled": llm.get("cloud", {}).get("enabled", False)
    }


@router.post("/mode")
async def set_mode(update: LLMModeUpdate):
    """Set LLM mode and optionally select cloud provider"""
    config = load_config()
    
    if "llm" not in config:
        config["llm"] = {}
    
    if update.mode not in ["local_first", "cloud_only", "local_only"]:
        raise HTTPException(status_code=400, detail="Invalid mode")
    
    config["llm"]["mode"] = update.mode
    
    if update.selected_cloud_provider_id:
        config["llm"]["selected_cloud_provider_id"] = update.selected_cloud_provider_id
    
    # Update cloud enabled flag based on mode
    if "cloud" not in config["llm"]:
        config["llm"]["cloud"] = {}
    config["llm"]["cloud"]["enabled"] = update.mode in ["local_first", "cloud_only"]
    
    save_config(config)
    
    return {"status": "updated"}


@router.put("/{provider_id}")
async def update_provider(provider_id: str, update: CloudProviderUpdate):
    """Update a cloud provider configuration"""
    config = load_config()
    providers = config.get("llm", {}).get("cloud_providers", [])
    
    for provider in providers:
        if provider.get("id") == provider_id:
            if update.enabled is not None:
                provider["enabled"] = update.enabled
            if update.api_key_env_var:
                provider["api_key_env_var"] = update.api_key_env_var
            if update.config:
                if "config" not in provider:
                    provider["config"] = {}
                provider["config"].update(update.config)
            break
    else:
        raise HTTPException(status_code=404, detail="Provider not found")
    
    config["llm"]["cloud_providers"] = providers
    save_config(config)
    
    return {"status": "updated"}


@router.post("/{provider_id}/api-key")
async def set_api_key(provider_id: str, request: APIKeyRequest):
    """Store API key for a cloud provider in a secret file"""
    secret_file = Path(DINS_SECRETS_DIR) / f"llm_{provider_id}_api_key"
    
    secret_file.parent.mkdir(parents=True, exist_ok=True)
    
    with open(secret_file, 'w') as f:
        f.write(request.api_key)
    
    os.chmod(secret_file, 0o600)
    
    # Update config to reference the secret file
    config = load_config()
    providers = config.get("llm", {}).get("cloud_providers", [])
    
    for provider in providers:
        if provider.get("id") == provider_id:
            provider["api_key_secret_file"] = str(secret_file)
            break
    
    config["llm"]["cloud_providers"] = providers
    save_config(config)
    
    return {"status": "stored"}


@router.post("/{provider_id}/select")
async def select_provider(provider_id: str):
    """Select a cloud provider as the default"""
    config = load_config()
    
    if "llm" not in config:
        config["llm"] = {}
    
    config["llm"]["selected_cloud_provider_id"] = provider_id
    save_config(config)
    
    return {"status": "selected", "provider_id": provider_id}
