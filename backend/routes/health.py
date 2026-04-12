"""
Health + status endpoint — returns full system state including AI configuration.
"""

from fastapi import APIRouter
from services.ai_client import get_provider_status

router = APIRouter()


@router.get("/health")
def health():
    ai = get_provider_status()
    return {
        "status":   "ok",
        "service":  "TRUMAN Backend",
        "phase":    4,
        "ai":       ai,
    }


@router.get("/api/status")
def api_status():
    """
    Called by the frontend to know if AI features are usable.
    Returns 200 with a structured payload — never 500.
    """
    ai = get_provider_status()
    return {
        "online":    True,
        "ai_ready":  ai["ready"],
        "provider":  ai["provider"],
        "model":     "configured" if ai["ready"] else "no key set",
        "message":   (
            f"AI ready via {ai['provider']}"
            if ai["ready"]
            else "AI keys not set — add OR_KEY or DEEPSEEK_API_KEY in Railway Variables."
        ),
    }
