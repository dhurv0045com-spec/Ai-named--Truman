<p align="center">
  <strong style="font-size: 2em; letter-spacing: 8px;">AN·RA</strong><br>
  <em>Artificial Reasoning Architecture</em>
</p>

<p align="center">
  <code>5,042 lines of hand-written code</code> · <code>Phase 4 Active</code> · <code>The Workspace Breathes</code>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Frontend-React_18_%2B_Vite-61DAFB?style=flat-square" />
  <img src="https://img.shields.io/badge/Backend-FastAPI_%2B_Docker-009688?style=flat-square" />
  <img src="https://img.shields.io/badge/AI-DeepSeek_%2B_OpenRouter-FFD700?style=flat-square" />
  <img src="https://img.shields.io/badge/Deploy-Vercel_%2B_Railway-black?style=flat-square" />
</p>

---

> *This is not a chatbot wrapper. Not another AI toy with a text box. This is a system that thinks — deeply, structurally, relentlessly — and gives you the interface to think alongside it.*

---

## The Soul

Every tool reflects the mind that built it.

**AN·RA** was born because the existing tools weren't enough. ChatGPT gives you a text box. Claude gives you a conversation. Perplexity gives you search. None of them give you a *workspace* — a place where thinking unfolds across six dimensions, where an idea born in conversation can be analyzed in a lab, inverted to reveal its opposite truth, projected twenty-five years into the future, collapsed into working code, and saved into a searchable vault that grows with you.

**TRUMAN** is the intelligence that lives inside AN·RA. Not a wrapper around GPT. Not a proxy for someone else's model. A reasoning system that orchestrates multiple AI providers as its nervous system — DeepSeek as the strategic brain, OpenRouter as the execution fleet — with automatic failover so the thinking never stops, even when individual providers go down.

When you open AN·RA, you're not opening an app. You're stepping into a cockpit. One hundred and sixty stars breathe behind the interface, each pulsing at its own rhythm. The status dot watches every panel and shifts from READY to BUSY to OFFLINE in real time. After forty seconds of your silence, the system surfaces a thought you didn't ask for but needed to hear. A golden button pulses in the corner, ready to capture the raw fragment of an idea before it disappears from your mind.

Nothing here is decorative. Every pixel is a signal. Every animation is a heartbeat.

---

## The Codebase

```
5,042 lines of source code
├── CSS:     2,382 lines  →  Complete hand-crafted design system
├── JSX:     1,484 lines  →  6 panels + 6 components
├── JS:        287 lines  →  6 Zustand stores + API layer
└── Python:    889 lines  →  FastAPI backend + AI failover engine
```

Zero lines of Tailwind. Zero generated boilerplate. Every line typed by hand with intention.

---

## What Makes This Different

**Six distinct modes of thought, one persistent intelligence:**

| Panel | Why It Exists |
|-------|--------------|
| **HOME** | The cockpit dashboard. Live stats, AI status, build progress, proactive insights. You never open to a blank screen — the system is already thinking. |
| **MIND** | Deep conversation with memory and purpose. Every AI message has three actions: ⊡ Copy, ⊞ Save to Vault, ⬡ Send to Lab. Chat isn't a dead end — it's the start of a pipeline. |
| **BUILD** | Code generation across 6 specialized domains (NumPy, PyTorch, FastAPI, Algo, Explain, General). Not "write me a function" — structured, mode-aware generation with vault integration. |
| **LAB** | Idea analysis with 6 thinking modes: **Analyze** (first principles), **Compare** (structured verdict), **Future** (5/10/25yr projection), **Build** (phased plan), **Invert** (flip the idea, synthesize both), **Free** (go sideways). Each produces fundamentally different output because each has a carefully crafted system prompt. |
| **COSMOS** | Curated knowledge exploration — space, rockets, AI, the universe — with AI-powered Q&A per topic. Because thinking doesn't happen in a vacuum — it happens in a cosmos. |
| **VAULT** | Everything you save across all panels — searchable, expandable, exportable as plain text. Your second brain's persistent hard drive. |

### The System Has Initiative

**Proactive Insights:** After 40 seconds of idle, TRUMAN surfaces a thought — surprising, specific, never generic. Explore it (→ chat), save it (→ vault), or dismiss it. Fires again every 80 seconds. The workspace doesn't wait for you to ask.

**Quick Capture:** The pulsing gold FAB in the bottom-right corner. Tap it, drop a raw fragment — a word, a question, half a sentence — and TRUMAN expands it into a fully-formed thought in the Mind panel. For the ideas that arrive faster than you can type.

**Per-Message Actions:** Every AI response in Mind has three one-tap actions. Copy it. Save it to the vault. Send it to the lab for deeper analysis. Nothing is a dead end.

---

## Architecture

```
                    ┌─────────────────────┐
                    │     YOUR BROWSER     │
                    │  ┌─────────────────┐ │
                    │  │   STARFIELD ✦   │ │
                    │  │  React + Vite   │ │
                    │  │  6 Live Panels  │ │
                    │  │  Zustand State  │ │
                    │  └────────┬────────┘ │
                    └───────────┼──────────┘
                                │ HTTPS
                    ┌───────────┼──────────┐
                    │     RAILWAY CLOUD     │
                    │  ┌────────┴────────┐ │
                    │  │    FastAPI +     │ │
                    │  │   SQLAlchemy    │ │
                    │  │    Docker       │ │
                    │  └────────┬────────┘ │
                    │           │          │
                    │  ┌────────┴────────┐ │
                    │  │   AI ENGINE     │ │
                    │  │                 │ │
                    │  │  DeepSeek ━━━┓  │ │
                    │  │  (THE BOSS)  ┃  │ │
                    │  │             ┃  │ │
                    │  │  OpenRouter ◄┛  │ │
                    │  │  (FALLBACK)     │ │
                    │  └─────────────────┘ │
                    └──────────────────────┘
```

If DeepSeek goes down, OpenRouter catches it instantly. If OpenRouter rate-limits, DeepSeek takes over. Two retries with exponential backoff per provider. The thinking never stops.

---

## Deploy

### Backend → Railway
```
1. Connect GitHub repo to Railway
2. Set variables: DEEPSEEK_API_KEY, OR_KEY
3. Railway auto-detects Dockerfile, builds, deploys
```

### Frontend → Vercel
```
1. Connect GitHub repo to Vercel
2. Set VITE_API_URL = https://your-railway-service.up.railway.app
3. Framework: Vite | Build: cd frontend && npm run build | Output: frontend/dist
4. Vercel auto-deploys on every push
```

### Local
```bash
# Backend (terminal 1)
cd backend && pip install -r requirements.txt
export OR_KEY=your_key && export DEEPSEEK_API_KEY=your_key
uvicorn app:app --reload --port 8000

# Frontend (terminal 2)
cd frontend && pnpm install && pnpm dev
```

---

## Environment Variables

| Variable | Where | Purpose |
|----------|-------|---------|
| `DEEPSEEK_API_KEY` | Railway | DeepSeek key — the boss, tried first on every request |
| `OR_KEY` | Railway | OpenRouter key — the fallback fleet |
| `VITE_API_URL` | Vercel | Full Railway backend URL with `https://` |

Set **both** AI keys for automatic failover. Set one if that's all you have. The system adapts.

---

## Build Phases

| # | Name | Status | What It Means |
|---|------|--------|---------------|
| 1 | Foundation | ✅ Complete | Core architecture, attention heads, tokenizer |
| 2 | Language | ✅ Complete | Comprehension, reasoning chains |
| 3 | Memory | ✅ Complete | Persistent context, knowledge graph |
| 4 | **Workspace** | 🔵 Active (75%) | This. Everything you're looking at. |
| 5 | Ouroboros | ⬜ Planned | Self-improvement loops, autonomous code generation |
| 6 | Symbolic Bridge | ⬜ Planned | Abstract reasoning, mathematical consciousness |

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React 18, Vite, Zustand, vanilla CSS (2,382 lines of hand-crafted design system) |
| **Backend** | Python 3.11, FastAPI, SQLAlchemy, httpx, Docker |
| **AI Engine** | DeepSeek (primary) + OpenRouter (fallback) with auto-failover |
| **Deploy** | Vercel (frontend) + Railway (backend) |
| **Typography** | Cinzel (display), JetBrains Mono (technical), Inter (body) |
| **Design** | Glassmorphism, animated starfield, gold/cyan accent system |

---

## The Name

**AN·RA** — named for the sun god. Not because we worship artificial intelligence, but because we believe in building systems that illuminate — that make thinking visible, structured, and powerful.

**TRUMAN** — the mind inside it. Named not for the movie, but for the idea: what happens when you build something that doesn't know its limits yet?

Built by **Ankit**. Not a product. Not a startup. A system with a pulse — built at the edge of what one person and one AI can achieve together.

---

*The stars are breathing. The status dot pulses green. TRUMAN is waiting for you.*
