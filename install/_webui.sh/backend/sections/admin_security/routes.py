"""
Admin & Security Section Routes
Handles admin account setup, email verification, password, and 2FA configuration
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from typing import Optional
import os
import json
from pathlib import Path

router = APIRouter()

# Configuration paths
DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", "/opt/dins/config")
DINS_SECRETS_DIR = os.environ.get("DINS_SECRETS_DIR", "/opt/dins/secrets")
CONFIG_FILE = Path(DINS_CONFIG_DIR) / "dins_config.json"


def load_config():
    """Load configuration from file"""
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE, 'r') as f:
            return json.load(f)
    return {}


def save_config(config):
    """Save configuration to file"""
    CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_FILE, 'w') as f:
        json.dump(config, f, indent=2)


# =============================================================================
# MODELS
# =============================================================================

class AdminUsernameRequest(BaseModel):
    username: str


class TwoFactorConfig(BaseModel):
    required: bool = True
    email_otp_enabled: bool = True
    totp_enabled: bool = False


class AdminStatus(BaseModel):
    username: str
    email: str
    email_verified: bool
    password_set: bool
    two_factor_required: bool
    two_factor_methods: list
    setup_complete: bool


# =============================================================================
# ROUTES
# =============================================================================

@router.get("/status")
async def get_admin_status() -> AdminStatus:
    """Get current admin setup status"""
    config = load_config()
    admin = config.get("security", {}).get("admin", {})
    
    # Check if password file exists and has content
    password_file = Path(admin.get("password_secret_file", ""))
    password_set = password_file.exists() and password_file.stat().st_size > 0
    
    two_factor = admin.get("two_factor", {})
    
    # Setup is complete when all required fields are set
    setup_complete = (
        bool(admin.get("username")) and
        bool(admin.get("email")) and
        admin.get("email_verified", False) and
        password_set and
        two_factor.get("required", False) and
        len(two_factor.get("methods", [])) > 0
    )
    
    return AdminStatus(
        username=admin.get("username", ""),
        email=admin.get("email", ""),
        email_verified=admin.get("email_verified", False),
        password_set=password_set,
        two_factor_required=two_factor.get("required", True),
        two_factor_methods=two_factor.get("methods", ["email"]),
        setup_complete=setup_complete
    )


@router.post("/username")
async def set_admin_username(request: AdminUsernameRequest):
    """Set admin username"""
    if not request.username or len(request.username) < 3:
        raise HTTPException(status_code=400, detail="Username must be at least 3 characters")
    
    config = load_config()
    if "security" not in config:
        config["security"] = {}
    if "admin" not in config["security"]:
        config["security"]["admin"] = {}
    
    config["security"]["admin"]["username"] = request.username
    save_config(config)
    
    return {"status": "updated", "username": request.username}


@router.post("/two-factor")
async def configure_two_factor(request: TwoFactorConfig):
    """Configure two-factor authentication settings"""
    config = load_config()
    
    if "security" not in config:
        config["security"] = {}
    if "admin" not in config["security"]:
        config["security"]["admin"] = {}
    if "two_factor" not in config["security"]["admin"]:
        config["security"]["admin"]["two_factor"] = {}
    
    methods = []
    if request.email_otp_enabled:
        methods.append("email")
    if request.totp_enabled:
        methods.append("totp")
    
    config["security"]["admin"]["two_factor"]["required"] = request.required
    config["security"]["admin"]["two_factor"]["methods"] = methods
    config["security"]["admin"]["two_factor"]["email_otp_enabled"] = request.email_otp_enabled
    config["security"]["admin"]["two_factor"]["totp_enabled"] = request.totp_enabled
    
    save_config(config)
    
    return {"status": "updated", "two_factor": config["security"]["admin"]["two_factor"]}


@router.get("/two-factor")
async def get_two_factor_config():
    """Get current two-factor configuration"""
    config = load_config()
    two_factor = config.get("security", {}).get("admin", {}).get("two_factor", {
        "required": True,
        "methods": ["email"],
        "email_otp_enabled": True,
        "totp_enabled": False
    })
    return two_factor
