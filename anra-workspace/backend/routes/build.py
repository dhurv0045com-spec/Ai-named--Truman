from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_code_prompt
from config import DEFAULT_MODEL

router = APIRouter()

VALID_MODES = ["numpy", "pytorch", "fastapi", "algo", "explain", "general"]


class CodeRequest(BaseModel):
    prompt: str
    mode: str = "general"
    model: str = DEFAULT_MODEL
    max_tokens: int = 3000


class CodeResponse(BaseModel):
    code: str
    mode: str
    model_used: str
    prompt_echo: str


@router.get("/ping")
def build_ping():
    return {
        "status": "build online",
        "modes": ["numpy", "pytorch", "fastapi", "algo", "explain", "general"]
    }


@router.post("/code", response_model=CodeResponse)
async def generate_code(req: CodeRequest):
    if req.mode not in VALID_MODES:
        raise HTTPException(status_code=400, detail="Invalid mode")
    try:
        system = build_code_prompt(task=req.prompt, mode=req.mode)
        messages = [{"role": "user", "content": req.prompt}]
        result = await call_ai_with_fallback(
            messages, system, req.model, max_tokens=req.max_tokens
        )
        return CodeResponse(
            code=result["reply"],
            mode=req.mode,
            model_used=result["model_used"],
            prompt_echo=req.prompt[:60]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Build failed: {str(e)}")
