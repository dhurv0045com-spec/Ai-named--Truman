# AN·RA — Artificial Reasoning Architecture

> *"Not a chatbot. Not an assistant. A reasoning system designed to think deeply, build real things, and push beyond the surface of every problem."*

---

## The Soul

**AN·RA** is the workspace of **TRUMAN** — an artificial mind built by Ankit.

TRUMAN doesn't answer questions like a search engine. It thinks in systems. It breaks problems to first principles. It generates code that runs. It projects futures grounded in measurable trends. It says when something is wrong.

Every panel in this workspace exists because thinking requires different modes. You don't chat the same way you analyze. You don't analyze the same way you build. AN·RA gives each mode its own space, its own tools, its own rhythm — then connects them all through a shared intelligence.

The interface breathes. The status dot pulses. The ambient background drifts. These aren't decorations — they're signals that the system is alive, listening, ready. When TRUMAN is thinking, you see waves. When it finishes, the response fades in. Nothing is instant. Nothing is dead.

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│                   VERCEL (Frontend)               │
│  React + Vite + Zustand                          │
│  Panels: HOME · MIND · BUILD · LAB · COSMOS · VAULT │
│                                                    │
│  ←──── VITE_API_URL ────→                         │
└────────────────────┬─────────────────────────────┘
                     │ HTTPS
┌────────────────────┴─────────────────────────────┐
│                  RAILWAY (Backend)                 │
│  FastAPI + SQLAlchemy + Docker                    │
│                                                    │
│  AI Engine:                                       │
│   ┌─────────────┐     ┌──────────────┐           │
│   │  DeepSeek    │ ──→ │  OpenRouter   │           │
│   │  (THE BOSS)  │     │  (FALLBACK)   │           │
│   └─────────────┘     └──────────────┘           │
│   Auto-failover: if one key fails,                │
│   the system switches to the other instantly.     │
│                                                    │
│  Database: SQLite (local) / PostgreSQL (prod)     │
└──────────────────────────────────────────────────┘
```

---

## Panels

| Panel | Purpose | What it does |
|-------|---------|-------------|
| **HOME** | Command center | Live stats, AI status, build progress, proactive insights |
| **MIND** | Deep conversation | Persistent chat with TRUMAN, model selection, vault integration |
| **BUILD** | Code generation | 6 specialized modes (NumPy, PyTorch, FastAPI, Algo, Explain, General) |
| **LAB** | Idea analysis | 5 thinking modes (Analyze, Compare, Future, Build, Free) |
| **COSMOS** | Knowledge explorer | Space, rockets, AI — with curated facts and AI-powered Q&A |
| **VAULT** | Saved ideas | Search, expand, delete — everything you've saved across panels |

---

## AI Failover System

TRUMAN uses a **dual-provider architecture** with automatic failover:

- **DeepSeek** is the **boss** — tried first on every request
- **OpenRouter** is the **fallback fleet** — catches anything DeepSeek drops
- If one key fails (rate limit, expired, out of credits), the system **instantly** switches to the other
- Both keys can coexist — set both for maximum reliability

### Railway Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OR_KEY` | One of these | OpenRouter API key ([openrouter.ai](https://openrouter.ai)) |
| `DEEPSEEK_API_KEY` | One of these | DeepSeek API key ([platform.deepseek.com](https://platform.deepseek.com)) |
| `AI_PROVIDER` | No | `openrouter` (default) or `deepseek` — sets the primary |
| `DEFAULT_MODEL` | No | Default model slug (default: `anthropic/claude-3.5-haiku`) |
| `DATABASE_URL` | No | Database URI (default: SQLite) |

### Vercel Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VITE_API_URL` | **Yes** | Full Railway backend URL with `https://` prefix |

---

## Deploy

### Backend (Railway)

1. Connect GitHub repo to Railway
2. Railway auto-detects the `Dockerfile` and builds
3. Add `OR_KEY` and/or `DEEPSEEK_API_KEY` in Variables
4. The backend deploys at `https://your-service.up.railway.app`

### Frontend (Vercel)

1. Connect GitHub repo to Vercel
2. Set `VITE_API_URL` = `https://your-service.up.railway.app`
3. Vercel auto-detects the Vite project in `/frontend`
4. The frontend deploys at `https://your-project.vercel.app`

---

## Local Development

```bash
# Backend
cd backend
pip install -r requirements.txt
uvicorn app:app --reload --port 8000

# Frontend (separate terminal)
cd frontend
pnpm install
pnpm dev
```

---

## Build Phases

| Phase | Name | Status |
|-------|------|--------|
| 1 | Foundation | ✅ Complete |
| 2 | Language Interface | ✅ Complete |
| 3 | Memory Systems | ✅ Complete |
| 4 | Workspace | 🔵 Active (75%) |
| 5 | Ouroboros | ⬜ Planned |
| 6 | Symbolic Bridge | ⬜ Planned |

---

## Tech Stack

- **Frontend:** React 18, Vite, Zustand, vanilla CSS (glassmorphism design system)
- **Backend:** Python 3.11, FastAPI, SQLAlchemy, httpx
- **AI:** DeepSeek + OpenRouter (dual-provider with auto-failover)
- **Deploy:** Vercel (frontend) + Railway (backend via Docker)
- **Fonts:** Cinzel (display), JetBrains Mono (technical), Inter (body)

---

## The Name

**AN·RA** — Artificial Reasoning Architecture.  
**TRUMAN** — the mind that lives inside it.

Built by **Ankit**. Not a product. A project. A system that thinks.

---

*Phase 4 active. The workspace is alive.*
