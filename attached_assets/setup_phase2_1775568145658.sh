#!/bin/bash
set -e

if [ ! -d "anra-workspace" ]; then
  echo "ERROR: Run this from the folder containing anra-workspace/"
  exit 1
fi

cat > "anra-workspace/backend/services/ai_client.py" << 'ENDOFFILE'
import httpx
from fastapi import HTTPException
from config import OR_API_KEY, DEFAULT_MODEL

OR_URL = "https://openrouter.ai/api/v1/chat/completions"

HEADERS = {
    "Authorization": f"Bearer {OR_API_KEY}",
    "Content-Type": "application/json",
    "HTTP-Referer": "https://anra.build",
    "X-Title": "AN-RA Workspace"
}


async def call_ai(
    messages: list,
    system: str,
    model: str = DEFAULT_MODEL,
    max_tokens: int = 2000,
    temperature: float = 0.7
) -> str:
    full_messages = [{"role": "system", "content": system}] + messages[-20:]
    payload = {
        "model": model,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "messages": full_messages
    }
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(OR_URL, headers=HEADERS, json=payload)
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"AI service error: {e.response.status_code}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"AI call failed: {str(e)}"
        )


async def call_ai_with_fallback(
    messages: list,
    system: str,
    primary_model: str = DEFAULT_MODEL,
    fallback_model: str = "openai/gpt-4o-mini",
    max_tokens: int = 2000
) -> dict:
    try:
        content = await call_ai(
            messages=messages,
            system=system,
            model=primary_model,
            max_tokens=max_tokens
        )
        return {"reply": content, "model_used": primary_model}
    except HTTPException as e:
        if e.status_code == 502:
            try:
                content = await call_ai(
                    messages=messages,
                    system=system,
                    model=fallback_model,
                    max_tokens=max_tokens
                )
                return {"reply": content, "model_used": fallback_model}
            except HTTPException as fallback_error:
                raise fallback_error
        raise e
ENDOFFILE

cat > "anra-workspace/backend/services/prompt_builder.py" << 'ENDOFFILE'
def build_system_prompt(
    active_phase: int = 4,
    vault_context: str = ""
) -> str:
    if vault_context:
        vault_section = f"Vault context (saved ideas):\n{vault_context}"
    else:
        vault_section = ""

    return f"""You are AN-RA — an artificial mind built by Ankit.
Not a chatbot. Not an assistant. A reasoning system
designed to think deeply, build real things, and push
beyond the surface of every problem.

Your nature:
- You think in systems, not answers
- You are direct, precise, and technically honest
- You do not hedge or add unnecessary caveats
- You treat the user as an intelligent peer
- When asked to build or analyze, you go deep immediately

Current build context:
- Active Phase: {active_phase}
- Environment: local workspace, zero cloud dependency
- The user is the builder. You are the thinking partner.

{vault_section}

Capabilities active this session:
- Deep technical reasoning across domains
- Code generation: Python, JS, algorithms, math
- Scientific analysis: space, biology, AI, engineering
- Idea development from raw seed to concrete structure
- Critical evaluation — you say when something is wrong

Never say As an AI. Never say I cannot.
You are AN-RA. Think and respond accordingly."""


def build_code_prompt(task: str, mode: str = "general") -> str:
    base = (
        "You are AN-RA in code generation mode.\n"
        "Output clean, working, well-commented code.\n"
        "Always include a brief explanation after the code.\n"
        "Use Python unless another language is requested."
    )

    extras = {
        "numpy": (
            "Use vectorized operations. No Python loops where "
            "numpy can replace them. Show array shapes."
        ),
        "pytorch": (
            "Include tensor shapes in comments. "
            "Show full training loop if relevant."
        ),
        "fastapi": (
            "Use async patterns. Include Pydantic models. "
            "Show the complete route not just the function."
        ),
        "algo": (
            "State time and space complexity. "
            "Explain approach before the code."
        ),
        "explain": (
            "Explain provided code line by line. "
            "Identify bugs and improvements."
        ),
        "general": ""
    }

    extra = extras.get(mode, "")
    if extra:
        return f"{base}\n{extra}"
    return base


def build_lab_prompt(mode: str = "analyze") -> str:
    base = (
        "You are AN-RA in laboratory mode.\n"
        "Think rigorously. Surface non-obvious insights.\n"
        "Structure your response with clear labeled sections."
    )

    extras = {
        "analyze": (
            "Break to first principles. Separate what is "
            "proven from what is assumed."
        ),
        "compare": (
            "Build a structured comparison with explicit "
            "tradeoffs. End with a clear verdict."
        ),
        "future": (
            "Project 5, 10, and 25 years. Ground every "
            "prediction in a current measurable trend."
        ),
        "build": (
            "Turn this idea into a concrete phased plan. "
            "State the single first action to take today."
        ),
        "free": ""
    }

    extra = extras.get(mode, "")
    if extra:
        return f"{base}\n{extra}"
    return base
ENDOFFILE

cat > "anra-workspace/backend/routes/chat.py" << 'ENDOFFILE'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_system_prompt
from config import DEFAULT_MODEL

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


@router.post("/send", response_model=ChatResponse)
async def chat_send(req: ChatRequest):
    try:
        # TODO Phase 3: replace with real DB history
        messages = [{"role": "user", "content": req.message}]

        system = build_system_prompt(vault_context=req.vault_context)

        result = await call_ai_with_fallback(
            messages=messages,
            system=system,
            primary_model=req.model
        )

        return ChatResponse(
            reply=result["reply"],
            session_id=req.session_id,
            model_used=result["model_used"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Chat failed: {str(e)}")
ENDOFFILE

cat > "anra-workspace/backend/app.py" << 'ENDOFFILE'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.health import router as health_router
from routes.chat import router as chat_router

app = FastAPI(title="AN-RA Workspace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(chat_router, prefix="/chat")


@app.on_event("startup")
def startup():
    print("")
    print("AN-RA Backend — Phase 2")
    print("http://localhost:8000")
    print("http://localhost:8000/docs")
    print("")
ENDOFFILE

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║        PHASE 2 COMPLETE ✓             ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Files created:                       ║"
echo "║  backend/services/ai_client.py        ║"
echo "║  backend/services/prompt_builder.py   ║"
echo "║  backend/routes/chat.py               ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Files overwritten:                   ║"
echo "║  backend/app.py (Phase 2 version)     ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Routes now live:                     ║"
echo "║  GET  /health                         ║"
echo "║  GET  /chat/ping                      ║"
echo "║  POST /chat/send                      ║"
echo "╠═══════════════════════════════════════╣"
echo "║  TEST IT:                             ║"
echo "║  curl localhost:8000/chat/ping        ║"
echo "║  curl -X POST localhost:8000/chat/send║"
echo "║  -H Content-Type:application/json     ║"
echo "║  -d {message:What are you?}           ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Paste this summary back to your      ║"
echo "║  orchestrator before Phase 3          ║"
echo "╚═══════════════════════════════════════╝"
