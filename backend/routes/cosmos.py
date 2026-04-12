"""
Cosmos route — deep-space knowledge explorer with AI answers.
"""

import json
import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback, get_provider_status
from config import DEFAULT_MODEL

router = APIRouter()

DATA_PATH = os.path.join(os.path.dirname(__file__), "../data/cosmos.json")


def _load_cosmos() -> dict:
    try:
        with open(DATA_PATH, "r") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return {"sections": {}}


COSMOS = _load_cosmos()


class CosmosAskRequest(BaseModel):
    question: str
    category: str = "universe"


@router.get("/sections")
def get_sections():
    sections = [
        {"key": key, "title": val["title"], "accent": val["accent"]}
        for key, val in COSMOS["sections"].items()
    ]
    return {"sections": sections}


@router.get("/status")
def cosmos_status():
    ai = get_provider_status()
    return {
        "status":    "cosmos online",
        "sections":  len(COSMOS["sections"]),
        "ai_ready":  ai["ready"],
    }


@router.get("/{category}")
def get_category(category: str):
    if category == "status":   # prevent shadowing the /status route
        return cosmos_status()
    if category not in COSMOS["sections"]:
        raise HTTPException(status_code=404, detail=f"Category '{category}' not found")
    return COSMOS["sections"][category]


@router.post("/ask")
async def ask_cosmos(req: CosmosAskRequest):
    ai = get_provider_status()
    if not ai["ready"]:
        raise HTTPException(
            status_code=503,
            detail=(
                "AI is not configured. Add OR_KEY or DEEPSEEK_API_KEY "
                "in your Railway Variables tab."
            ),
        )

    section   = COSMOS["sections"].get(req.category) or COSMOS["sections"].get("universe", {})
    facts_text = "\n".join(section.get("facts", []))
    system = (
        f"You are TRUMAN in cosmos exploration mode.\n"
        f"Deep knowledge of space, science, universe.\n"
        f"Precise, awe-inspiring, factually grounded.\n"
        f"Current topic: {section.get('title', 'Unknown')}\n"
        f"Known facts:\n{facts_text}\n"
        f"Respond with depth. Use specific numbers. No filler text."
    )
    messages = [{"role": "user", "content": req.question}]
    result   = await call_ai_with_fallback(messages, system, DEFAULT_MODEL)
    return {
        "answer":     result["reply"],
        "model_used": result["model_used"],
        "category":   req.category,
    }
