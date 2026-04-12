"""
Lab route — multi-mode idea analysis powered by TRUMAN AI.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback, get_provider_status
from services.prompt_builder import build_lab_prompt
from config import DEFAULT_MODEL

router = APIRouter()

VALID_MODES = ["analyze", "compare", "future", "build", "invert", "free"]


class LabRequest(BaseModel):
    idea:    str
    mode:    str = "analyze"
    model:   str = DEFAULT_MODEL
    context: str = ""


class LabResponse(BaseModel):
    result:     str
    mode:       str
    model_used: str
    idea_echo:  str


@router.get("/ping")
def lab_ping():
    ai = get_provider_status()
    return {
        "status":   "lab online",
        "modes":    VALID_MODES,
        "ai_ready": ai["ready"],
    }


@router.post("/run", response_model=LabResponse)
async def run_lab(req: LabRequest):
    ai = get_provider_status()
    if not ai["ready"]:
        raise HTTPException(
            status_code=503,
            detail=(
                "AI is not configured. Add OR_KEY or DEEPSEEK_API_KEY "
                "in your Railway Variables tab."
            ),
        )

    if req.mode not in VALID_MODES:
        raise HTTPException(status_code=400, detail=f"Invalid lab mode. Choose from: {VALID_MODES}")

    try:
        system = build_lab_prompt(mode=req.mode)
        if req.context:
            system += f"\n\nAdditional context:\n{req.context}"

        messages = [{"role": "user", "content": req.idea}]
        result = await call_ai_with_fallback(
            messages, system, req.model, max_tokens=3000
        )
        return LabResponse(
            result=result["reply"],
            mode=req.mode,
            model_used=result["model_used"],
            idea_echo=req.idea[:80],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lab failed: {str(e)}")
