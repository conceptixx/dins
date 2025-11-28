"""
DINS WebUI Backend - FastAPI Application
Location: /dins/install/_webui.sh/backend/app.py

Main FastAPI application that:
- Dynamically discovers and loads configuration sections
- Provides the configuration API
- Handles admin setup, discovery, and device management
"""

import os
import json
import importlib
import logging
from pathlib import Path
from typing import Any, Dict, List, Optional
from datetime import datetime
import asyncio

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import JSONResponse
from pydantic import BaseModel, EmailStr, validator
import uvicorn

# =============================================================================
# CONFIGURATION
# =============================================================================

DINS_BASE_DIR = os.environ.get("DINS_BASE_DIR", "/opt/dins")
DINS_CONFIG_DIR = os.environ.get("DINS_CONFIG_DIR", f"{DINS_BASE_DIR}/config")
DINS_SECRETS_DIR = os.environ.get("DINS_SECRETS_DIR", f"{DINS_BASE_DIR}/secrets")
DINS_WEBUI_DIR = os.environ.get("DINS_WEBUI_DIR", f"{DINS_BASE_DIR}/webui")

CONFIG_FILE = Path(DINS_CONFIG_DIR) / "dins_config.json"
SECTIONS_DIR = Path(__file__).parent / "sections"

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("dins.webui")

# =============================================================================
# DEFAULT CONFIGURATION
# =============================================================================

DEFAULT_CONFIG = {
    "version": "1.0.0",
    "instance_role": "master",
    "identity": {
        "node_id": "dins-master",
        "display_name": "DINS Master Node"
    },
    "network": {
        "http": {
            "bind_address": "0.0.0.0",
            "port": 8000,
            "base_path": "/dins"
        }
    },
    "security": {
        "admin": {
            "username": "masteradmin",
            "email": "",
            "email_verified": False,
            "password_secret_file": f"{DINS_SECRETS_DIR}/admin_password",
            "two_factor": {
                "required": True,
                "methods": ["email"],
                "email_otp_enabled": True,
                "totp_enabled": False
            }
        },
        "permissions": {
            "allow_network_scan": False,
            "allow_ssh_scan": False
        },
        "api_tokens": []
    },
    "discovery": {
        "scan_ranges": ["192.168.0.0/24"],
        "ssh_defaults": {
            "username": "pi",
            "password_secret_file": f"{DINS_SECRETS_DIR}/ssh_pi_password"
        },
        "nodes": []
    },
    "cluster": {
        "swarm": {
            "enabled": False,
            "manager_node": "dins-main",
            "nodes": [],
            "replica_policy": {
                "default_replicas": "auto",
                "exceptions": {
                    "audio": "pinned",
                    "video": "pinned",
                    "bluetooth": "pinned",
                    "wireless_access": "pinned"
                }
            }
        }
    },
    "audio": {
        "gateways": []
    },
    "stt": {
        "mode": "local",
        "selected_engine_id": "whisper_local",
        "logical_inputs": [],
        "engines": get_default_stt_engines()
    },
    "tts": {
        "engine": "opentts_local",
        "engines": get_default_tts_engines(),
        "outputs": get_default_tts_outputs()
    },
    "llm": {
        "mode": "local_first",
        "selected_cloud_provider_id": None,
        "selected_local_provider_id": "ollama",
        "cloud_providers": get_default_cloud_providers(),
        "local_providers": get_default_local_providers(),
        "local": {
            "enabled": True,
            "api_url": "http://dins-llm-server:8001/v1/chat",
            "model": "local-dins-model"
        },
        "cloud": {
            "enabled": False
        }
    },
    "devices": {
        "bluetooth": [],
        "audio": [],
        "video": [],
        "other": []
    },
    "services": {
        "audio": [],
        "enhancements": [],
        "mobile": [],
        "vpn_mesh": [],
        "web": []
    }
}


def get_default_stt_engines():
    """Return default STT engines catalog"""
    return [
        {"id": "whisper_local", "label": "Whisper (local)", "type": "local", "api_url": "http://whisper:5000/api/v1/transcribe", "languages": ["de", "en"], "realtime": True, "quality": "high", "latency_profile": "medium"},
        {"id": "vosk_local", "label": "Vosk (local)", "type": "local", "api_url": "http://vosk:2700", "languages": ["de", "en"], "realtime": True, "quality": "medium", "latency_profile": "low"},
        {"id": "coqui_stt_local", "label": "Coqui STT (local)", "type": "local", "api_url": "http://coqui-stt:5000/api", "languages": ["de", "en"], "realtime": True, "quality": "high", "latency_profile": "medium"},
        {"id": "deepspeech_local", "label": "DeepSpeech (local)", "type": "local", "api_url": "http://deepspeech:8080/stt", "languages": ["en"], "realtime": True, "quality": "medium", "latency_profile": "medium"},
        {"id": "kaldi_local", "label": "Kaldi (local)", "type": "local", "api_url": "http://kaldi:8080/stt", "languages": ["*"], "realtime": False, "quality": "high", "latency_profile": "high"},
        {"id": "google_cloud_stt", "label": "Google Cloud STT", "type": "cloud", "api_url": "https://speech.googleapis.com/v1/speech:recognize", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "azure_speech", "label": "Azure Speech Service", "type": "cloud", "api_url": "https://{region}.stt.speech.microsoft.com/speech/recognition", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "aws_transcribe", "label": "AWS Transcribe", "type": "cloud", "api_url": "https://transcribe.{region}.amazonaws.com", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "deepgram", "label": "Deepgram STT", "type": "cloud", "api_url": "https://api.deepgram.com/v1/listen", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "low", "pay_to_use": True},
        {"id": "assemblyai", "label": "AssemblyAI", "type": "cloud", "api_url": "https://api.assemblyai.com/v2", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "rev_ai", "label": "Rev AI", "type": "cloud", "api_url": "https://api.rev.ai/speechtotext/v1", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "speechmatics", "label": "Speechmatics", "type": "cloud", "api_url": "https://asr.api.speechmatics.com/v2", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "ibm_watson_stt", "label": "IBM Watson STT", "type": "cloud", "api_url": "https://api.us-south.speech-to-text.watson.cloud.ibm.com", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "nuance_dragon", "label": "Nuance Dragon Cloud", "type": "cloud", "api_url": "https://dragon.nuance.com/api/stt", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "low", "pay_to_use": True},
        {"id": "soniox", "label": "Soniox STT", "type": "cloud", "api_url": "https://api.soniox.com/v1/stt", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "low", "pay_to_use": True},
        {"id": "gladia", "label": "Gladia STT", "type": "cloud", "api_url": "https://api.gladia.io/v1/audio/text/audio-transcription", "languages": ["*"], "realtime": True, "quality": "high", "latency_profile": "medium", "pay_to_use": True},
        {"id": "openai_whisper_api", "label": "OpenAI Whisper API", "type": "cloud", "api_url": "https://api.openai.com/v1/audio/transcriptions", "languages": ["*"], "realtime": False, "quality": "high", "latency_profile": "high", "pay_to_use": True},
    ]


def get_default_tts_engines():
    """Return default TTS engines catalog"""
    return [
        {"id": "picotts_local", "label": "PicoTTS (local)", "type": "local", "api_url": None, "voices": ["en-US", "de-DE"], "quality": "basic"},
        {"id": "espeak_ng_local", "label": "eSpeak NG (local)", "type": "local", "api_url": None, "voices": ["en", "de"], "quality": "basic"},
        {"id": "coqui_tts_local", "label": "Coqui TTS (local)", "type": "local", "api_url": "http://coqui-tts:5002/api/tts", "voices": ["de_DE-thorsten-medium"], "quality": "high"},
        {"id": "opentts_local", "label": "OpenTTS (local hub)", "type": "local", "api_url": "http://opentts:5500/api/tts", "voices": ["*"], "quality": "high"},
        {"id": "mozilla_tts_local", "label": "Mozilla TTS (local)", "type": "local", "api_url": "http://mozilla-tts:5000/api/tts", "voices": ["*"], "quality": "high"},
        {"id": "gtts_wrapper", "label": "gTTS (cloud-wrapper)", "type": "cloud", "api_url": "http://gtts:5000/api/tts", "voices": ["*"], "quality": "medium", "pay_to_use": True},
        {"id": "google_cloud_tts", "label": "Google Cloud TTS", "type": "cloud", "api_url": "https://texttospeech.googleapis.com/v1/text:synthesize", "voices": ["*"], "quality": "high", "pay_to_use": True},
        {"id": "azure_tts", "label": "Azure TTS", "type": "cloud", "api_url": "https://{region}.tts.speech.microsoft.com/cognitiveservices/v1", "voices": ["*"], "quality": "high", "pay_to_use": True},
        {"id": "aws_polly", "label": "AWS Polly", "type": "cloud", "api_url": "https://polly.{region}.amazonaws.com", "voices": ["*"], "quality": "high", "pay_to_use": True},
        {"id": "elevenlabs", "label": "ElevenLabs TTS", "type": "cloud", "api_url": "https://api.elevenlabs.io/v1/text-to-speech", "voices": ["*"], "quality": "high", "pay_to_use": True},
    ]


def get_default_tts_outputs():
    """Return default TTS output targets"""
    return [
        {"id": "main_room_speaker", "label": "Main Room Speaker", "type": "local_speaker", "node_id": "dins-main", "transport": "alsa", "target_ref": "hw:0,0", "enabled": True, "priority": 100},
        {"id": "main_headphones", "label": "Main Headphones Jack", "type": "headphones", "node_id": "dins-main", "transport": "alsa", "target_ref": "hw:1,0", "enabled": False, "priority": 90},
        {"id": "node01_room_speaker", "label": "Node01 Room Speaker", "type": "node_speaker", "node_id": "dins-node01", "transport": "alsa", "target_ref": "hw:0,0", "enabled": True, "priority": 80},
        {"id": "node02_room_speaker", "label": "Node02 Room Speaker", "type": "node_speaker", "node_id": "dins-node02", "transport": "alsa", "target_ref": "hw:0,0", "enabled": False, "priority": 70},
        {"id": "bt_livingroom_speaker", "label": "Bluetooth Speaker Livingroom", "type": "bluetooth_device", "node_id": "dins-main", "transport": "bluetooth", "target_ref": "AA:BB:CC:DD:EE:FF", "enabled": True, "priority": 95},
        {"id": "bt_headphones_user1", "label": "User1 BT Headphones", "type": "bluetooth_device", "node_id": "dins-main", "transport": "bluetooth", "target_ref": "11:22:33:44:55:66", "enabled": False, "priority": 60},
        {"id": "mobile_push_user1", "label": "Mobile App User1", "type": "mobile_client", "node_id": None, "transport": "webrtc", "target_ref": "user1-device-id", "enabled": True, "priority": 85},
        {"id": "mobile_push_user2", "label": "Mobile App User2", "type": "mobile_client", "node_id": None, "transport": "webrtc", "target_ref": "user2-device-id", "enabled": False, "priority": 50},
        {"id": "browser_clients_all", "label": "All Browser Clients", "type": "browser_client", "node_id": "dins-main", "transport": "websocket", "target_ref": "/ws/tts", "enabled": True, "priority": 75},
        {"id": "audiostream_http", "label": "HTTP Audio Stream", "type": "stream", "node_id": "dins-main", "transport": "http", "target_ref": "http://audiostreamer:5000/stream", "enabled": False, "priority": 40},
        {"id": "webrtc_room", "label": "WebRTC Conference Room", "type": "stream", "node_id": "dins-main", "transport": "webrtc", "target_ref": "janus-room-1", "enabled": False, "priority": 30},
        {"id": "voip_call_default", "label": "Default VoIP Call (Asterisk)", "type": "voip_call", "node_id": "dins-main", "transport": "sip", "target_ref": "sip:1000@asterisk", "enabled": False, "priority": 20},
        {"id": "mumble_channel", "label": "Mumble Voice Channel", "type": "stream", "node_id": "dins-main", "transport": "mumble", "target_ref": "channel:general", "enabled": False, "priority": 10},
        {"id": "icecast_radio", "label": "Icecast Radio Stream", "type": "stream", "node_id": "dins-main", "transport": "http", "target_ref": "http://icecast:8000/mount", "enabled": False, "priority": 5},
        {"id": "obs_webrtc_feed", "label": "OBS WebRTC Feed", "type": "stream", "node_id": "dins-main", "transport": "webrtc", "target_ref": "obs-room", "enabled": False, "priority": 5},
        {"id": "car_audio", "label": "Car Bluetooth Audio", "type": "bluetooth_device", "node_id": "dins-node02", "transport": "bluetooth", "target_ref": "77:88:99:AA:BB:CC", "enabled": False, "priority": 50},
        {"id": "headless_debug_sink", "label": "Debug Null Sink", "type": "local_speaker", "node_id": "dins-main", "transport": "null", "target_ref": "null", "enabled": False, "priority": 1},
    ]


def get_default_cloud_providers():
    """Return default cloud LLM providers"""
    return [
        {"id": "openai", "label": "OpenAI (Chat / Realtime)", "base_url": "https://api.openai.com/v1", "pay_to_use": True},
        {"id": "anthropic", "label": "Anthropic Claude", "base_url": "https://api.anthropic.com", "pay_to_use": True},
        {"id": "google_gemini", "label": "Google Gemini", "base_url": "https://generativelanguage.googleapis.com", "pay_to_use": True},
        {"id": "azure_openai", "label": "Azure OpenAI", "base_url": "https://{resource}.openai.azure.com", "pay_to_use": True},
        {"id": "aws_bedrock", "label": "AWS Bedrock", "base_url": "https://bedrock-runtime.{region}.amazonaws.com", "pay_to_use": True},
        {"id": "cohere", "label": "Cohere", "base_url": "https://api.cohere.ai", "pay_to_use": True},
        {"id": "mistral_ai", "label": "Mistral AI", "base_url": "https://api.mistral.ai", "pay_to_use": True},
        {"id": "groq", "label": "Groq Cloud", "base_url": "https://api.groq.com/openai/v1", "pay_to_use": True},
        {"id": "perplexity", "label": "Perplexity API", "base_url": "https://api.perplexity.ai", "pay_to_use": True},
        {"id": "xai_grok", "label": "xAI Grok API", "base_url": "https://api.x.ai", "pay_to_use": True},
        {"id": "ai21", "label": "AI21 Studio", "base_url": "https://api.ai21.com/studio/v1", "pay_to_use": True},
        {"id": "together_ai", "label": "Together.ai", "base_url": "https://api.together.xyz/v1", "pay_to_use": True},
        {"id": "fireworks_ai", "label": "Fireworks.ai", "base_url": "https://api.fireworks.ai/inference/v1", "pay_to_use": True},
        {"id": "replicate", "label": "Replicate", "base_url": "https://api.replicate.com/v1", "pay_to_use": True},
        {"id": "ibm_watsonx", "label": "IBM watsonx", "base_url": "https://{region}.ml.cloud.ibm.com", "pay_to_use": True},
        {"id": "aleph_alpha", "label": "Aleph Alpha", "base_url": "https://api.aleph-alpha.com", "pay_to_use": True},
        {"id": "huggingface_ie", "label": "HF Inference Endpoints", "base_url": "https://{endpoint}.hf.space", "pay_to_use": True},
        {"id": "openrouter", "label": "OpenRouter (multi-provider)", "base_url": "https://openrouter.ai/api/v1", "pay_to_use": True},
        {"id": "deepseek", "label": "DeepSeek API", "base_url": "https://api.deepseek.com", "pay_to_use": True},
    ]


def get_default_local_providers():
    """Return default local LLM providers"""
    return [
        {"id": "llama_cpp_http", "label": "llama.cpp HTTP Server", "base_url": "http://llama-cpp:8000/v1", "openai_compatible": True},
        {"id": "ollama", "label": "Ollama", "base_url": "http://ollama:11434", "openai_compatible": False},
        {"id": "tgi", "label": "HF Text Generation Inference", "base_url": "http://tgi:8080", "openai_compatible": False},
        {"id": "textgen_webui", "label": "text-generation-webui API", "base_url": "http://textgen:5000/api/v1", "openai_compatible": False},
        {"id": "koboldcpp", "label": "KoboldCpp", "base_url": "http://koboldcpp:5001", "openai_compatible": False},
        {"id": "koboldai", "label": "KoboldAI HTTP", "base_url": "http://koboldai:5001", "openai_compatible": False},
        {"id": "vllm", "label": "vLLM Server", "base_url": "http://vllm:8000/v1", "openai_compatible": True},
        {"id": "fastchat", "label": "FastChat", "base_url": "http://fastchat:8000/v1", "openai_compatible": True},
        {"id": "lm_studio", "label": "LM Studio Server", "base_url": "http://lmstudio:1234/v1", "openai_compatible": True},
        {"id": "gpt4all_server", "label": "GPT4All Local Server", "base_url": "http://gpt4all:4891/v1", "openai_compatible": True},
        {"id": "localai", "label": "LocalAI", "base_url": "http://localai:8080/v1", "openai_compatible": True},
        {"id": "exllama_server", "label": "ExLlamaV2 Server", "base_url": "http://exllama:7000/v1", "openai_compatible": True},
        {"id": "sglang", "label": "SGLang Server", "base_url": "http://sglang:30000/v1", "openai_compatible": True},
        {"id": "tabbyapi", "label": "TabbyAPI", "base_url": "http://tabbyapi:8080/v1", "openai_compatible": True},
        {"id": "mistral_local", "label": "Mistral Local Serving", "base_url": "http://mistral-local:8000/v1", "openai_compatible": True},
        {"id": "llamaedge", "label": "LlamaEdge (WASM)", "base_url": "http://llamaedge:8080/v1", "openai_compatible": True},
        {"id": "llamafile", "label": "llamafile Server", "base_url": "http://llamafile:8080/v1", "openai_compatible": True},
        {"id": "deepspeed_mii", "label": "DeepSpeed-MII Endpoint", "base_url": "http://deepspeed-mii:5000/v1", "openai_compatible": True},
    ]


# =============================================================================
# CONFIGURATION MANAGER
# =============================================================================

class ConfigManager:
    """Manages the DINS configuration file"""
    
    def __init__(self, config_path: Path):
        self.config_path = config_path
        self._config: Dict[str, Any] = {}
        self._lock = asyncio.Lock()
    
    def load(self) -> Dict[str, Any]:
        """Load configuration from file or create default"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    self._config = json.load(f)
                logger.info(f"Loaded configuration from {self.config_path}")
            except json.JSONDecodeError as e:
                logger.error(f"Invalid JSON in config file: {e}")
                self._config = self._get_default_config()
                self.save()
        else:
            logger.info("Creating default configuration")
            self._config = self._get_default_config()
            self.save()
        
        return self._config
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Get default configuration with all catalogs populated"""
        return {
            "version": "1.0.0",
            "instance_role": "master",
            "identity": {
                "node_id": "dins-master",
                "display_name": "DINS Master Node"
            },
            "network": {
                "http": {
                    "bind_address": "0.0.0.0",
                    "port": 8000,
                    "base_path": "/dins"
                }
            },
            "security": {
                "admin": {
                    "username": "masteradmin",
                    "email": "",
                    "email_verified": False,
                    "password_secret_file": f"{DINS_SECRETS_DIR}/admin_password",
                    "two_factor": {
                        "required": True,
                        "methods": ["email"],
                        "email_otp_enabled": True,
                        "totp_enabled": False
                    }
                },
                "permissions": {
                    "allow_network_scan": False,
                    "allow_ssh_scan": False
                },
                "api_tokens": []
            },
            "discovery": {
                "scan_ranges": ["192.168.0.0/24"],
                "ssh_defaults": {
                    "username": "pi",
                    "password_secret_file": f"{DINS_SECRETS_DIR}/ssh_pi_password"
                },
                "nodes": []
            },
            "cluster": {
                "swarm": {
                    "enabled": False,
                    "manager_node": "dins-main",
                    "nodes": [],
                    "replica_policy": {
                        "default_replicas": "auto",
                        "exceptions": {
                            "audio": "pinned",
                            "video": "pinned",
                            "bluetooth": "pinned",
                            "wireless_access": "pinned"
                        }
                    }
                }
            },
            "audio": {
                "gateways": []
            },
            "stt": {
                "mode": "local",
                "selected_engine_id": "whisper_local",
                "logical_inputs": [],
                "engines": get_default_stt_engines()
            },
            "tts": {
                "engine": "opentts_local",
                "engines": get_default_tts_engines(),
                "outputs": get_default_tts_outputs()
            },
            "llm": {
                "mode": "local_first",
                "selected_cloud_provider_id": None,
                "selected_local_provider_id": "ollama",
                "cloud_providers": get_default_cloud_providers(),
                "local_providers": get_default_local_providers(),
                "local": {
                    "enabled": True,
                    "api_url": "http://dins-llm-server:8001/v1/chat",
                    "model": "local-dins-model"
                },
                "cloud": {
                    "enabled": False
                }
            },
            "devices": {
                "bluetooth": [],
                "audio": [],
                "video": [],
                "other": []
            },
            "services": {
                "audio": [],
                "enhancements": [],
                "mobile": [],
                "vpn_mesh": [],
                "web": []
            }
        }
    
    def save(self) -> None:
        """Save configuration to file atomically"""
        # Ensure directory exists
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Write to temp file first for atomic operation
        temp_path = self.config_path.with_suffix('.tmp')
        with open(temp_path, 'w') as f:
            json.dump(self._config, f, indent=2)
        
        # Atomic rename
        temp_path.rename(self.config_path)
        logger.info(f"Saved configuration to {self.config_path}")
    
    def get(self) -> Dict[str, Any]:
        """Get current configuration"""
        if not self._config:
            self.load()
        return self._config
    
    async def update(self, new_config: Dict[str, Any]) -> None:
        """Update configuration with validation"""
        async with self._lock:
            # Validate required fields
            self._validate_config(new_config)
            self._config = new_config
            self.save()
    
    def _validate_config(self, config: Dict[str, Any]) -> None:
        """Validate configuration structure"""
        # Check instance_role
        if config.get("instance_role") not in ["master", "client"]:
            raise ValueError("instance_role must be 'master' or 'client'")
        
        # Check admin username
        admin = config.get("security", {}).get("admin", {})
        if not admin.get("username"):
            raise ValueError("security.admin.username is required")
        
        # Check email format if provided
        email = admin.get("email", "")
        if email and "@" not in email:
            raise ValueError("security.admin.email must be a valid email")


# =============================================================================
# SECTION DISCOVERY
# =============================================================================

class SectionInfo(BaseModel):
    """Information about a discovered section"""
    id: str
    label: str
    order: int
    group: str
    frontend_path: str
    backend_prefix: str


class SectionManager:
    """Discovers and manages configuration sections"""
    
    def __init__(self, sections_dir: Path):
        self.sections_dir = sections_dir
        self._sections: List[SectionInfo] = []
        self._routers: Dict[str, Any] = {}
    
    def discover(self) -> List[SectionInfo]:
        """Discover all sections from the sections directory"""
        self._sections = []
        
        if not self.sections_dir.exists():
            logger.warning(f"Sections directory not found: {self.sections_dir}")
            return self._sections
        
        for section_dir in self.sections_dir.iterdir():
            if not section_dir.is_dir():
                continue
            
            section_json = section_dir / "section.json"
            if not section_json.exists():
                continue
            
            try:
                with open(section_json, 'r') as f:
                    section_data = json.load(f)
                
                section_info = SectionInfo(
                    id=section_data.get("id", section_dir.name),
                    label=section_data.get("label", section_dir.name.replace("_", " ").title()),
                    order=section_data.get("order", 999),
                    group=section_data.get("group", "other"),
                    frontend_path=section_data.get("frontend", {}).get("path", f"/sections/{section_dir.name}/page.html"),
                    backend_prefix=section_data.get("backend", {}).get("router_prefix", f"/{section_dir.name}")
                )
                self._sections.append(section_info)
                logger.info(f"Discovered section: {section_info.id}")
                
            except Exception as e:
                logger.error(f"Error loading section {section_dir.name}: {e}")
        
        # Sort by order
        self._sections.sort(key=lambda s: s.order)
        return self._sections
    
    def get_sections(self) -> List[SectionInfo]:
        """Get all discovered sections"""
        return self._sections
    
    def load_routers(self, app: FastAPI) -> None:
        """Dynamically load and include section routers"""
        for section in self._sections:
            routes_file = self.sections_dir / section.id / "routes.py"
            if not routes_file.exists():
                logger.warning(f"No routes.py for section: {section.id}")
                continue
            
            try:
                # Dynamic import
                spec = importlib.util.spec_from_file_location(
                    f"sections.{section.id}.routes",
                    routes_file
                )
                module = importlib.util.module_from_spec(spec)
                spec.loader.exec_module(module)
                
                if hasattr(module, 'router'):
                    app.include_router(
                        module.router,
                        prefix=f"/api{section.backend_prefix}",
                        tags=[section.label]
                    )
                    logger.info(f"Loaded router for section: {section.id}")
                    
            except Exception as e:
                logger.error(f"Error loading router for {section.id}: {e}")


# =============================================================================
# FASTAPI APPLICATION
# =============================================================================

app = FastAPI(
    title="DINS Setup WebUI API",
    description="Configuration API for DINS (Distributed Intelligent Network Services)",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Global instances
config_manager = ConfigManager(CONFIG_FILE)
section_manager = SectionManager(SECTIONS_DIR)

# Verification code storage (in-memory for simplicity)
verification_codes: Dict[str, str] = {}


# =============================================================================
# PYDANTIC MODELS
# =============================================================================

class HealthResponse(BaseModel):
    status: str
    timestamp: str


class EmailVerificationRequest(BaseModel):
    email: EmailStr


class EmailVerifyRequest(BaseModel):
    email: EmailStr
    code: str


class PasswordRequest(BaseModel):
    password: str


class StatusResponse(BaseModel):
    status: str


# =============================================================================
# CORE ENDPOINTS
# =============================================================================

@app.get("/api/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint"""
    return HealthResponse(
        status="ok",
        timestamp=datetime.utcnow().isoformat()
    )


@app.get("/api/config")
async def get_config():
    """Get the full configuration"""
    return config_manager.get()


@app.put("/api/config")
async def update_config(config: Dict[str, Any]):
    """Update the full configuration"""
    try:
        await config_manager.update(config)
        return {"status": "updated"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/api/ui/sections")
async def get_sections():
    """Get all discovered configuration sections"""
    sections = section_manager.get_sections()
    return [s.dict() for s in sections]


# =============================================================================
# ADMIN SETUP ENDPOINTS
# =============================================================================

@app.post("/api/setup/send-verification-email")
async def send_verification_email(request: EmailVerificationRequest):
    """Send email verification code"""
    import random
    import string
    
    # Generate 6-digit code
    code = ''.join(random.choices(string.digits, k=6))
    verification_codes[request.email] = code
    
    # In production, send actual email via SMTP
    # For development, log the code
    logger.info(f"Verification code for {request.email}: {code}")
    
    return {"status": "sent"}


@app.post("/api/setup/verify-email")
async def verify_email(request: EmailVerifyRequest):
    """Verify email with code"""
    stored_code = verification_codes.get(request.email)
    
    if not stored_code or stored_code != request.code:
        raise HTTPException(status_code=400, detail="Invalid verification code")
    
    # Update config
    config = config_manager.get()
    config["security"]["admin"]["email"] = request.email
    config["security"]["admin"]["email_verified"] = True
    await config_manager.update(config)
    
    # Remove used code
    del verification_codes[request.email]
    
    return {"status": "verified"}


@app.post("/api/setup/admin-password")
async def set_admin_password(request: PasswordRequest):
    """Set admin password (stored in secret file)"""
    config = config_manager.get()
    secret_file = Path(config["security"]["admin"]["password_secret_file"])
    
    # Ensure secrets directory exists
    secret_file.parent.mkdir(parents=True, exist_ok=True)
    
    # Write password with restricted permissions
    with open(secret_file, 'w') as f:
        f.write(request.password)
    
    # Set permissions (root:dins-system, 640)
    os.chmod(secret_file, 0o640)
    
    return {"status": "stored"}


# =============================================================================
# DISCOVERY ENDPOINTS
# =============================================================================

@app.post("/api/discovery/network")
async def discover_network():
    """Perform network scan"""
    config = config_manager.get()
    
    if not config["security"]["permissions"]["allow_network_scan"]:
        raise HTTPException(status_code=403, detail="Network scanning not permitted")
    
    # Stub implementation - would use nmap or similar in production
    scan_ranges = config["discovery"]["scan_ranges"]
    logger.info(f"Network scan requested for ranges: {scan_ranges}")
    
    # Return mock results
    return {
        "status": "completed",
        "ranges_scanned": scan_ranges,
        "hosts_found": 0
    }


@app.post("/api/discovery/ssh")
async def discover_ssh():
    """Perform SSH discovery on network hosts"""
    config = config_manager.get()
    
    if not config["security"]["permissions"]["allow_ssh_scan"]:
        raise HTTPException(status_code=403, detail="SSH scanning not permitted")
    
    # Stub implementation
    logger.info("SSH discovery requested")
    
    return {
        "status": "completed",
        "nodes_found": 0
    }


@app.get("/api/discovery/nodes")
async def get_nodes():
    """Get discovered nodes"""
    config = config_manager.get()
    return config["discovery"]["nodes"]


# =============================================================================
# DEVICE DISCOVERY ENDPOINTS
# =============================================================================

@app.post("/api/discovery/devices/bluetooth")
async def discover_bluetooth():
    """Discover Bluetooth devices"""
    config = config_manager.get()
    logger.info("Bluetooth discovery requested")
    return {"status": "completed", "devices_found": 0}


@app.get("/api/devices/bluetooth")
async def get_bluetooth_devices():
    """Get configured Bluetooth devices"""
    config = config_manager.get()
    return config["devices"]["bluetooth"]


@app.post("/api/discovery/devices/audio")
async def discover_audio():
    """Discover audio devices"""
    config = config_manager.get()
    logger.info("Audio device discovery requested")
    return {"status": "completed", "devices_found": 0}


@app.get("/api/devices/audio")
async def get_audio_devices():
    """Get configured audio devices"""
    config = config_manager.get()
    return config["devices"]["audio"]


@app.post("/api/discovery/devices/video")
async def discover_video():
    """Discover video devices"""
    config = config_manager.get()
    logger.info("Video device discovery requested")
    return {"status": "completed", "devices_found": 0}


@app.get("/api/devices/video")
async def get_video_devices():
    """Get configured video devices"""
    config = config_manager.get()
    return config["devices"]["video"]


# =============================================================================
# STARTUP EVENT
# =============================================================================

@app.on_event("startup")
async def startup_event():
    """Application startup"""
    logger.info("DINS WebUI Backend starting...")
    
    # Load configuration
    config_manager.load()
    
    # Discover sections
    section_manager.discover()
    
    # Load section routers
    section_manager.load_routers(app)
    
    logger.info("DINS WebUI Backend ready")


# =============================================================================
# MAIN
# =============================================================================

if __name__ == "__main__":
    uvicorn.run(
        "app:app",
        host="127.0.0.1",
        port=8080,
        reload=True
    )
