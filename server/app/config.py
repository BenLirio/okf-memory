"""Environment-driven configuration for the okf-memory server."""

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parent.parent / ".env")

MEMORIES_DIR = Path(os.environ.get("MEMORIES_DIR", str(Path.home() / "memories-okf")))
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
API_TOKEN = os.environ.get("API_TOKEN", "")

# Model choices. GPT-5.6 Sol is the frontier tier; Whisper per explicit requirement.
GENERATION_MODEL = os.environ.get("GENERATION_MODEL", "gpt-5.6-sol")
STT_MODEL = os.environ.get("STT_MODEL", "whisper-1")
TTS_MODEL = os.environ.get("TTS_MODEL", "gpt-4o-mini-tts")
TTS_VOICE = os.environ.get("TTS_VOICE", "marin")

TIMEZONE = os.environ.get("TIMEZONE", "America/New_York")
GIT_PUSH_ENABLED = os.environ.get("GIT_PUSH_ENABLED", "1") == "1"

AGENT_ACTOR = f"recall-agent/{GENERATION_MODEL}"
