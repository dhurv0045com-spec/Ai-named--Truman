"""
AN·RA AI Client — robust, retry-aware, multi-provider
Supports: OpenRouter (default) and DeepSeek
"""

import asyncio
import httpx
from fastapi import HTTPException
from config import (
    OR_API_KEY,
    DEEPSEEK_API_KEY,
    DEFAULT_MODEL,
    AI_PROVIDER,
)

OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"
DEEPSEEK_URL   = "https://api.deepseek.com/v1/chat/completions"

# Retry config
MAX_RETRIES   = 2
RETRY_DELAYS  = [1.0, 2.0]          # seconds between retries
TIMEOUT       = 90.0                 # increased timeout for long AI responses


def get_provider_status() -> dict:
    """Return a structured status of which AI providers are configured."""
    or_ready    = bool(OR_API_KEY)
    ds_ready    = bool(DEEPSEEK_API_KEY)
    active      = AI_PROVIDER
    ready       = (active == "openrouter" and or_ready) or (active == "deepseek" and ds_ready)
    return {
        "provider":  active,
        "ready":     ready,
        "openrouter": or_ready,
        "deepseek":   ds_ready,
    }


def _provider_config() -> tuple[str, dict[str, str]]:
    """Return (url, headers) for the configured provider, or raise 503 if unconfigured."""
    if AI_PROVIDER == "deepseek":
        if not DEEPSEEK_API_KEY:
            raise HTTPException(
                status_code=503,
                detail="AI not configured: DEEPSEEK_API_KEY is missing. "
                       "Add it in your Railway Variables tab.",
            )
        return (
            DEEPSEEK_URL,
            {
                "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                "Content-Type":  "application/json",
            },
        )

    # Default: OpenRouter
    if not OR_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="AI not configured: OR_KEY (OpenRouter API key) is missing. "
                   "Add it in your Railway Variables tab.",
        )
    return (
        OPENROUTER_URL,
        {
            "Authorization": f"Bearer {OR_API_KEY}",
            "Content-Type":  "application/json",
            "HTTP-Referer":  "https://anra.build",
            "X-Title":       "TRUMAN Workspace",
        },
    )


async def call_ai(
    messages:    list,
    system:      str,
    model:       str  = DEFAULT_MODEL,
    max_tokens:  int  = 2000,
    temperature: float = 0.7,
) -> str:
    """Call the AI provider with automatic retry on transient errors."""
    full_messages = [{"role": "system", "content": system}] + messages[-20:]
    payload = {
        "model":       model,
        "max_tokens":  max_tokens,
        "temperature": temperature,
        "messages":    full_messages,
    }
    url, headers = _provider_config()

    last_error: Exception | None = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=TIMEOUT) as client:
                response = await client.post(url, headers=headers, json=payload)

                # Surface meaningful HTTP errors from the provider
                if response.status_code == 401:
                    raise HTTPException(
                        status_code=503,
                        detail="AI provider rejected the API key (401 Unauthorized). "
                               "Please check your OR_KEY or DEEPSEEK_API_KEY in Railway.",
                    )
                if response.status_code == 429:
                    # Rate limited — wait longer before the next attempt
                    wait = RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)] * 3
                    if attempt < MAX_RETRIES:
                        await asyncio.sleep(wait)
                        continue
                    raise HTTPException(
                        status_code=429,
                        detail="AI provider rate limit hit. Please wait a moment and try again.",
                    )
                if response.status_code == 402:
                    raise HTTPException(
                        status_code=503,
                        detail="AI provider account has no credits. Please top up your account.",
                    )

                response.raise_for_status()
                data = response.json()

                # Validate response structure
                if "choices" not in data or not data["choices"]:
                    raise HTTPException(
                        status_code=502,
                        detail=f"AI provider returned an unexpected response: {data}",
                    )

                return data["choices"][0]["message"]["content"]

        except HTTPException:
            raise  # Never retry explicit HTTP exceptions we raised

        except (httpx.TimeoutException, httpx.ConnectError) as e:
            last_error = e
            if attempt < MAX_RETRIES:
                await asyncio.sleep(RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)])
                continue
            raise HTTPException(
                status_code=504,
                detail=f"AI provider timed out after {MAX_RETRIES + 1} attempts. "
                       "The model may be overloaded — try again in a moment.",
            )

        except httpx.HTTPStatusError as e:
            last_error = e
            if attempt < MAX_RETRIES:
                await asyncio.sleep(RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)])
                continue
            raise HTTPException(
                status_code=502,
                detail=f"AI service HTTP error: {e.response.status_code}",
            )

        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Unexpected AI error: {str(e)}")

    raise HTTPException(status_code=500, detail=f"AI call failed after retries: {last_error}")


async def call_ai_with_fallback(
    messages:       list,
    system:         str,
    primary_model:  str = DEFAULT_MODEL,
    fallback_model: str = "openai/gpt-4o-mini",
    max_tokens:     int = 2000,
) -> dict:
    """
    Try primary_model first.  On a transient 502/504, fall back to fallback_model
    (only when using OpenRouter, which supports both).
    Returns {"reply": str, "model_used": str}.
    """
    try:
        content = await call_ai(
            messages=messages,
            system=system,
            model=primary_model,
            max_tokens=max_tokens,
        )
        return {"reply": content, "model_used": primary_model}

    except HTTPException as e:
        # Only fall back on gateway / timeout errors (not auth / rate-limit errors)
        if e.status_code in (502, 504) and AI_PROVIDER == "openrouter":
            try:
                content = await call_ai(
                    messages=messages,
                    system=system,
                    model=fallback_model,
                    max_tokens=max_tokens,
                )
                return {"reply": content, "model_used": fallback_model}
            except HTTPException:
                pass  # Fall through to raise the original error
        raise
