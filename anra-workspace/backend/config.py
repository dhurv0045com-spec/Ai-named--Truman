import os
from dotenv import load_dotenv

load_dotenv()

OR_API_KEY = os.getenv("OR_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY")
AI_PROVIDER = os.getenv("AI_PROVIDER", "openrouter").strip().lower()
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./anra.db")
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "anthropic/claude-3.5-haiku")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

cors_origins_raw = os.getenv("CORS_ALLOW_ORIGINS", "http://localhost:5173")
CORS_ALLOW_ORIGINS = [origin.strip() for origin in cors_origins_raw.split(",") if origin.strip()]

if AI_PROVIDER == "deepseek" and not DEEPSEEK_API_KEY:
    print("WARNING: AI_PROVIDER=deepseek but DEEPSEEK_API_KEY is not set")
if AI_PROVIDER == "openrouter" and not OR_API_KEY:
    print("WARNING: AI_PROVIDER=openrouter but OR_KEY is not set")
