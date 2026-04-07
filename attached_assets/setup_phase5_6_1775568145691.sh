#!/bin/bash
set -e

if [ ! -d "anra-workspace" ]; then
  echo "ERROR: Run from folder containing anra-workspace/"
  exit 1
fi

mkdir -p anra-workspace/backend/data
mkdir -p anra-workspace/backend/routes
mkdir -p anra-workspace/frontend/src/store
mkdir -p anra-workspace/frontend/src/components
mkdir -p anra-workspace/frontend/src/panels

# ═══════════════════════════════════════════════════════
# PHASE 5 — BUILD PANEL
# ═══════════════════════════════════════════════════════

cat > "anra-workspace/backend/routes/build.py" << 'ENDOFFILE'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_code_prompt
from config import DEFAULT_MODEL

router = APIRouter()

VALID_MODES = ["numpy", "pytorch", "fastapi", "algo", "explain", "general"]


class CodeRequest(BaseModel):
    prompt: str
    mode: str = "general"
    model: str = DEFAULT_MODEL
    max_tokens: int = 3000


class CodeResponse(BaseModel):
    code: str
    mode: str
    model_used: str
    prompt_echo: str


@router.get("/ping")
def build_ping():
    return {
        "status": "build online",
        "modes": ["numpy", "pytorch", "fastapi", "algo", "explain", "general"]
    }


@router.post("/code", response_model=CodeResponse)
async def generate_code(req: CodeRequest):
    if req.mode not in VALID_MODES:
        raise HTTPException(status_code=400, detail="Invalid mode")
    try:
        system = build_code_prompt(task=req.prompt, mode=req.mode)
        messages = [{"role": "user", "content": req.prompt}]
        result = await call_ai_with_fallback(
            messages, system, req.model, max_tokens=req.max_tokens
        )
        return CodeResponse(
            code=result["reply"],
            mode=req.mode,
            model_used=result["model_used"],
            prompt_echo=req.prompt[:60]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Build failed: {str(e)}")
ENDOFFILE

cat > "anra-workspace/frontend/src/store/buildStore.js" << 'ENDOFFILE'
import { create } from 'zustand'
import { generateCode, saveToVault } from '../api'

const useBuildStore = create((set, get) => ({
  results: [],
  busy: false,
  error: null,
  activeMode: 'general',

  setActiveMode: (mode) => set({ activeMode: mode }),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearResults: () => set({ results: [] }),

  generate: async (prompt, mode, model) => {
    set({ busy: true, error: null })
    try {
      const data = await generateCode(prompt, mode, model)
      const result = {
        id: Date.now(),
        prompt: data.prompt_echo,
        mode: data.mode,
        code: data.code,
        model_used: data.model_used,
        timestamp: new Date().toISOString()
      }
      set((s) => ({ results: [result, ...s.results] }))
    } catch (e) {
      set({ error: e.message })
    } finally {
      set({ busy: false })
    }
  },

  saveResultToVault: async (resultId) => {
    const result = get().results.find(r => r.id === resultId)
    if (!result) return
    await saveToVault(result.prompt, result.code)
  },
}))

export default useBuildStore
ENDOFFILE

cat > "anra-workspace/frontend/src/components/CodeBlock.jsx" << 'ENDOFFILE'
import React, { useState } from 'react'
import './CodeBlock.css'

const KEYWORDS = new Set([
  'def','class','import','from','return','if','else','elif',
  'for','while','async','await','with','as','try','except',
  'True','False','None','in','not','and','or','pass','raise',
  'yield','lambda','global','nonlocal','del','is','break','continue'
])

function tokenizeLine(line) {
  const tokens = []

  // Comment
  const commentIdx = line.indexOf('#')
  if (commentIdx !== -1) {
    const pre = line.slice(0, commentIdx)
    const comment = line.slice(commentIdx)
    if (pre) tokens.push(...tokenizeLine(pre))
    tokens.push({ type: 'comment', value: comment })
    return tokens
  }

  // Decorator
  if (line.trimStart().startsWith('@')) {
    tokens.push({ type: 'decorator', value: line })
    return tokens
  }

  const re = /("""[\s\S]*?"""|'''[\s\S]*?'''|"[^"]*"|'[^']*'|\b\d+\.?\d*\b|[A-Za-z_]\w*\s*(?=\()|[A-Za-z_]\w*|[^\w\s]|\s+)/g
  let m
  while ((m = re.exec(line)) !== null) {
    const val = m[0]
    if (/^("""[\s\S]*?"""|'''[\s\S]*?'''|"[^"]*"|'[^']*')$/.test(val)) {
      tokens.push({ type: 'string', value: val })
    } else if (/^\d+\.?\d*$/.test(val)) {
      tokens.push({ type: 'number', value: val })
    } else if (/^[A-Za-z_]\w*\s*\($/.test(val)) {
      const name = val.replace(/\s*\($/, '')
      tokens.push({ type: 'function', value: name })
      tokens.push({ type: 'plain', value: val.slice(name.length) })
    } else if (KEYWORDS.has(val.trim()) && /^[A-Za-z_]\w*$/.test(val.trim())) {
      tokens.push({ type: 'keyword', value: val })
    } else {
      tokens.push({ type: 'plain', value: val })
    }
  }
  return tokens
}

const TOKEN_CLASSES = {
  keyword:   'tok-keyword',
  string:    'tok-string',
  comment:   'tok-comment',
  number:    'tok-number',
  function:  'tok-function',
  decorator: 'tok-decorator',
  plain:     'tok-plain',
}

export default function CodeBlock({ code = '', language = 'python' }) {
  const [copied, setCopied] = useState(false)

  const handleCopy = () => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }

  const lines = code.split('\n')

  return (
    <div className="codeblock">
      <div className="codeblock__header">
        <span className="codeblock__lang">{language.toUpperCase()}</span>
        <button className="codeblock__copy" onClick={handleCopy}>
          {copied ? 'COPIED ✓' : 'COPY'}
        </button>
      </div>
      <div className="codeblock__body">
        <div className="codeblock__numbers">
          {lines.map((_, i) => (
            <div key={i} className="codeblock__lineno">{i + 1}</div>
          ))}
        </div>
        <pre className="codeblock__code">
          {lines.map((line, i) => {
            const tokens = tokenizeLine(line)
            return (
              <div key={i} className="codeblock__line">
                {tokens.map((tok, j) => (
                  <span key={j} className={TOKEN_CLASSES[tok.type] || 'tok-plain'}>
                    {tok.value}
                  </span>
                ))}
              </div>
            )
          })}
        </pre>
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/components/CodeBlock.css" << 'ENDOFFILE'
.codeblock {
  border: 1px solid rgba(0, 229, 255, 0.1);
  border-radius: 10px;
  overflow: hidden;
  margin: 8px 0;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.8em;
}

.codeblock__header {
  background: rgba(255, 255, 255, 0.03);
  border-bottom: 1px solid var(--b1);
  padding: 8px 14px;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.codeblock__lang {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  color: var(--dim);
  letter-spacing: 2px;
}

.codeblock__copy {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  color: var(--cyan);
  background: transparent;
  border: 1px solid rgba(0, 229, 255, 0.2);
  border-radius: 4px;
  padding: 3px 10px;
  cursor: pointer;
  letter-spacing: 1px;
  transition: all 0.2s;
}

.codeblock__copy:hover {
  background: rgba(0, 229, 255, 0.08);
}

.codeblock__copy:active {
  transform: scale(0.97);
}

.codeblock__body {
  display: flex;
  background: rgba(0, 0, 0, 0.55);
  overflow-x: auto;
}

.codeblock__numbers {
  display: flex;
  flex-direction: column;
  padding: 16px 0;
  min-width: 32px;
  border-right: 1px solid var(--b1);
  margin-right: 16px;
  user-select: none;
  flex-shrink: 0;
}

.codeblock__lineno {
  color: var(--dim);
  font-size: 0.75em;
  text-align: right;
  padding-right: 16px;
  line-height: 1.8;
}

.codeblock__code {
  flex: 1;
  padding: 16px 0;
  margin: 0;
  line-height: 1.8;
  white-space: pre;
  overflow-x: auto;
  background: transparent;
  border: none;
}

.codeblock__line {
  display: block;
  min-height: 1.8em;
}

/* Token colors */
.tok-keyword  { color: var(--plasma); }
.tok-string   { color: var(--gold); }
.tok-comment  { color: var(--dim); font-style: italic; }
.tok-number   { color: var(--ember); }
.tok-function { color: var(--cyan); }
.tok-decorator{ color: var(--green); }
.tok-plain    { color: #e2e8f0; }
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/BuildPanel.jsx" << 'ENDOFFILE'
import React, { useState } from 'react'
import useBuildStore from '../store/buildStore'
import useAppStore from '../store/appStore'
import CodeBlock from '../components/CodeBlock'
import Markdown from '../components/Markdown'
import './BuildPanel.css'

const MODES = [
  { id: 'numpy',   label: 'NUMPY',   color: 'var(--cyan)' },
  { id: 'pytorch', label: 'PYTORCH', color: 'var(--plasma)' },
  { id: 'fastapi', label: 'FASTAPI', color: 'var(--green)' },
  { id: 'algo',    label: 'ALGO',    color: 'var(--gold)' },
  { id: 'explain', label: 'EXPLAIN', color: 'var(--ember)' },
  { id: 'general', label: 'GENERAL', color: 'var(--hi)' },
]

function splitContent(content) {
  return content.split(/(```[\s\S]*?```)/g).map((part, i) => {
    if (part.startsWith('```') && part.endsWith('```')) {
      const inner = part.slice(3, -3)
      const firstLine = inner.split('\n')[0]
      const lang = /^[a-zA-Z]+$/.test(firstLine.trim()) ? firstLine.trim() : 'python'
      const code = /^[a-zA-Z]+$/.test(firstLine.trim())
        ? inner.slice(firstLine.length + 1)
        : inner
      return <CodeBlock key={i} code={code} language={lang} />
    }
    return <Markdown key={i} content={part} />
  })
}

export default function BuildPanel() {
  const results     = useBuildStore((s) => s.results)
  const busy        = useBuildStore((s) => s.busy)
  const error       = useBuildStore((s) => s.error)
  const activeMode  = useBuildStore((s) => s.activeMode)
  const generate    = useBuildStore((s) => s.generate)
  const setMode     = useBuildStore((s) => s.setActiveMode)
  const clearResults= useBuildStore((s) => s.clearResults)
  const saveToVault = useBuildStore((s) => s.saveResultToVault)

  const model = useAppStore((s) => s.model)

  const [prompt, setPrompt] = useState('')
  const [saved, setSaved]   = useState({})

  const handleGenerate = async () => {
    if (!prompt.trim() || busy) return
    await generate(prompt.trim(), activeMode, model)
    setPrompt('')
  }

  const handleSave = async (id) => {
    await saveToVault(id)
    setSaved((s) => ({ ...s, [id]: true }))
    setTimeout(() => setSaved((s) => ({ ...s, [id]: false })), 2000)
  }

  const modeColor = MODES.find(m => m.id === activeMode)?.color || 'var(--hi)'

  return (
    <div className="build-panel">
      <div className="build-left">
        <div className="build-header">
          <div className="build-title">
            <span className="build-name">AN·<span>RA</span></span>
            <span className="build-tag">BUILD · CODE GENERATION</span>
          </div>
        </div>

        <div className="build-modes">
          {MODES.map((m) => (
            <button
              key={m.id}
              className={`mode-btn${activeMode === m.id ? ' mode-btn--active' : ''}`}
              style={activeMode === m.id ? {
                color: m.color,
                borderColor: m.color,
                background: m.color.replace(')', ', .08)').replace('var(', 'color-mix(in srgb, ').replace('var(--', 'var(--'),
              } : {}}
              onClick={() => setMode(m.id)}
            >
              {m.label}
            </button>
          ))}
        </div>

        <textarea
          className="build-textarea"
          value={prompt}
          onChange={(e) => setPrompt(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault()
              handleGenerate()
            }
          }}
          placeholder={"Describe what you want to build...\n\nExample: Write a numpy function to normalize a batch of vectors"}
          disabled={busy}
        />

        <button
          className="generate-btn"
          onClick={handleGenerate}
          disabled={busy || !prompt.trim()}
        >
          {busy ? 'GENERATING...' : 'GENERATE CODE'}
        </button>

        <div className="build-model-info">
          MODEL: {model.split('/').pop().toUpperCase()}
        </div>

        {error && <div className="build-error">⚠ {error}</div>}
      </div>

      <div className="build-right">
        {results.length === 0 && !busy && (
          <div className="build-empty">
            <div className="build-empty__icon">⟨/⟩</div>
            <div className="build-empty__text">Generated code appears here</div>
          </div>
        )}

        {busy && (
          <div className="build-generating">
            <span className="gen-label">AN·RA is writing code</span>
            <span className="gen-dots">
              <span /><span /><span />
            </span>
          </div>
        )}

        {results.map((r) => (
          <div key={r.id} className="result-card">
            <div className="result-card__header">
              <span className="result-prompt">{r.prompt}…</span>
              <div className="result-badges">
                <span className="badge badge--mode">{r.mode.toUpperCase()}</span>
                <span className="badge badge--model">{r.model_used.split('/').pop()}</span>
              </div>
            </div>
            <div className="result-card__body">
              {splitContent(r.code)}
            </div>
            <div className="result-card__footer">
              <button
                className={`vault-btn${saved[r.id] ? ' vault-btn--saved' : ''}`}
                onClick={() => handleSave(r.id)}
              >
                {saved[r.id] ? 'SAVED ✓' : '⊞ SAVE TO VAULT'}
              </button>
              <button className="clear-btn" onClick={clearResults}>
                CLEAR
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/BuildPanel.css" << 'ENDOFFILE'
.build-panel {
  display: grid;
  grid-template-columns: 360px 1fr;
  gap: 0;
  min-height: calc(100vh - 108px);
  overflow: hidden;
}

@media (max-width: 768px) {
  .build-panel {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }
}

/* ── LEFT ── */
.build-left {
  border-right: 1px solid var(--b1);
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  position: sticky;
  top: 104px;
  height: calc(100vh - 108px);
  overflow-y: auto;
}

.build-header {
  padding-bottom: 12px;
  border-bottom: 1px solid var(--b1);
}

.build-title {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.build-name {
  font-family: 'Cinzel', serif;
  font-size: 1.1rem;
  color: white;
  letter-spacing: 4px;
}

.build-name span { color: var(--gold); }

.build-tag {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  color: var(--dim);
  letter-spacing: 2px;
}

/* ── MODES ── */
.build-modes {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.mode-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1.5px;
  padding: 6px 14px;
  border-radius: 20px;
  border: 1px solid var(--b1);
  background: transparent;
  color: var(--dim);
  cursor: pointer;
  transition: all 0.2s;
}

.mode-btn:hover { color: var(--tx); border-color: var(--tx); }
.mode-btn--active { font-weight: 500; }

/* ── INPUTS ── */
.build-textarea {
  width: 100%;
  min-height: 160px;
  resize: vertical;
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--b1);
  border-radius: 10px;
  color: var(--hi);
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.88em;
  padding: 12px 14px;
  outline: none;
  transition: border-color 0.2s;
  line-height: 1.6;
}

.build-textarea:focus { border-color: rgba(176, 64, 255, 0.4); }
.build-textarea::placeholder { color: var(--dim); }

.generate-btn {
  width: 100%;
  background: linear-gradient(135deg, var(--plasma), var(--cyan));
  color: #000;
  border: none;
  border-radius: 8px;
  padding: 13px;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.65em;
  font-weight: 700;
  letter-spacing: 2px;
  cursor: pointer;
  transition: opacity 0.2s;
}

.generate-btn:hover:not(:disabled) { opacity: 0.85; }
.generate-btn:disabled { opacity: 0.4; cursor: not-allowed; }

.build-model-info {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  color: var(--dim);
  letter-spacing: 1px;
  text-align: center;
}

.build-error {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7em;
  color: var(--red);
  padding: 8px 12px;
  border: 1px solid rgba(255, 56, 96, 0.2);
  border-radius: 6px;
}

/* ── RIGHT ── */
.build-right {
  padding: 20px;
  overflow-y: auto;
  height: calc(100vh - 108px);
}

.build-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60%;
  gap: 16px;
}

.build-empty__icon {
  font-size: 2.5rem;
  color: var(--dim);
  opacity: 0.3;
}

.build-empty__text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--dim);
  letter-spacing: 1.5px;
}

/* ── GENERATING ── */
.build-generating {
  display: flex;
  align-items: center;
  gap: 12px;
  border: 1px solid rgba(176, 64, 255, 0.3);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
  animation: borderPulse 1.5s ease-in-out infinite;
}

@keyframes borderPulse {
  0%, 100% { border-color: rgba(176, 64, 255, 0.3); }
  50%       { border-color: rgba(176, 64, 255, 0.9); }
}

.gen-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--plasma);
  letter-spacing: 1px;
}

.gen-dots {
  display: flex;
  gap: 4px;
}

.gen-dots span {
  display: block;
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--plasma);
  animation: dot-pulse 1.2s ease-in-out infinite;
}

.gen-dots span:nth-child(2) { animation-delay: 0.2s; }
.gen-dots span:nth-child(3) { animation-delay: 0.4s; }

@keyframes dot-pulse {
  0%, 100% { opacity: 0.2; transform: scale(0.8); }
  50%       { opacity: 1;   transform: scale(1.2); }
}

/* ── RESULT CARDS ── */
.result-card {
  border: 1px solid var(--b1);
  border-radius: 12px;
  overflow: hidden;
  background: var(--s1);
  margin-bottom: 16px;
  animation: fadeUp 0.25s ease;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

.result-card__header {
  background: rgba(255, 255, 255, 0.02);
  border-bottom: 1px solid var(--b1);
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}

.result-prompt {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.82em;
  color: var(--tx);
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.result-badges { display: flex; gap: 6px; }

.badge {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  letter-spacing: 1px;
  padding: 3px 8px;
  border-radius: 4px;
}

.badge--mode  { color: var(--plasma); border: 1px solid rgba(176, 64, 255, 0.3); }
.badge--model { color: var(--dim);    border: 1px solid var(--b1); }

.result-card__body { padding: 16px; }

.result-card__footer {
  padding: 12px 16px;
  border-top: 1px solid var(--b1);
  display: flex;
  gap: 10px;
}

.vault-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1px;
  padding: 5px 12px;
  border-radius: 5px;
  border: 1px solid rgba(255, 201, 60, 0.25);
  background: transparent;
  color: var(--gold);
  cursor: pointer;
  transition: all 0.2s;
}

.vault-btn:hover { background: rgba(255, 201, 60, 0.08); }
.vault-btn--saved { color: var(--green); border-color: rgba(0, 255, 159, 0.3); }

.clear-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1px;
  padding: 5px 12px;
  border-radius: 5px;
  border: 1px solid var(--b1);
  background: transparent;
  color: var(--dim);
  cursor: pointer;
  transition: all 0.2s;
}

.clear-btn:hover { color: var(--tx); border-color: var(--tx); }
ENDOFFILE

# ═══════════════════════════════════════════════════════
# PHASE 6 — ALL REMAINING PANELS + FINAL WIRING
# ═══════════════════════════════════════════════════════

cat > "anra-workspace/backend/data/phases.json" << 'ENDOFFILE'
{
  "project": "AN-RA Workspace",
  "current_phase": 4,
  "phases": [
    {
      "number": 1,
      "title": "Foundation",
      "status": "complete",
      "description": "Core reasoning engine, base architecture",
      "modules": ["symbolic_core","base_memory","logic_engine"],
      "completion": 100
    },
    {
      "number": 2,
      "title": "Language Interface",
      "status": "complete",
      "description": "Natural language processing layer",
      "modules": ["nlp_bridge","token_processor","context_window"],
      "completion": 100
    },
    {
      "number": 3,
      "title": "Memory Systems",
      "status": "complete",
      "description": "Short and long-term memory architecture",
      "modules": ["ghost_memory","session_store","compression"],
      "completion": 100
    },
    {
      "number": 4,
      "title": "Workspace Integration",
      "status": "active",
      "description": "Full workspace UI, code gen, lab, vault",
      "modules": ["chat_engine","code_gen","lab_mode","vault"],
      "completion": 65
    },
    {
      "number": 5,
      "title": "Ouroboros Engine",
      "status": "planned",
      "description": "Self-improving reasoning loop",
      "modules": ["ouroboros","self_eval","recursive_improve"],
      "completion": 0
    },
    {
      "number": 6,
      "title": "Symbolic Bridge",
      "status": "planned",
      "description": "Symbolic + neural hybrid reasoning",
      "modules": ["symbolic_bridge","sat_solver","proof_engine"],
      "completion": 0
    }
  ],
  "stats": {
    "total_phases": 6,
    "complete": 3,
    "active": 1,
    "planned": 2,
    "overall_completion": 42
  }
}
ENDOFFILE

cat > "anra-workspace/backend/data/cosmos.json" << 'ENDOFFILE'
{
  "sections": {
    "india": {
      "title": "India Space Program",
      "accent": "#ff5e1a",
      "summary": "ISRO journey from humble beginnings to landing on the Moons south pole",
      "facts": [
        "Chandrayaan-3 landed near lunar south pole August 2023 — a world first",
        "Mangalyaan reached Mars on first attempt 2014, cost less than the film Gravity",
        "Gaganyaan will make India 4th nation to send humans to space",
        "ISRO operates on budget 10x smaller than NASA per mission",
        "NAVIC satellite navigation covers entire Asian region"
      ],
      "missions": ["Chandrayaan-3","Mangalyaan","Aditya-L1","Gaganyaan"],
      "next": "Chandrayaan-4 sample return 2027"
    },
    "mars": {
      "title": "Mars Colonisation",
      "accent": "#ff3860",
      "summary": "The path to making humanity multiplanetary",
      "facts": [
        "Mars day is 24 hours 37 minutes",
        "Starship designed to carry 100 people per flight",
        "Mars has enough CO2 to terraform over centuries",
        "Journey takes 6-9 months depending on alignment",
        "Olympus Mons is 22km high largest volcano in solar system"
      ],
      "missions": ["Perseverance","Ingenuity","Starship","Mars Base Alpha"],
      "next": "First crewed Mars mission early 2030s"
    },
    "sun": {
      "title": "Solar Science",
      "accent": "#ffc93c",
      "summary": "Understanding the star that powers all life",
      "facts": [
        "Sun contains 99.86 percent of all solar system mass",
        "Solar wind travels 400-800 km per second",
        "Solar flare releases energy of billions of bombs",
        "Core temperature is 15 million degrees Celsius",
        "Aditya-L1 is India first solar observatory at L1"
      ],
      "missions": ["Parker Solar Probe","Solar Orbiter","Aditya-L1"],
      "next": "Parker Solar Probe touches corona 2025"
    },
    "raptor": {
      "title": "Raptor Engine",
      "accent": "#b040ff",
      "summary": "The most powerful rocket engine ever built",
      "facts": [
        "Raptor 3 produces 280 tonnes of thrust",
        "Burns liquid methane and liquid oxygen",
        "Full-flow staged combustion near perfect efficiency",
        "33 Raptors power Starship Super Heavy booster",
        "SpaceX caught booster with mechazilla October 2024"
      ],
      "missions": ["Starship","Super Heavy"],
      "next": "Raptor 3 powers first orbital Starship missions"
    },
    "universe": {
      "title": "Universe and Cosmology",
      "accent": "#00e5ff",
      "summary": "The scale age and structure of everything",
      "facts": [
        "Observable universe is 93 billion light-years wide",
        "More stars than grains of sand on all Earth beaches",
        "Universe is 13.8 billion years old",
        "Dark matter makes up 27 percent of universe",
        "JWST sees galaxies from 300 million years after Big Bang"
      ],
      "missions": ["James Webb","Hubble","Euclid"],
      "next": "Euclid mapping dark matter across 10 billion light-years"
    },
    "ai": {
      "title": "AI and Intelligence",
      "accent": "#00ff9f",
      "summary": "Evolution of machine intelligence and what comes next",
      "facts": [
        "Transformers invented 2017 all LLMs descend from it",
        "AlphaFold solved 50-year protein folding problem 2020",
        "Human brain has 86 billion neurons",
        "GPT-4 uses mixture-of-experts architecture",
        "AN-RA bridges symbolic reasoning with neural models"
      ],
      "models": ["GPT-4o","Claude 3","Gemini","Llama 3","AN-RA"],
      "next": "Reasoning models solving novel math theorems"
    }
  }
}
ENDOFFILE

cat > "anra-workspace/backend/routes/lab.py" << 'ENDOFFILE'
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_lab_prompt
from config import DEFAULT_MODEL

router = APIRouter()

VALID_MODES = ["analyze", "compare", "future", "build", "free"]


class LabRequest(BaseModel):
    idea: str
    mode: str = "analyze"
    model: str = DEFAULT_MODEL
    context: str = ""


class LabResponse(BaseModel):
    result: str
    mode: str
    model_used: str
    idea_echo: str


@router.get("/ping")
def lab_ping():
    return {
        "status": "lab online",
        "modes": ["analyze", "compare", "future", "build", "free"]
    }


@router.post("/run", response_model=LabResponse)
async def run_lab(req: LabRequest):
    if req.mode not in VALID_MODES:
        raise HTTPException(status_code=400, detail="Invalid lab mode")
    try:
        system = build_lab_prompt(mode=req.mode)
        if req.context:
            system += f"\n\nAdditional context:\n{req.context}"
        messages = [{"role": "user", "content": req.idea}]
        result = await call_ai_with_fallback(
            messages, system, req.model, max_tokens=3000
        )
        return LabResponse(
            result=result["reply"],
            mode=req.mode,
            model_used=result["model_used"],
            idea_echo=req.idea[:80]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lab failed: {str(e)}")
ENDOFFILE

cat > "anra-workspace/backend/routes/cosmos.py" << 'ENDOFFILE'
import json
import os
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from config import DEFAULT_MODEL

router = APIRouter()

DATA_PATH = os.path.join(os.path.dirname(__file__), "../data/cosmos.json")
with open(DATA_PATH, "r") as f:
    COSMOS = json.load(f)


class CosmosAskRequest(BaseModel):
    question: str
    category: str = "universe"


@router.get("/sections")
def get_sections():
    sections = [
        {
            "key": key,
            "title": val["title"],
            "accent": val["accent"]
        }
        for key, val in COSMOS["sections"].items()
    ]
    return {"sections": sections}


@router.get("/{category}")
def get_category(category: str):
    if category not in COSMOS["sections"]:
        raise HTTPException(status_code=404, detail="Category not found")
    return COSMOS["sections"][category]


@router.post("/ask")
async def ask_cosmos(req: CosmosAskRequest):
    section = COSMOS["sections"].get(req.category)
    if not section:
        section = COSMOS["sections"]["universe"]
    facts_text = "\n".join(section.get("facts", []))
    system = (
        f"You are AN-RA in cosmos exploration mode.\n"
        f"Deep knowledge of space, science, universe.\n"
        f"Precise, awe-inspiring, factually grounded.\n"
        f"Current topic: {section['title']}\n"
        f"Known facts about this topic:\n{facts_text}\n"
        f"Respond with depth. Use specific numbers."
    )
    messages = [{"role": "user", "content": req.question}]
    result = await call_ai_with_fallback(messages, system, DEFAULT_MODEL)
    return {
        "answer": result["reply"],
        "model_used": result["model_used"],
        "category": req.category
    }
ENDOFFILE

cat > "anra-workspace/backend/routes/insights.py" << 'ENDOFFILE'
from fastapi import APIRouter
from services.ai_client import call_ai
from db.database import SessionLocal
from db.models import ChatMessage, VaultItem

router = APIRouter()


@router.get("/probe")
async def probe():
    system = (
        "You are AN-RA. Generate one short profound insight about "
        "intelligence, consciousness, space, mathematics, or reality. "
        "Maximum 3 sentences. Be original. Be precise. No cliches."
    )
    messages = [{"role": "user", "content": "Generate insight."}]
    reply = await call_ai(messages, system, max_tokens=200)
    return {"insight": reply}


@router.get("/stats")
def stats():
    db = SessionLocal()
    try:
        total_messages = db.query(ChatMessage).count()
        total_sessions = db.query(ChatMessage.session_id).distinct().count()
        vault_items = db.query(VaultItem).count()
    finally:
        db.close()
    return {
        "total_messages": total_messages,
        "total_sessions": total_sessions,
        "vault_items": vault_items,
        "total_builds": 0
    }
ENDOFFILE

cat > "anra-workspace/backend/app.py" << 'ENDOFFILE'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import init_db
from routes.health import router as health_router
from routes.chat import router as chat_router
from routes.vault import router as vault_router
from routes.build import router as build_router
from routes.lab import router as lab_router
from routes.cosmos import router as cosmos_router
from routes.insights import router as insights_router

app = FastAPI(title="AN-RA Workspace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(chat_router,    prefix="/chat")
app.include_router(vault_router,   prefix="/vault")
app.include_router(build_router,   prefix="/build")
app.include_router(lab_router,     prefix="/lab")
app.include_router(cosmos_router,  prefix="/cosmos")
app.include_router(insights_router, prefix="/insights")


@app.on_event("startup")
def startup():
    init_db()
    print("")
    print("AN-RA Workspace — All systems online")
    print("http://localhost:8000")
    print("http://localhost:8000/docs")
    print("")
ENDOFFILE

cat > "anra-workspace/frontend/src/store/labStore.js" << 'ENDOFFILE'
import { create } from 'zustand'
import { runLab, saveToVault } from '../api'

const useLabStore = create((set, get) => ({
  results: [],
  busy: false,
  error: null,
  activeMode: 'analyze',

  setActiveMode: (mode) => set({ activeMode: mode }),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearResults: () => set({ results: [] }),

  run: async (idea, mode, model, context = '') => {
    set({ busy: true, error: null })
    try {
      const data = await runLab(idea, mode, model, context)
      const result = {
        id: Date.now(),
        idea: data.idea_echo,
        mode: data.mode,
        result: data.result,
        model_used: data.model_used,
        timestamp: new Date().toISOString()
      }
      set((s) => ({ results: [result, ...s.results] }))
    } catch (e) {
      set({ error: e.message })
    } finally {
      set({ busy: false })
    }
  },

  saveToVault: async (resultId) => {
    const r = get().results.find(x => x.id === resultId)
    if (!r) return
    await saveToVault(r.idea, r.result)
  },
}))

export default useLabStore
ENDOFFILE

cat > "anra-workspace/frontend/src/store/cosmosStore.js" << 'ENDOFFILE'
import { create } from 'zustand'
import { getCosmosSections, getCosmosSection,
         askCosmos, getInsight } from '../api'

const useCosmosStore = create((set, get) => ({
  sections: [],
  activeSection: 'universe',
  sectionData: null,
  conversation: [],
  busy: false,
  insight: '',

  setActiveSection: (key) => set({ activeSection: key }),
  setBusy: (busy) => set({ busy }),
  setInsight: (text) => set({ insight: text }),

  loadSections: async () => {
    const data = await getCosmosSections()
    set({ sections: data.sections })
  },

  loadSection: async (key) => {
    set({ busy: true, conversation: [] })
    try {
      const data = await getCosmosSection(key)
      set({ sectionData: data, activeSection: key })
    } finally {
      set({ busy: false })
    }
  },

  ask: async (question) => {
    set({ busy: true })
    set((s) => ({
      conversation: [...s.conversation,
        { role: 'user', content: question }]
    }))
    try {
      const data = await askCosmos(question, get().activeSection)
      set((s) => ({
        conversation: [...s.conversation,
          { role: 'assistant', content: data.answer }]
      }))
    } finally {
      set({ busy: false })
    }
  },

  fetchInsight: async () => {
    const data = await getInsight()
    set({ insight: data.insight })
  },
}))

export default useCosmosStore
ENDOFFILE

cat > "anra-workspace/frontend/src/api.js" << 'ENDOFFILE'
// ALL backend calls go through this file only.
// Never call fetch() from any component directly.

const BASE = '/api'

const post = async (url, body) => {
  const res = await fetch(`${BASE}${url}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

const get = async (url) => {
  const res = await fetch(`${BASE}${url}`)
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

const del = async (url) => {
  const res = await fetch(`${BASE}${url}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

// HEALTH
export const healthCheck = () => get('/health')

// CHAT
export const newSession    = () => get('/chat/new')
export const sendMessage   = (message, session_id, model) =>
  post('/chat/send', { message, session_id, model, vault_context: '' })
export const getHistory    = (session_id) => get(`/chat/history/${session_id}`)
export const deleteSession = (session_id) => del(`/chat/${session_id}`)

// VAULT
export const getVault       = () => get('/vault')
export const saveToVault    = (title, content) => post('/vault', { title, content })
export const deleteVaultItem= (id) => del(`/vault/${id}`)
export const getVaultCount  = () => get('/vault/count')

// BUILD
export const generateCode = (prompt, mode, model) =>
  post('/build/code', { prompt, mode, model })
export const buildPing = () => get('/build/ping')

// LAB
export const runLab  = (idea, mode, model, context = '') =>
  post('/lab/run', { idea, mode, model, context })
export const labPing = () => get('/lab/ping')

// COSMOS
export const getCosmosSections = () => get('/cosmos/sections')
export const getCosmosSection  = (category) => get(`/cosmos/${category}`)
export const askCosmos         = (question, category) =>
  post('/cosmos/ask', { question, category })

// INSIGHTS
export const getInsight = () => get('/insights/probe')
export const getStats   = () => get('/insights/stats')
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/HomePanel.jsx" << 'ENDOFFILE'
import React, { useState, useEffect } from 'react'
import { getStats, getInsight } from '../api'
import useAppStore from '../store/appStore'
import './HomePanel.css'

const PHASES = [
  { number: 1, title: 'Foundation',         status: 'complete', completion: 100, color: 'var(--green)' },
  { number: 2, title: 'Language Interface', status: 'complete', completion: 100, color: 'var(--green)' },
  { number: 3, title: 'Memory Systems',     status: 'complete', completion: 100, color: 'var(--green)' },
  { number: 4, title: 'Workspace',          status: 'active',   completion: 65,  color: 'var(--cyan)'  },
  { number: 5, title: 'Ouroboros',          status: 'planned',  completion: 0,   color: 'var(--dim)'   },
  { number: 6, title: 'Symbolic Bridge',    status: 'planned',  completion: 0,   color: 'var(--dim)'   },
]

const QUICK = [
  { id: 'mind',   icon: '◈', label: 'MIND',   color: 'var(--cyan)'   },
  { id: 'build',  icon: '⟨/⟩', label: 'BUILD', color: 'var(--plasma)' },
  { id: 'lab',    icon: '⬡', label: 'LAB',    color: 'var(--green)'  },
  { id: 'cosmos', icon: '✦', label: 'COSMOS', color: 'var(--ember)'  },
]

export default function HomePanel() {
  const setActivePanel = useAppStore((s) => s.setActivePanel)
  const [stats,   setStats]   = useState(null)
  const [insight, setInsight] = useState('')
  const [loadingInsight, setLoadingInsight] = useState(false)

  useEffect(() => {
    getStats().then(setStats).catch(() => {})
    fetchInsight()
  }, [])

  const fetchInsight = async () => {
    setLoadingInsight(true)
    try {
      const data = await getInsight()
      setInsight(data.insight)
    } catch (_) {}
    finally { setLoadingInsight(false) }
  }

  return (
    <div className="home-panel fade-in">
      <div className="home-hero">
        <div className="home-wordmark">AN·<span>RA</span></div>
        <div className="home-subtitle">ARTIFICIAL REASONING ARCHITECTURE</div>

        <div className="insight-box">
          <p className="insight-text">
            {loadingInsight ? 'Generating insight...' : insight || ''}
          </p>
          <button className="insight-refresh" onClick={fetchInsight}>
            ↻ NEW INSIGHT
          </button>
        </div>
      </div>

      {stats && (
        <div className="home-stats">
          {[
            { label: 'MESSAGES', value: stats.total_messages },
            { label: 'SESSIONS', value: stats.total_sessions },
            { label: 'VAULT',    value: stats.vault_items    },
            { label: 'PHASE',    value: 4                    },
          ].map((s) => (
            <div key={s.label} className="stat-card">
              <div className="stat-number">{s.value}</div>
              <div className="stat-label">{s.label}</div>
            </div>
          ))}
        </div>
      )}

      <div className="home-section-label">BUILD PROGRESS</div>
      <div className="phase-grid">
        {PHASES.map((p) => (
          <div
            key={p.number}
            className={`phase-card${p.status === 'active' ? ' phase-card--active' : ''}`}
            style={p.status === 'active' ? { borderColor: 'rgba(0,229,255,.3)', boxShadow: '0 0 20px -8px var(--cyan)' } : {}}
          >
            <div className="phase-num" style={{ color: p.color }}>
              PHASE {p.number}
            </div>
            <div className="phase-title">{p.title}</div>
            <div className={`phase-badge phase-badge--${p.status}`}>{p.status}</div>
            <div className="phase-bar-track">
              <div
                className="phase-bar-fill"
                style={{ width: `${p.completion}%`, background: p.color }}
              />
            </div>
          </div>
        ))}
      </div>

      <div className="home-section-label">QUICK ACCESS</div>
      <div className="quick-grid">
        {QUICK.map((q) => (
          <button
            key={q.id}
            className="quick-btn"
            style={{
              borderColor: q.color.replace(')', ', .25)').replace('var(', 'rgba(0,0,0,').replace('rgba(0,0,0,', 'color-mix(in srgb, ').replace('var(--', 'var(--'),
            }}
            onClick={() => setActivePanel(q.id)}
          >
            <span className="quick-icon" style={{ color: q.color }}>{q.icon}</span>
            <span className="quick-label" style={{ color: q.color }}>{q.label}</span>
          </button>
        ))}
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/HomePanel.css" << 'ENDOFFILE'
.home-panel {
  min-height: calc(100vh - 108px);
  overflow-y: auto;
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

/* ── HERO ── */
.home-hero {
  border-radius: 16px;
  padding: 36px 32px 28px;
  background: radial-gradient(ellipse at 50% 0%, rgba(0,229,255,.07) 0%, rgba(176,64,255,.04) 60%, transparent 100%);
  border: 1px solid var(--b1);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 10px;
  text-align: center;
}

.home-wordmark {
  font-family: 'Cinzel', serif;
  font-size: 2.8rem;
  color: white;
  letter-spacing: 8px;
}

.home-wordmark span { color: var(--gold); }

.home-subtitle {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  color: var(--dim);
  letter-spacing: 3px;
}

.insight-box {
  margin-top: 12px;
  width: 100%;
  max-width: 600px;
  border: 1px solid var(--b1);
  border-left: 3px solid var(--cyan);
  border-radius: 0 10px 10px 0;
  padding: 16px 20px;
  background: var(--s1);
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.insight-text {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.92em;
  color: var(--tx);
  font-style: italic;
  line-height: 1.7;
  text-align: left;
}

.insight-refresh {
  align-self: flex-start;
  background: transparent;
  border: 1px solid rgba(0, 229, 255, 0.2);
  border-radius: 5px;
  color: var(--cyan);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  letter-spacing: 1px;
  padding: 4px 12px;
  cursor: pointer;
  transition: all 0.2s;
}

.insight-refresh:hover { background: rgba(0, 229, 255, 0.08); }

/* ── STATS ── */
.home-stats {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

@media (max-width: 600px) {
  .home-stats { grid-template-columns: repeat(2, 1fr); }
}

.stat-card {
  border: 1px solid var(--b1);
  border-radius: 10px;
  padding: 18px;
  background: var(--s1);
  text-align: center;
}

.stat-number {
  font-family: 'JetBrains Mono', monospace;
  font-size: 1.8rem;
  color: var(--hi);
  line-height: 1;
}

.stat-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  color: var(--dim);
  letter-spacing: 2px;
  margin-top: 6px;
}

/* ── SECTION LABEL ── */
.home-section-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  color: var(--dim);
  letter-spacing: 3px;
}

/* ── PHASES ── */
.phase-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
}

@media (max-width: 600px) {
  .phase-grid { grid-template-columns: repeat(2, 1fr); }
}

.phase-card {
  border: 1px solid var(--b1);
  border-radius: 10px;
  padding: 16px;
  background: var(--s1);
  display: flex;
  flex-direction: column;
  gap: 6px;
  transition: box-shadow 0.3s;
}

.phase-num {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  letter-spacing: 1.5px;
}

.phase-title {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.9em;
  color: var(--hi);
}

.phase-badge {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  letter-spacing: 1px;
  padding: 2px 8px;
  border-radius: 20px;
  width: fit-content;
}

.phase-badge--complete { color: var(--green); border: 1px solid rgba(0,255,159,.2); }
.phase-badge--active   { color: var(--cyan);  border: 1px solid rgba(0,229,255,.2); }
.phase-badge--planned  { color: var(--dim);   border: 1px solid var(--b1); }

.phase-bar-track {
  height: 2px;
  background: var(--b1);
  border-radius: 1px;
  margin-top: 4px;
  overflow: hidden;
}

.phase-bar-fill {
  height: 100%;
  border-radius: 1px;
  transition: width 0.6s ease;
}

/* ── QUICK ── */
.quick-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

@media (max-width: 600px) {
  .quick-grid { grid-template-columns: repeat(2, 1fr); }
}

.quick-btn {
  border: 1px solid var(--b1);
  border-radius: 10px;
  padding: 14px;
  background: rgba(255,255,255,.02);
  cursor: pointer;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  transition: all 0.2s;
}

.quick-btn:hover {
  background: rgba(255,255,255,.05);
  transform: translateY(-2px);
}

.quick-icon {
  font-size: 1.4rem;
  line-height: 1;
}

.quick-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  letter-spacing: 2px;
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/LabPanel.jsx" << 'ENDOFFILE'
import React, { useState } from 'react'
import useLabStore from '../store/labStore'
import useAppStore from '../store/appStore'
import Markdown from '../components/Markdown'
import './LabPanel.css'

const MODES = [
  { id: 'analyze', label: 'ANALYZE', color: 'var(--cyan)',   desc: 'Break to first principles' },
  { id: 'compare', label: 'COMPARE', color: 'var(--gold)',   desc: 'Structured comparison + verdict' },
  { id: 'future',  label: 'FUTURE',  color: 'var(--plasma)', desc: 'Project 5, 10, 25 years forward' },
  { id: 'build',   label: 'BUILD',   color: 'var(--green)',  desc: 'Idea to concrete phased plan' },
  { id: 'free',    label: 'FREE',    color: 'var(--hi)',     desc: 'Open-ended deep analysis' },
]

export default function LabPanel() {
  const results     = useLabStore((s) => s.results)
  const busy        = useLabStore((s) => s.busy)
  const error       = useLabStore((s) => s.error)
  const activeMode  = useLabStore((s) => s.activeMode)
  const run         = useLabStore((s) => s.run)
  const setMode     = useLabStore((s) => s.setActiveMode)
  const saveVault   = useLabStore((s) => s.saveToVault)

  const model = useAppStore((s) => s.model)

  const [idea,    setIdea]    = useState('')
  const [context, setContext] = useState('')
  const [showCtx, setShowCtx] = useState(false)
  const [saved,   setSaved]   = useState({})

  const currentMode = MODES.find(m => m.id === activeMode)

  const handleRun = async () => {
    if (!idea.trim() || busy) return
    await run(idea.trim(), activeMode, model, context)
    setIdea('')
  }

  const handleSave = async (id) => {
    await saveVault(id)
    setSaved((s) => ({ ...s, [id]: true }))
    setTimeout(() => setSaved((s) => ({ ...s, [id]: false })), 2000)
  }

  return (
    <div className="lab-panel">
      <div className="lab-left">
        <div className="lab-header">
          <div className="lab-name">AN·<span>RA</span></div>
          <div className="lab-tag">LAB · IDEA ANALYSIS</div>
        </div>

        <div className="lab-modes">
          {MODES.map((m) => (
            <button
              key={m.id}
              className={`lab-mode-btn${activeMode === m.id ? ' lab-mode-btn--active' : ''}`}
              style={activeMode === m.id ? { color: m.color, borderColor: m.color } : {}}
              onClick={() => setMode(m.id)}
            >
              {m.label}
            </button>
          ))}
        </div>

        {currentMode && (
          <div className="lab-mode-desc">{currentMode.desc}</div>
        )}

        <button
          className="ctx-toggle"
          onClick={() => setShowCtx(v => !v)}
        >
          {showCtx ? '− Remove context' : '+ Add context'}
        </button>

        {showCtx && (
          <textarea
            className="lab-textarea lab-textarea--ctx"
            rows={3}
            value={context}
            onChange={(e) => setContext(e.target.value)}
            placeholder="Optional background context..."
          />
        )}

        <textarea
          className="lab-textarea"
          value={idea}
          onChange={(e) => setIdea(e.target.value)}
          onKeyDown={(e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
              e.preventDefault()
              handleRun()
            }
          }}
          placeholder="Describe your idea or question..."
          style={{ minHeight: '140px' }}
          disabled={busy}
        />

        <button
          className="analyze-btn"
          onClick={handleRun}
          disabled={busy || !idea.trim()}
        >
          {busy ? 'ANALYSING...' : 'ANALYZE'}
        </button>

        {error && <div className="lab-error">⚠ {error}</div>}
      </div>

      <div className="lab-right">
        {results.length === 0 && !busy && (
          <div className="lab-empty">
            <div className="lab-empty__icon">⬡</div>
            <div className="lab-empty__text">Run an analysis to see results</div>
          </div>
        )}

        {busy && (
          <div className="lab-thinking">
            <span className="lab-think-label">AN·RA is analysing</span>
            <span className="lab-dots"><span /><span /><span /></span>
          </div>
        )}

        {results.map((r) => (
          <div key={r.id} className="lab-card">
            <div className="lab-card__header">
              <span className="lab-idea">{r.idea}…</span>
              <span className="lab-badge">{r.mode.toUpperCase()}</span>
            </div>
            <div className="lab-card__body">
              <Markdown content={r.result} />
            </div>
            <div className="lab-card__footer">
              <button
                className={`lab-vault-btn${saved[r.id] ? ' lab-vault-btn--saved' : ''}`}
                onClick={() => handleSave(r.id)}
              >
                {saved[r.id] ? 'SAVED ✓' : '⊞ SAVE TO VAULT'}
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/LabPanel.css" << 'ENDOFFILE'
.lab-panel {
  display: grid;
  grid-template-columns: 360px 1fr;
  min-height: calc(100vh - 108px);
  overflow: hidden;
}

@media (max-width: 768px) {
  .lab-panel {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }
}

.lab-left {
  border-right: 1px solid var(--b1);
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 14px;
  position: sticky;
  top: 104px;
  height: calc(100vh - 108px);
  overflow-y: auto;
}

.lab-header { padding-bottom: 12px; border-bottom: 1px solid var(--b1); }

.lab-name {
  font-family: 'Cinzel', serif;
  font-size: 1.1rem;
  color: white;
  letter-spacing: 4px;
}

.lab-name span { color: var(--gold); }

.lab-tag {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  color: var(--dim);
  letter-spacing: 2px;
  margin-top: 4px;
}

.lab-modes {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.lab-mode-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1.5px;
  padding: 6px 14px;
  border-radius: 20px;
  border: 1px solid var(--b1);
  background: transparent;
  color: var(--dim);
  cursor: pointer;
  transition: all 0.2s;
}

.lab-mode-btn:hover { color: var(--tx); }
.lab-mode-btn--active { font-weight: 500; }

.lab-mode-desc {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.62em;
  color: var(--dim);
  letter-spacing: 0.5px;
  font-style: italic;
}

.ctx-toggle {
  background: transparent;
  border: none;
  color: var(--cyan);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.62em;
  cursor: pointer;
  text-align: left;
  padding: 0;
  letter-spacing: 0.5px;
}

.lab-textarea {
  width: 100%;
  resize: vertical;
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--b1);
  border-radius: 10px;
  color: var(--hi);
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.88em;
  padding: 12px 14px;
  outline: none;
  transition: border-color 0.2s;
  line-height: 1.6;
}

.lab-textarea:focus { border-color: rgba(0, 255, 159, 0.3); }
.lab-textarea::placeholder { color: var(--dim); }
.lab-textarea--ctx { min-height: 80px; }

.analyze-btn {
  width: 100%;
  background: linear-gradient(135deg, var(--green), var(--cyan));
  color: #000;
  border: none;
  border-radius: 8px;
  padding: 13px;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.65em;
  font-weight: 700;
  letter-spacing: 2px;
  cursor: pointer;
  transition: opacity 0.2s;
}

.analyze-btn:hover:not(:disabled) { opacity: 0.85; }
.analyze-btn:disabled { opacity: 0.4; cursor: not-allowed; }

.lab-error {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7em;
  color: var(--red);
  padding: 8px 12px;
  border: 1px solid rgba(255, 56, 96, 0.2);
  border-radius: 6px;
}

.lab-right {
  padding: 20px;
  overflow-y: auto;
  height: calc(100vh - 108px);
}

.lab-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 60%;
  gap: 16px;
}

.lab-empty__icon {
  font-size: 2.5rem;
  color: var(--dim);
  opacity: 0.3;
}

.lab-empty__text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--dim);
  letter-spacing: 1.5px;
}

.lab-thinking {
  display: flex;
  align-items: center;
  gap: 12px;
  border: 1px solid rgba(0, 255, 159, 0.3);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 16px;
  animation: labPulse 1.5s ease-in-out infinite;
}

@keyframes labPulse {
  0%, 100% { border-color: rgba(0, 255, 159, 0.3); }
  50%       { border-color: rgba(0, 255, 159, 0.9); }
}

.lab-think-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--green);
  letter-spacing: 1px;
}

.lab-dots { display: flex; gap: 4px; }
.lab-dots span {
  display: block;
  width: 5px; height: 5px;
  border-radius: 50%;
  background: var(--green);
  animation: dot-pulse 1.2s ease-in-out infinite;
}
.lab-dots span:nth-child(2) { animation-delay: 0.2s; }
.lab-dots span:nth-child(3) { animation-delay: 0.4s; }

.lab-card {
  border: 1px solid var(--b1);
  border-radius: 12px;
  overflow: hidden;
  background: var(--s1);
  margin-bottom: 16px;
  animation: fadeUp 0.25s ease;
}

.lab-card__header {
  background: rgba(255,255,255,.02);
  border-bottom: 1px solid var(--b1);
  padding: 12px 16px;
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
}

.lab-idea {
  font-size: 0.82em;
  color: var(--tx);
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.lab-badge {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  color: var(--green);
  border: 1px solid rgba(0, 255, 159, 0.3);
  border-radius: 4px;
  padding: 3px 8px;
  letter-spacing: 1px;
  flex-shrink: 0;
}

.lab-card__body { padding: 16px; }
.lab-card__footer { padding: 12px 16px; border-top: 1px solid var(--b1); }

.lab-vault-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1px;
  padding: 5px 12px;
  border-radius: 5px;
  border: 1px solid rgba(255, 201, 60, 0.25);
  background: transparent;
  color: var(--gold);
  cursor: pointer;
  transition: all 0.2s;
}

.lab-vault-btn:hover { background: rgba(255, 201, 60, 0.08); }
.lab-vault-btn--saved { color: var(--green); border-color: rgba(0, 255, 159, 0.3); }
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/CosmosPanel.jsx" << 'ENDOFFILE'
import React, { useState, useEffect, useRef } from 'react'
import useCosmosStore from '../store/cosmosStore'
import Markdown from '../components/Markdown'
import './CosmosPanel.css'

const SUGGESTIONS = {
  india:    ['How did Chandrayaan-3 land?', 'What is Gaganyaan?', 'Compare ISRO vs NASA budget'],
  mars:     ['How long to travel to Mars?', 'Can Mars be terraformed?', 'What has Perseverance found?'],
  sun:      ['What is a solar flare?', 'How does Aditya-L1 work?', 'How long until the Sun dies?'],
  raptor:   ['How does full-flow combustion work?', 'Compare Raptor vs Merlin', 'Why methane fuel?'],
  universe: ['What is dark matter?', 'What did JWST discover?', 'How big is the observable universe?'],
  ai:       ['What is a transformer?', 'How did AlphaFold work?', 'What is AN-RA building toward?'],
}

export default function CosmosPanel() {
  const sections       = useCosmosStore((s) => s.sections)
  const activeSection  = useCosmosStore((s) => s.activeSection)
  const sectionData    = useCosmosStore((s) => s.sectionData)
  const conversation   = useCosmosStore((s) => s.conversation)
  const busy           = useCosmosStore((s) => s.busy)
  const loadSections   = useCosmosStore((s) => s.loadSections)
  const loadSection    = useCosmosStore((s) => s.loadSection)
  const ask            = useCosmosStore((s) => s.ask)

  const [input, setInput] = useState('')
  const scrollRef = useRef(null)

  useEffect(() => {
    loadSections()
    loadSection('universe')
  }, [])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [conversation, busy])

  const handleAsk = () => {
    if (!input.trim() || busy) return
    ask(input.trim())
    setInput('')
  }

  const accent = sectionData?.accent || 'var(--cyan)'

  return (
    <div className="cosmos-panel">
      <div className="cosmos-pills-row">
        {sections.map((s) => (
          <button
            key={s.key}
            className={`cosmos-pill${activeSection === s.key ? ' cosmos-pill--active' : ''}`}
            style={activeSection === s.key ? {
              color: s.accent,
              borderColor: s.accent,
            } : {}}
            onClick={() => loadSection(s.key)}
          >
            {s.key.toUpperCase()}
          </button>
        ))}
      </div>

      <div className="cosmos-body">
        <div className="cosmos-info">
          {sectionData && (
            <>
              <div className="cosmos-title">{sectionData.title}</div>
              <div className="cosmos-accent-bar" style={{ background: accent }} />
              <div className="cosmos-summary">{sectionData.summary}</div>

              <div className="cosmos-facts">
                {sectionData.facts?.map((f, i) => (
                  <div
                    key={i}
                    className="cosmos-fact"
                    style={{ borderLeftColor: accent }}
                  >
                    {f}
                  </div>
                ))}
              </div>

              {sectionData.missions && (
                <div className="cosmos-missions">
                  {sectionData.missions.map((m) => (
                    <span key={m} className="cosmos-mission-pill">{m}</span>
                  ))}
                </div>
              )}

              {sectionData.next && (
                <div className="cosmos-next">
                  <span className="cosmos-next-label">NEXT →</span>
                  {sectionData.next}
                </div>
              )}
            </>
          )}
        </div>

        <div className="cosmos-convo">
          <div className="cosmos-messages" ref={scrollRef}>
            {conversation.length === 0 && (
              <div className="cosmos-suggestions">
                {(SUGGESTIONS[activeSection] || []).map((q) => (
                  <button
                    key={q}
                    className="cosmos-suggest-pill"
                    onClick={() => { setInput(q); ask(q) }}
                  >
                    {q}
                  </button>
                ))}
              </div>
            )}

            {conversation.map((msg, i) => (
              <div key={i} className={`cosmos-msg cosmos-msg--${msg.role}`}>
                {msg.role === 'user'
                  ? <span>{msg.content}</span>
                  : <Markdown content={msg.content} />
                }
              </div>
            ))}

            {busy && (
              <div className="cosmos-msg cosmos-msg--assistant">
                <span className="cosmos-thinking">AN·RA is exploring</span>
              </div>
            )}
          </div>

          <div className="cosmos-input-row">
            <textarea
              className="cosmos-textarea"
              rows={2}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  handleAsk()
                }
              }}
              placeholder={`Ask AN·RA about ${sectionData?.title || 'the cosmos'}...`}
              style={{ '--focus-accent': accent }}
              disabled={busy}
            />
            <button
              className="cosmos-ask-btn"
              style={{ background: accent }}
              onClick={handleAsk}
              disabled={busy || !input.trim()}
            >
              ASK
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/CosmosPanel.css" << 'ENDOFFILE'
.cosmos-panel {
  min-height: calc(100vh - 108px);
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* ── PILLS ── */
.cosmos-pills-row {
  display: flex;
  gap: 8px;
  padding: 16px 20px;
  overflow-x: auto;
  border-bottom: 1px solid var(--b1);
  flex-shrink: 0;
}

.cosmos-pills-row::-webkit-scrollbar { display: none; }

.cosmos-pill {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1.5px;
  padding: 6px 16px;
  border-radius: 20px;
  border: 1px solid var(--b1);
  background: transparent;
  color: var(--dim);
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
  flex-shrink: 0;
}

.cosmos-pill:hover { color: var(--tx); border-color: var(--tx); }
.cosmos-pill--active { font-weight: 500; }

/* ── BODY ── */
.cosmos-body {
  display: grid;
  grid-template-columns: 320px 1fr;
  flex: 1;
  overflow: hidden;
}

@media (max-width: 768px) {
  .cosmos-body {
    grid-template-columns: 1fr;
    overflow-y: auto;
  }
}

/* ── INFO ── */
.cosmos-info {
  padding: 20px;
  border-right: 1px solid var(--b1);
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 14px;
}

.cosmos-title {
  font-family: 'Cinzel', serif;
  font-size: 1.2em;
  color: var(--hi);
}

.cosmos-accent-bar {
  height: 3px;
  width: 40px;
  border-radius: 2px;
}

.cosmos-summary {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.88em;
  color: var(--tx);
  line-height: 1.8;
}

.cosmos-fact {
  padding: 10px 14px;
  background: var(--s1);
  border-left: 2px solid;
  border-radius: 0 6px 6px 0;
  font-size: 0.83em;
  color: var(--tx);
  line-height: 1.6;
}

.cosmos-missions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.cosmos-mission-pill {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1px;
  padding: 4px 10px;
  border-radius: 20px;
  border: 1px solid var(--b1);
  color: var(--dim);
}

.cosmos-next {
  border: 1px solid var(--b1);
  border-radius: 8px;
  padding: 12px 14px;
  font-size: 0.83em;
  color: var(--tx);
  line-height: 1.6;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.cosmos-next-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.7em;
  color: var(--dim);
  letter-spacing: 1.5px;
}

/* ── CONVO ── */
.cosmos-convo {
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.cosmos-messages {
  flex: 1;
  padding: 20px;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.cosmos-suggestions {
  display: flex;
  flex-direction: column;
  gap: 8px;
  padding: 20px 0;
}

.cosmos-suggest-pill {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  letter-spacing: 0.5px;
  padding: 10px 14px;
  border-radius: 20px;
  border: 1px solid var(--b1);
  background: transparent;
  color: var(--dim);
  cursor: pointer;
  text-align: left;
  transition: all 0.2s;
}

.cosmos-suggest-pill:hover {
  color: var(--tx);
  border-color: var(--tx);
  background: var(--s1);
}

.cosmos-msg {
  max-width: 100%;
  animation: fadeUp 0.2s ease;
}

.cosmos-msg--user {
  align-self: flex-end;
  background: rgba(0, 229, 255, 0.08);
  border: 1px solid rgba(0, 229, 255, 0.15);
  border-radius: 12px 12px 2px 12px;
  padding: 10px 14px;
  max-width: 80%;
  color: var(--hi);
  font-size: 0.9em;
}

.cosmos-msg--assistant {
  align-self: flex-start;
  width: 100%;
  background: var(--s1);
  border: 1px solid var(--b1);
  border-radius: 2px 12px 12px 12px;
  padding: 14px 16px;
}

.cosmos-thinking {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--cyan);
  letter-spacing: 1px;
}

.cosmos-input-row {
  display: flex;
  gap: 10px;
  align-items: flex-end;
  padding: 12px 20px;
  border-top: 1px solid var(--b1);
  background: rgba(2, 3, 8, 0.95);
  flex-shrink: 0;
}

.cosmos-textarea {
  flex: 1;
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--b1);
  border-radius: 10px;
  color: var(--hi);
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.88em;
  padding: 10px 14px;
  resize: none;
  outline: none;
  transition: border-color 0.2s;
  line-height: 1.6;
}

.cosmos-textarea::placeholder { color: var(--dim); }
.cosmos-textarea:focus { border-color: rgba(0, 229, 255, 0.3); }

.cosmos-ask-btn {
  color: #000;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.65em;
  font-weight: 700;
  letter-spacing: 2px;
  cursor: pointer;
  transition: opacity 0.2s;
  height: 40px;
  white-space: nowrap;
}

.cosmos-ask-btn:hover:not(:disabled) { opacity: 0.85; }
.cosmos-ask-btn:disabled { opacity: 0.4; cursor: not-allowed; }
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/VaultPanel.jsx" << 'ENDOFFILE'
import React, { useState, useEffect } from 'react'
import useVaultStore from '../store/vaultStore'
import Markdown from '../components/Markdown'
import './VaultPanel.css'

function formatDate(iso) {
  const d = new Date(iso)
  return d.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric'
  })
}

export default function VaultPanel() {
  const items       = useVaultStore((s) => s.items)
  const loading     = useVaultStore((s) => s.loading)
  const load        = useVaultStore((s) => s.load)
  const remove      = useVaultStore((s) => s.remove)

  const [searchQuery,   setSearchQuery]   = useState('')
  const [expandedItem,  setExpandedItem]  = useState(null)

  useEffect(() => { load() }, [])

  const filtered = items.filter(item =>
    item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    item.content.toLowerCase().includes(searchQuery.toLowerCase())
  )

  const handleDelete = async (id) => {
    await remove(id)
    if (expandedItem?.id === id) setExpandedItem(null)
  }

  return (
    <div className="vault-panel fade-in">
      <div className="vault-header">
        <div className="vault-title-row">
          <div>
            <div className="vault-title">AN·<span>RA</span></div>
            <div className="vault-subtitle">VAULT · SAVED IDEAS</div>
          </div>
          <div className="vault-count">{items.length}</div>
        </div>
        <input
          className="vault-search"
          type="text"
          placeholder="Search vault..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
        />
      </div>

      {loading && (
        <div className="vault-loading">Loading vault...</div>
      )}

      {!loading && items.length === 0 && (
        <div className="vault-empty">
          <div className="vault-empty__icon">⊞</div>
          <div className="vault-empty__text">Your vault is empty</div>
          <div className="vault-empty__sub">Save ideas from MIND and BUILD panels</div>
        </div>
      )}

      {!loading && items.length > 0 && (
        <div className="vault-grid">
          {filtered.map((item) => (
            <div key={item.id} className="vault-card">
              <div className="vault-card__header">
                <div className="vault-card__title">{item.title}</div>
                <div className="vault-card__date">{formatDate(item.created_at)}</div>
              </div>
              <div className="vault-card__body">
                {item.content.slice(0, 200)}
                {item.content.length > 200 && '…'}
              </div>
              <div className="vault-card__footer">
                <button
                  className="vault-expand-btn"
                  onClick={() => setExpandedItem(item)}
                >
                  EXPAND
                </button>
                <button
                  className="vault-delete-btn"
                  onClick={() => handleDelete(item.id)}
                >
                  DELETE
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {expandedItem && (
        <div className="vault-overlay" onClick={() => setExpandedItem(null)}>
          <div className="vault-overlay__content" onClick={(e) => e.stopPropagation()}>
            <button
              className="vault-overlay__close"
              onClick={() => setExpandedItem(null)}
            >
              ✕ CLOSE
            </button>
            <div className="vault-overlay__title">{expandedItem.title}</div>
            <div className="vault-overlay__date">{formatDate(expandedItem.created_at)}</div>
            <div className="vault-overlay__body">
              <Markdown content={expandedItem.content} />
            </div>
            <button
              className="vault-overlay__delete"
              onClick={() => handleDelete(expandedItem.id)}
            >
              DELETE ITEM
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/VaultPanel.css" << 'ENDOFFILE'
.vault-panel {
  min-height: calc(100vh - 108px);
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 20px;
}

/* ── HEADER ── */
.vault-header {
  display: flex;
  flex-direction: column;
  gap: 14px;
  padding-bottom: 16px;
  border-bottom: 1px solid var(--b1);
}

.vault-title-row {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.vault-title {
  font-family: 'Cinzel', serif;
  font-size: 1.2rem;
  color: white;
  letter-spacing: 4px;
}

.vault-title span { color: var(--gold); }

.vault-subtitle {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  color: var(--dim);
  letter-spacing: 2px;
  margin-top: 4px;
}

.vault-count {
  font-family: 'JetBrains Mono', monospace;
  font-size: 1.4rem;
  color: var(--gold);
  min-width: 36px;
  text-align: right;
}

.vault-search {
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--b1);
  border-radius: 8px;
  color: var(--hi);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.8em;
  padding: 8px 14px;
  outline: none;
  width: 100%;
  transition: border-color 0.2s;
}

.vault-search:focus { border-color: rgba(255, 201, 60, 0.3); }
.vault-search::placeholder { color: var(--dim); }

/* ── STATES ── */
.vault-loading {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--dim);
  letter-spacing: 1px;
  text-align: center;
  padding: 40px;
}

.vault-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 12px;
  padding: 80px 0;
}

.vault-empty__icon {
  font-size: 3rem;
  color: var(--dim);
  opacity: 0.3;
}

.vault-empty__text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.8em;
  color: var(--dim);
  letter-spacing: 1.5px;
}

.vault-empty__sub {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.62em;
  color: var(--dim);
  opacity: 0.6;
  letter-spacing: 0.5px;
}

/* ── GRID ── */
.vault-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 14px;
}

.vault-card {
  border: 1px solid var(--b1);
  border-radius: 12px;
  background: var(--s1);
  display: flex;
  flex-direction: column;
  transition: border-color 0.2s, transform 0.2s;
  overflow: hidden;
}

.vault-card:hover {
  border-color: rgba(255, 201, 60, 0.2);
  transform: translateY(-2px);
}

.vault-card__header {
  padding: 14px 16px 10px;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.vault-card__title {
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.9em;
  color: var(--hi);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  font-weight: 400;
}

.vault-card__date {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.52em;
  color: var(--dim);
  letter-spacing: 0.5px;
}

.vault-card__body {
  padding: 0 16px 14px;
  font-size: 0.82em;
  color: var(--dim);
  line-height: 1.6;
  flex: 1;
}

.vault-card__footer {
  padding: 10px 16px;
  border-top: 1px solid var(--b1);
  display: flex;
  gap: 8px;
}

.vault-expand-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  letter-spacing: 1px;
  padding: 5px 12px;
  border-radius: 5px;
  border: 1px solid rgba(0, 229, 255, 0.25);
  background: transparent;
  color: var(--cyan);
  cursor: pointer;
  transition: all 0.2s;
}

.vault-expand-btn:hover { background: rgba(0, 229, 255, 0.08); }

.vault-delete-btn {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  letter-spacing: 1px;
  padding: 5px 12px;
  border-radius: 5px;
  border: 1px solid rgba(255, 56, 96, 0.2);
  background: transparent;
  color: var(--red);
  cursor: pointer;
  transition: all 0.2s;
}

.vault-delete-btn:hover { background: rgba(255, 56, 96, 0.08); }

/* ── OVERLAY ── */
.vault-overlay {
  position: fixed;
  inset: 0;
  background: rgba(2, 3, 8, 0.97);
  z-index: 999;
  overflow-y: auto;
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from { opacity: 0; }
  to   { opacity: 1; }
}

.vault-overlay__content {
  padding: 80px 10vw;
  max-width: 900px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.vault-overlay__close {
  align-self: flex-end;
  background: transparent;
  border: 1px solid var(--b1);
  border-radius: 5px;
  color: var(--dim);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.62em;
  letter-spacing: 1px;
  padding: 6px 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.vault-overlay__close:hover { color: var(--tx); border-color: var(--tx); }

.vault-overlay__title {
  font-family: 'Cinzel', serif;
  font-size: 1.4em;
  color: var(--hi);
}

.vault-overlay__date {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  color: var(--dim);
  letter-spacing: 1px;
}

.vault-overlay__body {
  border: 1px solid var(--b1);
  border-radius: 10px;
  padding: 24px;
  background: var(--s1);
  line-height: 1.8;
  margin-top: 8px;
}

.vault-overlay__delete {
  align-self: flex-start;
  margin-top: 12px;
  background: transparent;
  border: 1px solid rgba(255, 56, 96, 0.3);
  border-radius: 5px;
  color: var(--red);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  letter-spacing: 1px;
  padding: 8px 16px;
  cursor: pointer;
  transition: all 0.2s;
}

.vault-overlay__delete:hover { background: rgba(255, 56, 96, 0.08); }
ENDOFFILE

cat > "anra-workspace/frontend/src/App.jsx" << 'ENDOFFILE'
import React, { useEffect, useState } from 'react'
import useAppStore from './store/appStore'
import BottomNav from './components/BottomNav'
import MindPanel from './panels/MindPanel'
import BuildPanel from './panels/BuildPanel'
import HomePanel from './panels/HomePanel'
import LabPanel from './panels/LabPanel'
import CosmosPanel from './panels/CosmosPanel'
import VaultPanel from './panels/VaultPanel'
import { newSession, healthCheck } from './api'

const renderPanel = (panel) => {
  switch (panel) {
    case 'home':   return <HomePanel />
    case 'mind':   return <MindPanel />
    case 'build':  return <BuildPanel />
    case 'lab':    return <LabPanel />
    case 'cosmos': return <CosmosPanel />
    case 'vault':  return <VaultPanel />
    default:       return <MindPanel />
  }
}

export default function App() {
  const activePanel  = useAppStore((s) => s.activePanel)
  const sessionId    = useAppStore((s) => s.sessionId)
  const setSessionId = useAppStore((s) => s.setSessionId)

  const [backendOk, setBackendOk] = useState(false)

  useEffect(() => {
    healthCheck()
      .then(() => setBackendOk(true))
      .catch(() => setBackendOk(false))
    if (!sessionId) {
      newSession()
        .then((data) => setSessionId(data.session_id))
        .catch(() => {})
    }
  }, [])

  return (
    <div className="app-shell">
      <header className="top-bar">
        <div className="top-bar__brand">
          AN·<span>RA</span>
        </div>
        <div className="top-bar__right">
          <div
            className="status-dot"
            style={{
              background: backendOk ? 'var(--green)' : 'var(--red)',
              boxShadow: backendOk
                ? '0 0 8px var(--green)'
                : '0 0 8px var(--red)',
            }}
          />
        </div>
      </header>

      <main className="app-main">
        {renderPanel(activePanel)}
      </main>

      <BottomNav />
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/App.css" << 'ENDOFFILE'
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;700&family=Cinzel:wght@400;700&family=Inter:wght@300;400;500;600&display=swap');

:root {
  --bg:     #020308;
  --tx:     #b8bcd0;
  --hi:     #e8eaf6;
  --dim:    #4a5070;
  --gold:   #ffc93c;
  --cyan:   #00e5ff;
  --plasma: #b040ff;
  --ember:  #ff5e1a;
  --green:  #00ff9f;
  --red:    #ff3860;
  --b1:     rgba(255,255,255,.07);
  --s1:     rgba(255,255,255,.03);
  --s2:     rgba(255,255,255,.055);
}

*, *::before, *::after {
  box-sizing: border-box;
  margin: 0;
  padding: 0;
}

body {
  background: var(--bg);
  color: var(--tx);
  font-family: 'Inter', system-ui, sans-serif;
  font-weight: 300;
  -webkit-font-smoothing: antialiased;
  overflow: hidden;
}

/* ── SHELL ── */
.app-shell {
  display: flex;
  flex-direction: column;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
}

/* ── TOP BAR ── */
.top-bar {
  position: fixed;
  top: 0; left: 0; right: 0;
  height: 52px;
  z-index: 900;
  background: rgba(2, 3, 8, 0.97);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--b1);
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 20px;
}

.top-bar__brand {
  font-family: 'Cinzel', serif;
  font-size: 1.15rem;
  color: white;
  letter-spacing: 5px;
}

.top-bar__brand span { color: var(--gold); }

.top-bar__right {
  display: flex;
  align-items: center;
  gap: 10px;
}

.status-dot {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  transition: background 0.3s, box-shadow 0.3s;
}

/* ── MAIN ── */
.app-main {
  flex: 1;
  overflow: hidden;
  padding-top: 52px;
  padding-bottom: 56px;
}

/* ── PANEL COMMONS ── */
.home-panel,
.lab-panel,
.cosmos-panel,
.vault-panel,
.build-panel {
  min-height: calc(100vh - 108px);
  overflow-y: auto;
}

.panel-header {
  padding: 32px 24px 20px;
  border-bottom: 1px solid var(--b1);
}

.panel-title {
  font-family: 'Cinzel', serif;
  font-size: 1.4em;
  color: white;
}

.panel-label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.55em;
  letter-spacing: 3px;
  color: var(--dim);
  text-transform: uppercase;
  margin-top: 4px;
}

/* ── ANIMATIONS ── */
@keyframes fadeIn {
  from { opacity: 0; transform: translateY(8px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

@keyframes dot-pulse {
  0%, 100% { opacity: 0.2; transform: scale(0.8); }
  50%       { opacity: 1;   transform: scale(1.2); }
}

.fade-in { animation: fadeIn 0.3s ease forwards; }

/* ── SCROLLBARS ── */
* {
  scrollbar-width: thin;
  scrollbar-color: var(--b1) transparent;
}

*::-webkit-scrollbar { width: 4px; }
*::-webkit-scrollbar-track { background: transparent; }
*::-webkit-scrollbar-thumb { background: var(--b1); border-radius: 2px; }
ENDOFFILE

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║        PHASE 5 + 6 COMPLETE ✓                ║"
echo "║        AN-RA WORKSPACE IS COMPLETE           ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Phase 5 — Build Panel:                      ║"
echo "║  backend/routes/build.py                     ║"
echo "║  frontend/src/store/buildStore.js            ║"
echo "║  frontend/src/components/CodeBlock.jsx       ║"
echo "║  frontend/src/components/CodeBlock.css       ║"
echo "║  frontend/src/panels/BuildPanel.jsx          ║"
echo "║  frontend/src/panels/BuildPanel.css          ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Phase 6 — All Remaining Panels:             ║"
echo "║  backend/data/cosmos.json                    ║"
echo "║  backend/data/phases.json                    ║"
echo "║  backend/routes/lab.py                       ║"
echo "║  backend/routes/cosmos.py                    ║"
echo "║  backend/routes/insights.py                  ║"
echo "║  backend/app.py (FINAL)                      ║"
echo "║  frontend/src/store/labStore.js              ║"
echo "║  frontend/src/store/cosmosStore.js           ║"
echo "║  frontend/src/panels/HomePanel.jsx+css       ║"
echo "║  frontend/src/panels/LabPanel.jsx+css        ║"
echo "║  frontend/src/panels/CosmosPanel.jsx+css     ║"
echo "║  frontend/src/panels/VaultPanel.jsx+css      ║"
echo "║  frontend/src/api.js (FINAL)                 ║"
echo "║  frontend/src/App.jsx (FINAL)                ║"
echo "║  frontend/src/App.css (FINAL)                ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  ALL ROUTES LIVE:                            ║"
echo "║  GET  /health                                ║"
echo "║  GET  POST DEL /chat/*                       ║"
echo "║  GET  POST DEL /vault/*                      ║"
echo "║  GET  POST     /build/*                      ║"
echo "║  GET  POST     /lab/*                        ║"
echo "║  GET  POST     /cosmos/*                     ║"
echo "║  GET           /insights/*                   ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  ALL PANELS LIVE:                            ║"
echo "║  HOME MIND BUILD LAB COSMOS VAULT            ║"
echo "║  Zero placeholders remaining                 ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  FINAL STEPS:                                ║"
echo "║  1. cd anra-workspace/backend                ║"
echo "║  2. Create .env from .env.example            ║"
echo "║  3. Add your real OR_KEY to .env             ║"
echo "║  4. pip install -r requirements.txt          ║"
echo "║  5. uvicorn app:app --reload --port 8000     ║"
echo "║  6. cd ../frontend                           ║"
echo "║  7. npm install                              ║"
echo "║  8. npm run dev                              ║"
echo "║  9. Open http://localhost:5173               ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Push to GitHub:                             ║"
echo "║  git init                                    ║"
echo "║  git add .                                   ║"
echo "║  git commit -m AN-RA complete                ║"
echo "║  git remote add origin YOUR_REPO_URL         ║"
echo "║  git push -u origin main                     ║"
echo "╚══════════════════════════════════════════════╝"
