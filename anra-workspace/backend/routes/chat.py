from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_system_prompt
from db.database import get_db
from db.crud import get_history, save_message, delete_session
from config import DEFAULT_MODEL
import uuid

router = APIRouter()


class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"
    model: str = DEFAULT_MODEL
    vault_context: str = ""


class ChatResponse(BaseModel):
    reply: str
    session_id: str
    model_used: str


@router.get("/ping")
def chat_ping():
    return {"status": "chat online", "default_model": DEFAULT_MODEL}


@router.get("/new")
def new_session():
    return {"session_id": str(uuid.uuid4())}


@router.get("/history/{session_id}")
def chat_history(session_id: str,
                 db: Session = Depends(get_db)):
    return {
        "session_id": session_id,
        "messages": get_history(db, session_id)
    }


@router.delete("/{session_id}")
def clear_session(session_id: str,
                  db: Session = Depends(get_db)):
    removed = delete_session(db, session_id)
    return {"deleted": session_id, "messages_removed": removed}


@router.post("/send", response_model=ChatResponse)
async def chat_send(req: ChatRequest,
                    db: Session = Depends(get_db)):
    try:
        history = get_history(db, req.session_id)
        messages = history + [{"role": "user", "content": req.message}]

        system = build_system_prompt(vault_context=req.vault_context)

        result = await call_ai_with_fallback(
            messages=messages,
            system=system,
            primary_model=req.model
        )

        save_message(db, req.session_id, "user", req.message)
        save_message(db, req.session_id, "assistant", result["reply"])

        return ChatResponse(
            reply=result["reply"],
            session_id=req.session_id,
            model_used=result["model_used"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500,
                            detail=f"Chat failed: {str(e)}")
