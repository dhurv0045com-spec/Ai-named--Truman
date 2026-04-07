from sqlalchemy.orm import Session
from db.models import ChatMessage, VaultItem
from datetime import datetime


# ── CHAT ──────────────────────────────────────────────────────────────────────

def save_message(db: Session, session_id: str,
                 role: str, content: str) -> ChatMessage:
    msg = ChatMessage(session_id=session_id, role=role, content=content)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_history(db: Session, session_id: str,
                limit: int = 40) -> list:
    rows = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.timestamp.asc())
        .limit(limit)
        .all()
    )
    return [{"role": r.role, "content": r.content} for r in rows]


def delete_session(db: Session, session_id: str) -> int:
    count = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .delete()
    )
    db.commit()
    return count


def list_sessions(db: Session) -> list:
    rows = db.query(ChatMessage.session_id).distinct().all()
    return [r.session_id for r in rows]


# ── VAULT ─────────────────────────────────────────────────────────────────────

def get_vault(db: Session) -> list:
    return (
        db.query(VaultItem)
        .order_by(VaultItem.created_at.desc())
        .all()
    )


def save_vault_item(db: Session, title: str, content: str) -> VaultItem:
    item = VaultItem(title=title, content=content)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def delete_vault_item(db: Session, item_id: int) -> bool:
    item = (
        db.query(VaultItem)
        .filter(VaultItem.id == item_id)
        .first()
    )
    if not item:
        return False
    db.delete(item)
    db.commit()
    return True
