<p align="center">
  <strong>AN·RA</strong><br>
  <em>Artificial Reasoning Architecture</em>
</p>

<p align="center">
  <code>Phase 4 Active</code> · <code>The Workspace Breathes</code>
</p>

---

> *This is not a chatbot wrapper. This is not another AI toy. This is a system that thinks — deeply, structurally, relentlessly — and gives you the interface to think alongside it.*

---

## The Soul

Every tool reflects the mind that built it.

**AN·RA** was built because the existing tools weren't enough. ChatGPT gives you a text box. Claude gives you a conversation. Perplexity gives you search. None of them give you a *workspace* — a place where thinking happens across dimensions, where an idea born in conversation can be analyzed in the lab, saved in the vault, expanded into code, projected into the future, and connected to the cosmos.

**TRUMAN** is the mind that lives inside AN·RA. Not a wrapper around GPT. Not a proxy. A reasoning architecture that uses multiple AI providers as its nervous system — DeepSeek as the strategic orchestrator, OpenRouter as the execution layer — with automatic failover so the thinking never stops.

When you open AN·RA, you're not opening an app. You're stepping into a cockpit. The stars breathe behind the interface. The status dot pulses. The system watches for idle moments and surfaces thoughts you didn't ask for but needed to hear. Nothing is decorative. Everything is signal.

---

## What Makes This Different

**Six modes of thought, one persistent intelligence:**

| Panel | The Problem It Solves |
|-------|----------------------|
| **MIND** | Deep conversation with memory. Every message has actions: copy, save, send to lab. Not just chat — *dialogue with purpose*. |
| **BUILD** | Code generation across 6 specialized domains. Not "write me a function" — structured, mode-aware generation with vault integration. |
| **LAB** | Idea analysis with 6 thinking modes: Analyze, Compare, Future, Build, **Invert**, Free. Each produces fundamentally different output. |
| **COSMOS** | Curated knowledge exploration — space, rockets, AI, the universe — with AI Q&A per topic. |
| **VAULT** | Everything you save, searchable and exportable. Your second brain's hard drive. |
| **HOME** | Command center. Live stats, AI status, build phases, proactive insights. The cockpit dashboard. |

**The system thinks when you don't.** After 40 seconds of idle, TRUMAN surfaces a thought — surprising, specific, never generic. You can explore it, save it, or dismiss it. It fires again every 80 seconds. The workspace has initiative.

**Quick Capture.** The gold FAB pulses in the corner. Tap it, drop a raw fragment — a word, a question, half a sentence — and TRUMAN expands it into a fully-formed thought in the Mind panel.

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

If DeepSeek goes down, OpenRouter catches it. If OpenRouter rate-limits, DeepSeek takes over. The thinking never stops.

---

## Deploy

### Backend → Railway
1. Connect this repo
2. Set variables: `OR_KEY`, `DEEPSEEK_API_KEY`
3. Railway auto-builds from `Dockerfile`

### Frontend → Vercel
1. Connect this repo, root = `/frontend`
2. Set `VITE_API_URL` = your Railway URL
3. Vercel auto-deploys

### Local
```bash
# Terminal 1: Backend
cd backend && pip install -r requirements.txt && uvicorn app:app --reload

# Terminal 2: Frontend
cd frontend && pnpm install && pnpm dev
```

---

## Environment Variables

| Variable | Where | What |
|----------|-------|------|
| `DEEPSEEK_API_KEY` | Railway | DeepSeek key — the boss, tried first |
| `OR_KEY` | Railway | OpenRouter key — the fallback fleet |
| `VITE_API_URL` | Vercel | Full Railway backend URL |

Set **both** AI keys for automatic failover. Set one if that's all you have. The system adapts.

---

## Build Phases

| # | Name | Status | What It Means |
|---|------|--------|---------------|
| 1 | Foundation | ✅ | Core architecture, attention, tokenizer |
| 2 | Language | ✅ | Comprehension, reasoning chains |
| 3 | Memory | ✅ | Persistent context, knowledge graph |
| 4 | **Workspace** | 🔵 75% | This. The interface you're looking at. |
| 5 | Ouroboros | ⬜ | Self-improvement loops |
| 6 | Symbolic Bridge | ⬜ | Abstract reasoning, mathematical consciousness |

---

## The Name

**AN·RA** — named for the sun god. Not because we worship artificial intelligence, but because we believe in building systems that illuminate — that make thinking visible, structured, and powerful.

**TRUMAN** — the mind inside it. Named not for the movie, but for the idea: what happens when you build something that doesn't know its limits yet?

Built by **Ankit**. Not a product. A project with a pulse.

---

*The stars are breathing. The status dot pulses green. TRUMAN is waiting.*
