# AN·RA (Ai-named--Truman)

AN·RA is a split-deployment AI workspace with:
- a **TypeScript API backend** deployed to **Railway**.
- a **Vite + React frontend** deployed to **Vercel**.
- an additional **legacy Python/React workspace** kept in the repo for iteration and reference.

This README is focused on what the project does, how it is deployed today, and how to run it locally.

---

## 1) Project Goal

The goal of AN·RA is to provide a practical, developer-friendly AI workspace that combines:
- conversational assistance,
- code-oriented tooling,
- idea exploration,
- and structured knowledge workflows.

In short: **one interface where users can chat, build, analyze, and store useful outputs**.

---

## 2) Current Deployment Strategy (Production)

This repository uses **split hosting**:

### Backend → Railway
- Service: `@workspace/api-server`
- Build platform: Nixpacks (`nixpacks.toml`)
- Runtime command: `pnpm --filter @workspace/api-server start` with production runtime env
- Health endpoint: `/api/healthz`

### Frontend → Vercel
- App: `anra-workspace/frontend`
- Vercel build target: `anra-workspace/frontend/package.json` (`@vercel/static-build`)
- Dist directory produced by Vite: `anra-workspace/frontend/dist`
- SPA rewrite to `/index.html`

### Why split deployment?
- Better platform fit (API service vs static frontend)
- Independent scaling/deployment
- Clear separation of runtime concerns

### Vercel Project Settings (Required)

In the Vercel dashboard for this repo, use:

- **Root Directory:** `.` (repo root)
- **Do not set:** `.repo root` (this is not a real path and causes deployment failure)
- Build behavior is defined in `vercel.json` and targets `anra-workspace/frontend/package.json`.
- If you override Build/Output in Vercel, use `Build Command: pnpm build` and `Output Directory: dist` (root `build` now uses a reproducible frontend install (`npm ci`) and publishes `anra-workspace/frontend/dist` to root `dist`).
- If you override Build/Output in Vercel, use `Build Command: pnpm build` and `Output Directory: dist` (root `build` now publishes `anra-workspace/frontend/dist` to root `dist`).
 main

If you see `The specified Root Directory ".repo root" does not exist`, update the project setting and redeploy.

---

## 3) Repository Layout

```text
.
├── artifacts/
│   ├── api-server/            # Railway backend (TypeScript + Express)
│   └── mockup-sandbox/        # Vercel frontend (React + Vite)
├── lib/
│   ├── api-spec/              # OpenAPI source
│   ├── api-client-react/      # generated client hooks
│   ├── api-zod/               # generated zod schemas
│   └── db/                    # DB package (Drizzle)
├── anra-workspace/
│   ├── backend/               # legacy/parallel Python FastAPI backend
│   └── frontend/              # legacy/parallel React frontend
├── nixpacks.toml              # Railway/Nixpacks config
├── vercel.json                # Vercel build + output config
└── pnpm-workspace.yaml
```

---

## 4) Main Tech Stack

### Production path (active split deployment)
- Node.js 22
- pnpm workspaces
- TypeScript
- Express (API)
- React + Vite (frontend)

### Shared/Support tooling
- OpenAPI + Orval codegen
- Zod schemas
- Drizzle ORM (DB package)

### Legacy/parallel app in repo
- Python FastAPI backend
- React frontend under `anra-workspace/`

---

## 5) Local Development

## Prerequisites
- Node.js 22+
- pnpm 10+

Install dependencies:

```bash
pnpm install
```

### Run API server locally

```bash
pnpm --filter @workspace/api-server dev
```

### Run ANRA frontend locally

```bash
cd anra-workspace/frontend && npm run dev
```

### Build commands

```bash
pnpm --filter @workspace/api-server build
cd anra-workspace/frontend && npm run build
```

---

## 6) Deployment Configuration Files

- **Railway / Nixpacks:** `nixpacks.toml`
- **Vercel:** `vercel.json` (static-build config targeting `anra-workspace/frontend`)
- **Railway service metadata:** `railway.json`

If deployment fails, check these first along with package-level build scripts.

---

## 7) API and Frontend Responsibilities

### API (`artifacts/api-server`)
- Handles server runtime and HTTP endpoints
- Exposes health route for platform checks
- Built with TypeScript build pipeline (`tsc -b`)

### Frontend (`artifacts/mockup-sandbox`)
- Provides UI for workspace interactions
- Built as static assets via Vite
- Served by Vercel as SPA

---

## 8) Project Size (quick snapshot)

The following snapshot was measured from tracked files in this repository:

- **Tracked files:** 176
- **Total tracked lines (all file types):** ~26,549 (`git ls-files | xargs wc -l`)
- **Approx code lines (selected code extensions):** ~11,506

Approx code lines by major area:
- `artifacts/mockup-sandbox`: ~6,533
- `anra-workspace/frontend`: ~3,416
- `anra-workspace/backend`: ~695
- `lib/*`: ~646
- `artifacts/api-server`: ~215

> Note: values are moving targets and will change as the project evolves.

---

## 9) Typical Contributor Workflow

1. Create a branch.
2. Run scoped builds for changed packages.
3. Update deployment config when build/output paths change.
4. Open PR with:
   - motivation,
   - exact file changes,
   - validation commands and results.

---

## 10) Roadmap Direction (high level)

- Stabilize split deployment pipeline (Railway + Vercel)
- Improve frontend UX and feature depth in the workspace
- Expand API surface with documented contracts
- Consolidate legacy and active app paths over time

---

## License

MIT
