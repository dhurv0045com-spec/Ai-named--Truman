# AN·RA — AI Workspace

AN·RA is a full-stack AI workspace built around an intelligent reasoning system. It provides a clean, dark-themed interface with multiple specialized panels for chat, code generation, scientific analysis, and knowledge storage.

---

## Features

- **Mind** — persistent AI chat with session history
- **Build** — code generation across multiple modes (NumPy, PyTorch, FastAPI, algorithms, explain, general)
- **Lab** — deep analysis, comparisons, future projections, and idea development
- **Cosmos** — curated knowledge base for space, science, and frontier topics
- **Vault** — save and revisit generated ideas and code snippets
- **Home** — dashboard overview and quick access

---

## Stack

### Backend (`anra-workspace/backend`)
- **Python** + **FastAPI**
- **SQLAlchemy** + SQLite for chat history and vault storage
- **OpenRouter** AI client with model fallback
- Routes: `/health`, `/chat`, `/vault`, `/build`, `/lab`, `/cosmos`, `/insights`

### Frontend (`anra-workspace/frontend`)
- **React** + **Vite**
- **Zustand** for state management
- Custom syntax-highlighted `CodeBlock` component
- Panels: Home, Mind, Build, Lab, Cosmos, Vault

### Monorepo (`/`)
- **pnpm workspaces** monorepo
- **TypeScript** 5.9
- **Express 5** API server (`artifacts/api-server`)
- **PostgreSQL** + **Drizzle ORM**
- **Zod** validation + **Orval** codegen from OpenAPI spec
- **esbuild** for production builds

---

## Getting Started

### Prerequisites
- Node.js 18+
- Python 3.10+
- pnpm (`npm install -g pnpm`)

### Backend

```bash
cd anra-workspace/backend
cp .env.example .env
# Add your OpenRouter API key to .env:
# OR_KEY=sk-or-v1-your-key-here
pip install -r requirements.txt
uvicorn app:app --reload --port 8000
```

API docs available at `http://localhost:8000/docs`

### Frontend

```bash
cd anra-workspace/frontend
npm install
npm run dev
```

Open `http://localhost:5173`

### Monorepo (TypeScript API Server)

```bash
pnpm install
pnpm --filter @workspace/api-server run dev
```

---

## Environment Variables

Copy `anra-workspace/backend/.env.example` to `.env` and fill in:

| Variable | Description |
|---|---|
| `OR_KEY` | OpenRouter API key — get one at [openrouter.ai](https://openrouter.ai) |
| `DATABASE_URL` | SQLite path (default: `sqlite:///./anra.db`) |
| `DEFAULT_MODEL` | AI model to use (default: `anthropic/claude-3.5-haiku`) |
| `DEBUG` | Enable debug mode (`true` / `false`) |

---

## Project Structure

```
.
├── anra-workspace/
│   ├── backend/
│   │   ├── app.py               # FastAPI app entry point
│   │   ├── config.py            # Environment config
│   │   ├── requirements.txt
│   │   ├── db/                  # SQLAlchemy models + CRUD
│   │   ├── routes/              # health, chat, vault, build, lab, cosmos
│   │   └── services/            # AI client, prompt builder
│   └── frontend/
│       └── src/
│           ├── api.js           # All API calls (single source of truth)
│           ├── store/           # Zustand stores per panel
│           ├── components/      # Markdown renderer, CodeBlock
│           └── panels/          # Home, Mind, Build, Lab, Cosmos, Vault
├── artifacts/
│   └── api-server/              # TypeScript Express API server
├── lib/
│   ├── api-spec/                # OpenAPI spec + Orval codegen config
│   ├── api-client-react/        # Generated React Query hooks
│   ├── api-zod/                 # Generated Zod schemas
│   └── db/                      # Drizzle ORM schema
└── pnpm-workspace.yaml
```

---

## Key Commands (Monorepo)

```bash
pnpm run typecheck                           # Full TypeScript check
pnpm run build                               # Typecheck + build all packages
pnpm --filter @workspace/api-spec run codegen  # Regenerate API hooks + Zod schemas
pnpm --filter @workspace/db run push         # Push DB schema changes (dev only)
pnpm --filter @workspace/api-server run dev  # Run API server
```

---

## License

MIT
