import json
import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from config import DEFAULT_MODEL

router = APIRouter()

DATA_PATH = os.path.join(os.path.dirname(__file__), "../data/cosmos.json")
with open(DATA_PATH, "r") as f:
    COSMOS = json.load(f)


class CosmosAskRequest(BaseModel):
    question: str
    category: str = "universe"


@router.get("/sections")
def get_sections():
    sections = [
        {
            "key": key,
            "title": val["title"],
            "accent": val["accent"]
        }
        for key, val in COSMOS["sections"].items()
    ]
    return {"sections": sections}


@router.get("/{category}")
def get_category(category: str):
    if category not in COSMOS["sections"]:
        raise HTTPException(status_code=404, detail="Category not found")
    return COSMOS["sections"][category]


@router.post("/ask")
async def ask_cosmos(req: CosmosAskRequest):
    section = COSMOS["sections"].get(req.category)
    if not section:
        section = COSMOS["sections"]["universe"]
    facts_text = "\n".join(section.get("facts", []))
    system = (
        f"You are AN-RA in cosmos exploration mode.\n"
        f"Deep knowledge of space, science, universe.\n"
        f"Precise, awe-inspiring, factually grounded.\n"
        f"Current topic: {section['title']}\n"
        f"Known facts about this topic:\n{facts_text}\n"
        f"Respond with depth. Use specific numbers."
    )
    messages = [{"role": "user", "content": req.question}]
    result = await call_ai_with_fallback(messages, system, DEFAULT_MODEL)
    return {
        "answer": result["reply"],
        "model_used": result["model_used"],
        "category": req.category
    }
