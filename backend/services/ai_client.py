import httpx
from fastapi import HTTPException
from config import (
    OR_API_KEY,
    DEEPSEEK_API_KEY,
    DEFAULT_MODEL,
    AI_PROVIDER,
)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEEPSEEK_URL = "https://api.deepseek.com/v1/chat/completions"


def _provider_config() -> tuple[str, dict[str, str]]:
    if AI_PROVIDER == "deepseek":
        if not DEEPSEEK_API_KEY:
            raise HTTPException(status_code=500, detail="Missing DEEPSEEK_API_KEY")
        return (
            DEEPSEEK_URL,
            {
                "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                "Content-Type": "application/json",
            },
        )

    if not OR_API_KEY:
        raise HTTPException(status_code=500, detail="Missing OR_KEY")

    return (
        OPENROUTER_URL,
        {
            "Authorization": f"Bearer {OR_API_KEY}",
            "Content-Type": "application/json",
            "HTTP-Referer": "https://anra.build",
            "X-Title": "TRUMAN Workspace",
        },
    )


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
    url, headers = _provider_config()
    try:
        async with httpx.AsyncClient(timeout=60) as client:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()["choices"][0]["message"]["content"]
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"AI service error: {e.response.status_code}"
        )
    except HTTPException:
        raise
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
        if e.status_code == 502 and AI_PROVIDER == "openrouter":
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
