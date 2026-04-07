#!/bin/bash
set -e

mkdir -p anra-workspace/backend/routes
mkdir -p anra-workspace/backend/services
mkdir -p anra-workspace/backend/db
mkdir -p anra-workspace/frontend/src

cat > "anra-workspace/backend/requirements.txt" << 'ENDOFFILE'
fastapi
uvicorn[standard]
httpx
python-dotenv
sqlalchemy
pydantic
ENDOFFILE

cat > "anra-workspace/backend/.env.example" << 'ENDOFFILE'
# Copy this to .env and fill your real values
# NEVER commit .env to GitHub

OR_KEY=sk-or-v1-your-openrouter-key-here
DATABASE_URL=sqlite:///./anra.db
DEFAULT_MODEL=anthropic/claude-3.5-haiku
DEBUG=true
ENDOFFILE

cat > "anra-workspace/backend/config.py" << 'ENDOFFILE'
import os
from dotenv import load_dotenv

load_dotenv()

OR_API_KEY = os.getenv("OR_KEY")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./anra.db")
DEFAULT_MODEL = os.getenv("DEFAULT_MODEL", "anthropic/claude-3.5-haiku")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

if not OR_API_KEY:
    print("WARNING: OR_KEY not set in .env file")
ENDOFFILE

cat > "anra-workspace/backend/routes/__init__.py" << 'ENDOFFILE'
ENDOFFILE

cat > "anra-workspace/backend/services/__init__.py" << 'ENDOFFILE'
ENDOFFILE

cat > "anra-workspace/backend/db/__init__.py" << 'ENDOFFILE'
ENDOFFILE

cat > "anra-workspace/backend/routes/health.py" << 'ENDOFFILE'
from fastapi import APIRouter

router = APIRouter()

@router.get("/health")
def health():
    return {
        "status": "ok",
        "service": "AN-RA Backend",
        "phase": 4
    }
ENDOFFILE

cat > "anra-workspace/backend/app.py" << 'ENDOFFILE'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.health import router as health_router

app = FastAPI(title="AN-RA Workspace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)

@app.on_event("startup")
def startup():
    print("")
    print("AN-RA Backend running at http://localhost:8000")
    print("API docs at http://localhost:8000/docs")
    print("")
ENDOFFILE

cat > "anra-workspace/frontend/package.json" << 'ENDOFFILE'
{
  "name": "anra-workspace",
  "version": "1.0.0",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.2.0",
    "vite": "^5.0.0"
  }
}
ENDOFFILE

cat > "anra-workspace/frontend/vite.config.js" << 'ENDOFFILE'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, '')
      }
    }
  }
})
ENDOFFILE

cat > "anra-workspace/frontend/index.html" << 'ENDOFFILE'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>AN·RA Workspace</title>
    <style>body{background:#020308;margin:0}</style>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
ENDOFFILE

cat > "anra-workspace/frontend/src/main.jsx" << 'ENDOFFILE'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './App.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
)
ENDOFFILE

cat > "anra-workspace/frontend/src/App.css" << 'ENDOFFILE'
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;700&family=Cinzel:wght@400;700&family=Inter:wght@300;400;500;600&display=swap');

:root {
  --bg: #020308;
  --tx: #b8bcd0;
  --hi: #e8eaf6;
  --dim: #4a5070;
  --gold: #ffc93c;
  --cyan: #00e5ff;
  --plasma: #b040ff;
  --ember: #ff5e1a;
  --green: #00ff9f;
  --red: #ff3860;
  --b1: rgba(255,255,255,.07);
  --s1: rgba(255,255,255,.03);
  --s2: rgba(255,255,255,.055);
}

*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background: var(--bg);
  color: var(--tx);
  font-family: Inter, system-ui, sans-serif;
  font-weight: 300;
  -webkit-font-smoothing: antialiased;
}

.app {
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 24px;
  padding: 24px;
}

.app-name {
  font-family: Cinzel, serif;
  font-size: 2.4rem;
  color: white;
  letter-spacing: 8px;
  text-align: center;
}

.app-name span {
  color: var(--gold);
}

.status-box {
  border: 1px solid var(--b1);
  border-radius: 14px;
  padding: 32px 48px;
  background: rgba(255,255,255,.02);
  text-align: center;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  min-width: 320px;
}

.status-row {
  display: flex;
  align-items: center;
  gap: 10px;
}

.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.dot-green {
  background: var(--green);
  box-shadow: 0 0 10px var(--green);
}

.dot-red {
  background: var(--red);
  box-shadow: 0 0 10px var(--red);
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.25; }
}

.dot-gold {
  background: var(--gold);
  animation: pulse 1.2s ease-in-out infinite;
}

.status-text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.78em;
  color: var(--hi);
  letter-spacing: 1.5px;
}

.status-sub {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  color: var(--dim);
  letter-spacing: 1px;
  margin-top: 4px;
}
ENDOFFILE

cat > "anra-workspace/frontend/src/api.js" << 'ENDOFFILE'
// ALL backend calls go through this file only.
// Never call fetch() from any component directly.

const BASE = '/api'

export const healthCheck = async () => {
  const res = await fetch(`${BASE}/health`)
  if (!res.ok) throw new Error('Backend offline')
  return res.json()
}
ENDOFFILE

cat > "anra-workspace/frontend/src/App.jsx" << 'ENDOFFILE'
import { useState, useEffect } from 'react'
import { healthCheck } from './api'

export default function App() {
  const [status, setStatus] = useState('checking')
  const [info, setInfo] = useState(null)

  useEffect(() => {
    healthCheck()
      .then((data) => {
        setInfo(data)
        setStatus('connected')
      })
      .catch(() => {
        setStatus('offline')
      })
  }, [])

  return (
    <div className="app">
      <div className="app-name">
        AN·<span>RA</span>
      </div>

      <div className="status-box">
        {status === 'checking' && (
          <div className="status-row">
            <div className="dot dot-gold" />
            <span className="status-text">CONNECTING TO AN·RA...</span>
          </div>
        )}

        {status === 'connected' && (
          <>
            <div className="status-row">
              <div className="dot dot-green" />
              <span className="status-text">BACKEND CONNECTED</span>
            </div>
            <div className="status-sub">
              {info.service} · PHASE {info.phase}
            </div>
          </>
        )}

        {status === 'offline' && (
          <>
            <div className="status-row">
              <div className="dot dot-red" />
              <span className="status-text">BACKEND OFFLINE</span>
            </div>
            <div className="status-sub">
              Run uvicorn app:app --reload --port 8000
            </div>
          </>
        )}
      </div>
    </div>
  )
}
ENDOFFILE

echo ""
echo "╔═══════════════════════════════════════╗"
echo "║        PHASE 1 COMPLETE ✓             ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Folders created:                     ║"
echo "║  anra-workspace/backend/              ║"
echo "║  anra-workspace/backend/routes/       ║"
echo "║  anra-workspace/backend/services/     ║"
echo "║  anra-workspace/backend/db/           ║"
echo "║  anra-workspace/frontend/             ║"
echo "║  anra-workspace/frontend/src/         ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Files created:                       ║"
echo "║  backend/app.py                       ║"
echo "║  backend/config.py                    ║"
echo "║  backend/requirements.txt             ║"
echo "║  backend/.env.example                 ║"
echo "║  backend/routes/__init__.py           ║"
echo "║  backend/routes/health.py             ║"
echo "║  backend/services/__init__.py         ║"
echo "║  backend/db/__init__.py               ║"
echo "║  frontend/index.html                  ║"
echo "║  frontend/package.json                ║"
echo "║  frontend/vite.config.js              ║"
echo "║  frontend/src/main.jsx                ║"
echo "║  frontend/src/App.jsx                 ║"
echo "║  frontend/src/App.css                 ║"
echo "║  frontend/src/api.js                  ║"
echo "╠═══════════════════════════════════════╣"
echo "║  NEXT STEPS:                          ║"
echo "║  1. cd anra-workspace/backend         ║"
echo "║  2. pip install -r requirements.txt   ║"
echo "║  3. uvicorn app:app --reload          ║"
echo "║  4. open new terminal                 ║"
echo "║  5. cd anra-workspace/frontend        ║"
echo "║  6. npm install && npm run dev        ║"
echo "║  7. open http://localhost:5173        ║"
echo "╠═══════════════════════════════════════╣"
echo "║  Paste this script output back to     ║"
echo "║  your orchestrator before Phase 2     ║"
echo "╚═══════════════════════════════════════╝"
