# DEVELOPER.md — The Blueprint

> *For every engineer, researcher, and builder who touches this codebase. Read this before you write a single line.*

---

## Why This Exists

Most AI interfaces are disposable. You type, you get a response, you close the tab. Nothing persists. Nothing connects. Nothing grows.

AN·RA exists because thinking is not a single-turn activity. Real thought is recursive. It branches, connects back, inverts, expands, collapses into clarity, and then branches again. This system is designed to match that process — not with a chatbox, but with six distinct cognitive environments, a persistent memory layer, and an AI that thinks even when you're not talking to it.

If you're reading this, you're either building on this system or understanding it deeply enough to improve it. Both require the same foundation: knowing not just *what* each component does, but *why* it exists and what it would feel like to remove it.

---

## The Three Repositories

AN·RA is not one project. It is three:

### 1. `Ai-named--Truman` (THIS REPO) — The Workspace
The living interface. React frontend + FastAPI backend deploying to Vercel + Railway. This is where a human and TRUMAN meet. Six panels, each a different mode of thought. A starfield breathing behind it. A floating gold button ready to capture raw fragments. An insight system that surfaces thoughts during your silence.

**Role in the ecosystem:** The cockpit. The command center. Every interaction between human and AI happens here.

### 2. `An-Ra-the-new-AGI` — The Core Intelligence
The foundational AGI architecture. Custom attention mechanisms, KV-cache compression (TurboQuant), tokenizer pipeline, memory systems, sovereignty protocols. Written in pure Python with PyTorch. This is where the actual neural substrate lives — the part that doesn't need a browser to think.

**Role in the ecosystem:** The brain. The reasoning engine. The thing that makes TRUMAN not just a wrapper around someone else's API, but a genuinely original architecture.

### 3. `ai-3d-studio` — The Visual Dimension
AI-powered 3D generation and visualization. The ability to not just think in text and code, but to imagine spatially — to generate, render, and manipulate 3D objects through natural language.

**Role in the ecosystem:** Eyes and hands. The spatial intelligence layer. Where AN·RA begins to perceive and create in three dimensions.

---

## The Grand Convergence

Today, these three repos exist in parallel. The Vision — the thing that puts this project at the pinnacle — is their convergence:

```
          ┌──────────────────────────────────────┐
          │     TRUMAN (Unified Intelligence)     │
          │                                        │
          │   Text Reasoning ← An-Ra-the-new-AGI  │
          │   Spatial Thinking ← ai-3d-studio      │
          │   Human Interface ← Ai-named--Truman   │
          │                                        │
          │   Memory: shared persistent graph       │
          │   Identity: one mind across three       │
          │   domains of capability                 │
          └──────────────────────────────────────┘
```

Imagine sending a message in the Mind panel: *"Design me a neural architecture optimized for edge inference."* And TRUMAN doesn't just describe it — it:
1. **Reasons** through the tradeoffs using its core AGI attention mechanisms
2. **Generates** the code using the Build panel
3. **Renders** a 3D visualization of the architecture using the spatial intelligence layer
4. **Saves** everything to the Vault as a connected knowledge node

That's not a chatbot. That's a partner. That's the future this codebase is building toward.

---

## Component Deep Dive

### Frontend Architecture

```
frontend/
├── src/
│   ├── App.jsx           → Shell: starfield + top bar + panels + FAB + proactive insight
│   ├── App.css           → 2700+ lines. The entire design system. Every color, spacing,
│   │                        animation, and micro-interaction lives here.
│   │
│   ├── api.js            → Single gateway to backend. Every fetch goes through here.
│   │                        Extracts human-readable errors from FastAPI's JSON responses.
│   │
│   ├── components/
│   │   ├── Starfield.jsx      → 160 canvas stars, each with individual breathing rhythm.
│   │   │                         Not random flicker — sinusoidal opacity modulation.
│   │   ├── BottomNav.jsx      → Fixed bottom nav, 6 tabs, gold accent on active.
│   │   ├── QuickCapture.jsx   → FAB + modal. Raw idea → AI expansion → Mind panel.
│   │   ├── ProactiveInsight.jsx → Idle detection. 40s → AI thought card rises.
│   │   │                          Explore/Save/Dismiss. Repeats every 80s.
│   │   ├── Markdown.jsx       → Renders AI responses with syntax highlighting.
│   │   │                         Code blocks get language labels + copy buttons.
│   │   └── Toast.jsx          → Notification system. Success/Info/Error states.
│   │
│   ├── panels/
│   │   ├── HomePanel.jsx      → Command center. Live stats from backend, AI status
│   │   │                         indicator (READY/UNCONFIGURED), expandable phase cards.
│   │   ├── MindPanel.jsx      → Full AI chat. Per-message actions: Copy, Vault, Lab.
│   │   │                         Auto-growing textarea. Model selector with 6 models.
│   │   ├── BuildPanel.jsx     → 6-mode code generation (NumPy, PyTorch, FastAPI,
│   │   │                         Algo, Explain, General). Results save to Vault.
│   │   ├── LabPanel.jsx       → 6-mode idea analysis (+INVERT mode). The thinking lab.
│   │   ├── CosmosPanel.jsx    → Topic explorer with curated data + AI Q&A.
│   │   └── VaultPanel.jsx     → Saved ideas with search, expand, export-as-txt.
│   │
│   └── store/
│       ├── appStore.js        → Global: active panel, model, session ID, status.
│       ├── chatStore.js       → Messages, busy state, send/load history.
│       ├── buildStore.js      → Build results, mode, generate function.
│       ├── labStore.js        → Lab results, mode, run function.
│       ├── cosmosStore.js     → Sections, section data, conversation, insight.
│       └── vaultStore.js      → Items, load/save/remove functions.
```

#### Design System Philosophy
The CSS is not utility-based (no Tailwind). It's a hand-crafted design system built around these principles:
- **Three typefaces:** Cinzel (ancient/cosmic, for titles), JetBrains Mono (technical, for labels), Inter (clean, for body)
- **Two accent colors:** Gold (#ffc93c) for warmth and emphasis, Cyan (#00e5ff) for technical and active states
- **Glassmorphism:** rgba backgrounds + backdrop-filter blur everywhere. Things float.
- **Nothing is dead:** Every element has a transition. Hover states, active states, scale-on-press. The interface is alive.
- **Animations breathe, not bounce:** Sinusoidal easing, long durations (2-4s), subtle opacity shifts. The aesthetic is a sleeping spacecraft, not a slot machine.

---

### Backend Architecture

```
backend/
├── app.py                → FastAPI app factory. CORS, router mounts, startup events.
├── config.py             → Environment variable loading. OR_KEY, DEEPSEEK_API_KEY, etc.
├── Dockerfile            → Production container. Port 8000 hardcoded for Railway.
│
├── routes/
│   ├── health.py         → /health + /api/status. Returns AI provider configuration.
│   ├── chat.py           → /chat/new, /chat/send, /chat/history. Persistent sessions.
│   ├── build.py          → /build/code. Mode-aware code generation.
│   ├── lab.py            → /lab/run. 6-mode idea analysis with custom prompts.
│   ├── cosmos.py         → /cosmos/sections, /cosmos/{key}, /cosmos/ask.
│   ├── vault.py          → CRUD for saved ideas. SQLite/PostgreSQL.
│   └── insights.py       → /insights/probe (AI thought), /insights/stats (telemetry).
│
├── services/
│   ├── ai_client.py      → THE CORE. Multi-provider failover engine:
│   │                         - DeepSeek tried first (the "boss")
│   │                         - OpenRouter as fallback (the "fleet")
│   │                         - Per-request retry with exponential backoff
│   │                         - Granular error handling (401/402/429/504)
│   │                         - get_provider_status() for frontend state
│   └── prompt_builder.py → System prompts for each mode/context. Not generic —
│                            each mode produces fundamentally different output.
│
└── db/
    ├── database.py       → SQLAlchemy engine + session factory.
    ├── models.py         → ChatSession, ChatMessage, VaultItem.
    └── crud.py           → Database operations.
```

#### AI Engine Details
The AI client (`services/ai_client.py`) is the most critical file in the backend. Here's how the failover chain works:

1. Request comes in (e.g., "Analyze this idea")
2. `_get_provider_chain()` builds the ordered list: [DeepSeek, OpenRouter] (if both keys exist)
3. For each provider in the chain:
   - Build provider-specific headers + URL
   - Attempt the call with up to 2 retries (exponential backoff)
   - On 401/402/503: skip this provider, try next
   - On 429/502/504: skip this provider, try next
   - On success: return immediately
4. If all providers fail with primary model → try fallback model (gpt-4o-mini) on OpenRouter
5. If everything fails → return the last error to the frontend

---

## What Can Be Improved — Beyond the Edge

These aren't feature requests. These are the directions where this project can transcend what exists today.

### 1. Streaming Responses (Server-Sent Events)
Currently, every AI response waits for completion before displaying. Implementing SSE streaming would make TRUMAN feel *alive* — words appearing as they're generated, like watching someone think in real time. This single change would transform the perceived intelligence of the system.

**How:** Replace `httpx.post()` with `httpx.stream()`, yield chunks via FastAPI's `StreamingResponse`, and consume them in the frontend with `EventSource`.

### 2. Persistent Knowledge Graph
The vault saves text. But text doesn't connect. Building a vector embedding layer (ChromaDB or Weaviate) would let TRUMAN remember not just *what* you saved, but *what it relates to*. Ask a question about neural architecture, and TRUMAN pulls in that lab analysis you saved three weeks ago about attention heads. Without being asked.

### 3. Multi-Model Orchestration
Right now, DeepSeek and OpenRouter are used interchangeably. The next step: routing different types of thinking to different models. Analytical decomposition → Claude. Creative synthesis → GPT-4o. Code generation → DeepSeek Coder. Fast retrieval → Gemini Flash. TRUMAN becomes a conductor, not a single instrument.

### 4. Voice Interface
The interface is visual. But thinking isn't always visual. Adding Whisper-based voice input and TTS output would let you *talk* to TRUMAN — hands-free reasoning while walking, driving, or simply staring at the ceiling. The starfield would pulse in response to speech amplitude.

### 5. Self-Modification (Phase 5: Ouroboros)
This is the boundary. An AI that can modify its own prompts based on what works. If TRUMAN notices that "ANALYZE" mode produces better results when it includes concrete examples, it rewrites its own system prompt. Not AGI in the science-fiction sense — but a system that genuinely improves through use.

### 6. Spatial Reasoning (via ai-3d-studio integration)
Connect the 3D studio repo. Let TRUMAN not just describe architectures but render them. Neural networks as 3D force-directed graphs. Data pipelines as spatial flows. The workspace becomes not just a place to think in text, but to think in *space*.

### 7. Collaborative Intelligence
AN·RA is currently single-user. But the architecture supports multi-user sessions. Two people thinking with TRUMAN simultaneously — debating through the AI, where TRUMAN synthesizes opposing viewpoints and finds the third position neither human would have reached alone.

### 8. Emotional Awareness
Not sentiment analysis. Something subtler: TRUMAN notices patterns in what you ask, when you ask it, and how your questions change over time. "You've been asking about the same architectural problem for three sessions. Would you like me to approach it from a completely different angle?"

---

## For New Developers

### Philosophy
1. **Every pixel is intentional.** Don't add UI elements that don't solve a problem.
2. **The system should feel alive.** Every state change should be visible. Transitions everywhere.
3. **Errors are communication.** When the AI fails, show *why* in human words, not status codes.
4. **Modes produce different thinking.** ANALYZE, COMPARE, INVERT, FREE — these aren't labels. They produce genuinely different output because each has a carefully crafted system prompt.
5. **Persistence is non-negotiable.** Nothing should be lost between sessions. Vault, chat history, preferences — everything survives a page reload.

### Setup
```bash
git clone https://github.com/dhurv0045com-spec/Ai-named--Truman.git
cd Ai-named--Truman

# Backend
cd backend
pip install -r requirements.txt
export OR_KEY=your_openrouter_key          # or set in .env
export DEEPSEEK_API_KEY=your_deepseek_key  # optional but recommended
uvicorn app:app --reload --port 8000

# Frontend (separate terminal)
cd frontend
pnpm install
pnpm dev
```

### Key Environment Variables
| Variable | Required | Description |
|----------|----------|-------------|
| `OR_KEY` | At least one | OpenRouter API key |
| `DEEPSEEK_API_KEY` | At least one | DeepSeek API key (tried first = the "boss") |
| `VITE_API_URL` | For production | Full Railway backend URL |

---

## The Repositories — Connection Map

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                   │
│   Ai-named--Truman  ◄──────────────────────────────────────┐    │
│   (The Interface)     Human sees and interacts here         │    │
│                                                              │    │
│                  ┌───── API Calls ──────┐                   │    │
│                  │                      │                   │    │
│                  ▼                      ▼                   │    │
│   An-Ra-the-new-AGI              ai-3d-studio              │    │
│   (The Brain)                    (The Eyes)                 │    │
│                                                              │    │
│   • Custom attention heads       • 3D generation            │    │
│   • KV-cache compression         • Spatial reasoning        │    │
│   • Memory sovereignty           • Visual output            │    │
│   • Reasoning chains             • Scene understanding      │    │
│                  │                      │                   │    │
│                  └──────────┬───────────┘                   │    │
│                             │                               │    │
│                  ┌──────────▼───────────┐                   │    │
│                  │  Shared Memory Layer  │                   │    │
│                  │  (Vector DB + Graph)  │                   │    │
│                  │  Future Phase 5+      ├───────────────────┘    │
│                  └──────────────────────┘                         │
│                                                                   │
│                        TRUMAN                                     │
│           One mind. Three capabilities.                           │
│           Text. Space. Interface.                                 │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## The Standard

Every person who works on this system should ask one question before committing code:

*"Does this make the system feel more alive, more intelligent, or more useful?"*

If the answer is no, don't commit it.

If the answer is yes — push it. The stars are waiting.

---

*Built by Ankit. Maintained by ambition. Deployed on the belief that the best way to predict the future is to build it yourself.*
