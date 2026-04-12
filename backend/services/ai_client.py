"""
AN·RA AI Client — Multi-provider with automatic failover.

Architecture:
  - DeepSeek operates as the "boss" (primary orchestrator)
  - OpenRouter serves as the fallback worker fleet
  - If one key fails, the system automatically switches to the other
  - Both keys can coexist; DeepSeek is tried first when available

Railway Variable Names:
  OR_KEY          — OpenRouter API key
  DEEPSEEK_API_KEY — DeepSeek API key
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

# DeepSeek model mapping (when DeepSeek is the active provider)
DEEPSEEK_MODEL = "deepseek-chat"

# Retry config
MAX_RETRIES   = 2
RETRY_DELAYS  = [1.0, 2.0]
TIMEOUT       = 90.0


def get_provider_status() -> dict:
    """Return a structured status of which AI providers are configured."""
    or_ready = bool(OR_API_KEY)
    ds_ready = bool(DEEPSEEK_API_KEY)
    active   = AI_PROVIDER

    # Ready if ANY key is available (since we auto-failover)
    ready = or_ready or ds_ready

    return {
        "provider":    active,
        "ready":       ready,
        "openrouter":  or_ready,
        "deepseek":    ds_ready,
        "failover":    or_ready and ds_ready,  # both keys = auto-failover enabled
    }


def _build_headers_for(provider: str) -> tuple[str, dict[str, str], str]:
    """
    Returns (url, headers, model_override) for a specific provider.
    Raises HTTPException if the requested provider has no key.
    """
    if provider == "deepseek":
        if not DEEPSEEK_API_KEY:
            raise HTTPException(
                status_code=503,
                detail="DeepSeek key not set. Add DEEPSEEK_API_KEY in Railway Variables.",
            )
        return (
            DEEPSEEK_URL,
            {
                "Authorization": f"Bearer {DEEPSEEK_API_KEY}",
                "Content-Type":  "application/json",
            },
            DEEPSEEK_MODEL,
        )
    else:  # openrouter
        if not OR_API_KEY:
            raise HTTPException(
                status_code=503,
                detail="OpenRouter key not set. Add OR_KEY in Railway Variables.",
            )
        return (
            OPENROUTER_URL,
            {
                "Authorization": f"Bearer {OR_API_KEY}",
                "Content-Type":  "application/json",
                "HTTP-Referer":  "https://anra.build",
                "X-Title":       "TRUMAN Workspace",
            },
            None,  # no override — use whatever model was requested
        )


def _get_provider_chain() -> list[str]:
    """
    Build the ordered list of providers to try.
    DeepSeek is the 'boss' — always tried first when available.
    OpenRouter is the fallback worker fleet.
    """
    chain = []

    # DeepSeek is the boss — priority #1 if its key exists
    if DEEPSEEK_API_KEY:
        chain.append("deepseek")

    # OpenRouter is the fallback army
    if OR_API_KEY:
        chain.append("openrouter")

    return chain


async def _call_single_provider(
    provider:    str,
    messages:    list,
    system:      str,
    model:       str,
    max_tokens:  int,
    temperature: float,
) -> tuple[str, str]:
    """
    Call a single provider. Returns (content, model_used).
    Raises HTTPException on failure.
    """
    url, headers, model_override = _build_headers_for(provider)
    actual_model = model_override or model

    full_messages = [{"role": "system", "content": system}] + messages[-20:]
    payload = {
        "model":       actual_model,
        "max_tokens":  max_tokens,
        "temperature": temperature,
        "messages":    full_messages,
    }

    last_error = None
    for attempt in range(MAX_RETRIES + 1):
        try:
            async with httpx.AsyncClient(timeout=TIMEOUT) as client:
                response = await client.post(url, headers=headers, json=payload)

                if response.status_code == 401:
                    raise HTTPException(
                        status_code=503,
                        detail=f"{provider} rejected the API key (401). Check your key.",
                    )
                if response.status_code == 402:
                    raise HTTPException(
                        status_code=503,
                        detail=f"{provider} account has no credits (402). Please top up.",
                    )
                if response.status_code == 429:
                    wait = RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)] * 3
                    if attempt < MAX_RETRIES:
                        await asyncio.sleep(wait)
                        continue
                    raise HTTPException(
                        status_code=429,
                        detail=f"{provider} rate limit hit. Wait and try again.",
                    )

                response.raise_for_status()
                data = response.json()

                if "choices" not in data or not data["choices"]:
                    raise HTTPException(
                        status_code=502,
                        detail=f"{provider} returned empty response.",
                    )

                content = data["choices"][0]["message"]["content"]
                used    = data.get("model", actual_model)
                return content, f"{provider}/{used}" if provider == "deepseek" else used

        except HTTPException:
            raise

        except (httpx.TimeoutException, httpx.ConnectError) as e:
            last_error = e
            if attempt < MAX_RETRIES:
                await asyncio.sleep(RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)])
                continue
            raise HTTPException(
                status_code=504,
                detail=f"{provider} timed out after {MAX_RETRIES + 1} attempts.",
            )

        except httpx.HTTPStatusError as e:
            last_error = e
            if attempt < MAX_RETRIES:
                await asyncio.sleep(RETRY_DELAYS[min(attempt, len(RETRY_DELAYS) - 1)])
                continue
            raise HTTPException(
                status_code=502,
                detail=f"{provider} HTTP error: {e.response.status_code}",
            )

        except Exception as e:
            raise HTTPException(status_code=500, detail=f"{provider} error: {str(e)}")

    raise HTTPException(status_code=500, detail=f"{provider} failed after retries: {last_error}")


async def call_ai(
    messages:    list,
    system:      str,
    model:       str   = DEFAULT_MODEL,
    max_tokens:  int   = 2000,
    temperature: float = 0.7,
) -> str:
    """
    Call AI with automatic multi-provider failover.
    Tries DeepSeek first (the boss), then OpenRouter (the worker fleet).
    """
    chain = _get_provider_chain()

    if not chain:
        raise HTTPException(
            status_code=503,
            detail=(
                "No AI keys configured. Add OR_KEY (OpenRouter) and/or "
                "DEEPSEEK_API_KEY (DeepSeek) in Railway Variables."
            ),
        )

    last_error = None
    for provider in chain:
        try:
            content, _ = await _call_single_provider(
                provider, messages, system, model, max_tokens, temperature
            )
            return content
        except HTTPException as e:
            last_error = e
            # Auth/credit errors for this provider → try next
            if e.status_code in (401, 402, 503) and len(chain) > 1:
                print(f"⚡ {provider} failed ({e.detail}), falling over to next provider...")
                continue
            # Transient errors → try next provider
            if e.status_code in (429, 502, 504) and len(chain) > 1:
                print(f"⚡ {provider} transient error ({e.status_code}), trying next...")
                continue
            raise

    raise last_error or HTTPException(status_code=500, detail="All AI providers failed.")


async def call_ai_with_fallback(
    messages:       list,
    system:         str,
    primary_model:  str = DEFAULT_MODEL,
    fallback_model: str = "openai/gpt-4o-mini",
    max_tokens:     int = 2000,
) -> dict:
    """
    Try primary_model first, then fallback_model.
    Both attempts use the full provider failover chain internally.
    Returns {"reply": str, "model_used": str}.
    """
    chain = _get_provider_chain()

    if not chain:
        raise HTTPException(
            status_code=503,
            detail=(
                "No AI keys configured. Add OR_KEY and/or DEEPSEEK_API_KEY "
                "in your Railway Variables tab."
            ),
        )

    # Try each provider in the chain with the primary model
    last_error = None
    for provider in chain:
        try:
            content, model_used = await _call_single_provider(
                provider, messages, system, primary_model, max_tokens, 0.7
            )
            return {"reply": content, "model_used": model_used}
        except HTTPException as e:
            last_error = e
            print(f"⚡ {provider}/{primary_model} failed: {e.detail}")
            # If auth/credit → skip this provider entirely
            if e.status_code in (401, 402, 503):
                continue
            # Transient → try next provider
            if e.status_code in (429, 502, 504):
                continue
            raise

    # All providers failed with primary model → try fallback model on OpenRouter
    if OR_API_KEY:
        try:
            content, model_used = await _call_single_provider(
                "openrouter", messages, system, fallback_model, max_tokens, 0.7
            )
            return {"reply": content, "model_used": model_used}
        except HTTPException:
            pass

    raise last_error or HTTPException(status_code=500, detail="All AI providers failed.")
