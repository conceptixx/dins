"""
Node Selection Section Routes
Handles selection and configuration of DINS nodes
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


class NodeUpdate(BaseModel):
    node_id: str
    selected: bool
    role: str = "worker"  # "worker" or "lead"


class NodeListUpdate(BaseModel):
    nodes: List[NodeUpdate]


@router.get("/")
async def get_nodes():
    """Get all discovered nodes"""
    config = load_config()
    return config.get("discovery", {}).get("nodes", [])


@router.put("/")
async def update_nodes(request: NodeListUpdate):
    """Update node selection and roles"""
    config = load_config()
    
    if "discovery" not in config:
        config["discovery"] = {}
    
    existing_nodes = config["discovery"].get("nodes", [])
    
    # Update nodes based on request
    for update in request.nodes:
        for node in existing_nodes:
            if node.get("node_id") == update.node_id:
                node["selected"] = update.selected
                node["role"] = update.role
                break
    
    config["discovery"]["nodes"] = existing_nodes
    save_config(config)
    
    return {"status": "updated", "nodes": existing_nodes}


@router.post("/{node_id}/select")
async def select_node(node_id: str, selected: bool = True):
    """Select or deselect a node"""
    config = load_config()
    nodes = config.get("discovery", {}).get("nodes", [])
    
    for node in nodes:
        if node.get("node_id") == node_id:
            node["selected"] = selected
            break
    else:
        raise HTTPException(status_code=404, detail="Node not found")
    
    config["discovery"]["nodes"] = nodes
    save_config(config)
    
    return {"status": "updated", "node_id": node_id, "selected": selected}


@router.post("/{node_id}/role")
async def set_node_role(node_id: str, role: str):
    """Set node role (worker or lead)"""
    if role not in ["worker", "lead"]:
        raise HTTPException(status_code=400, detail="Role must be 'worker' or 'lead'")
    
    config = load_config()
    nodes = config.get("discovery", {}).get("nodes", [])
    
    for node in nodes:
        if node.get("node_id") == node_id:
            node["role"] = role
            break
    else:
        raise HTTPException(status_code=404, detail="Node not found")
    
    config["discovery"]["nodes"] = nodes
    save_config(config)
    
    return {"status": "updated", "node_id": node_id, "role": role}
