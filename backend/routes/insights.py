"""
Insights route — live AI probes + workspace statistics.
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from services.ai_client import call_ai, get_provider_status
from db.database import get_db
from db.models import ChatMessage, VaultItem

router = APIRouter()


@router.get("/probe")
async def probe():
    """Generate one original, sharp insight from TRUMAN."""
    ai = get_provider_status()
    if not ai["ready"]:
        raise HTTPException(
            status_code=503,
            detail=(
                "AI is not configured. Add OR_KEY or DEEPSEEK_API_KEY "
                "in your Railway Variables tab."
            ),
        )
    system = (
        "You are TRUMAN. Generate one short profound insight about "
        "intelligence, consciousness, space, mathematics, or reality. "
        "Maximum 3 sentences. Be original. Be precise. No clichés. "
        "Do not start with 'I' or 'As'."
    )
    messages = [{"role": "user", "content": "Generate insight."}]
    reply    = await call_ai(messages, system, max_tokens=200)
    return {"insight": reply}


@router.get("/stats")
def stats(db: Session = Depends(get_db)):
    """Return workspace usage statistics."""
    total_messages  = db.query(ChatMessage).count()
    total_sessions  = db.query(ChatMessage.session_id).distinct().count()
    vault_items     = db.query(VaultItem).count()
    ai              = get_provider_status()
    return {
        "total_messages": total_messages,
        "total_sessions": total_sessions,
        "vault_items":    vault_items,
        "total_builds":   0,
        "ai_ready":       ai["ready"],
        "provider":       ai["provider"],
    }
