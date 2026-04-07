from fastapi import APIRouter
from services.ai_client import call_ai
from db.database import SessionLocal
from db.models import ChatMessage, VaultItem

router = APIRouter()


@router.get("/probe")
async def probe():
    system = (
        "You are AN-RA. Generate one short profound insight about "
        "intelligence, consciousness, space, mathematics, or reality. "
        "Maximum 3 sentences. Be original. Be precise. No cliches."
    )
    messages = [{"role": "user", "content": "Generate insight."}]
    reply = await call_ai(messages, system, max_tokens=200)
    return {"insight": reply}


@router.get("/stats")
def stats():
    db = SessionLocal()
    try:
        total_messages = db.query(ChatMessage).count()
        total_sessions = db.query(ChatMessage.session_id).distinct().count()
        vault_items = db.query(VaultItem).count()
    finally:
        db.close()
    return {
        "total_messages": total_messages,
        "total_sessions": total_sessions,
        "vault_items": vault_items,
        "total_builds": 0
    }
