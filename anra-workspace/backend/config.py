import os
from dotenv import load_dotenv

load_dotenv()

OR_API_KEY = os.getenv("OR_KEY")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./anra.db")
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "anthropic/claude-3.5-haiku")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

if not OR_API_KEY:
    print("WARNING: OR_KEY not set in .env file")
