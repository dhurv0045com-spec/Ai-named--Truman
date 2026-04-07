#!/bin/bash
set -e

if [ ! -d "anra-workspace" ]; then
  echo "ERROR: Run from folder containing anra-workspace/"
  exit 1
fi

mkdir -p anra-workspace/frontend/src/store
mkdir -p anra-workspace/frontend/src/components
mkdir -p anra-workspace/frontend/src/panels

cat > "anra-workspace/backend/db/database.py" << 'ENDOFFILE'
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from config import DATABASE_URL

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    from db.models import ChatMessage, VaultItem
    Base.metadata.create_all(bind=engine)
    print("AN-RA Database ready — anra.db created")
ENDOFFILE

cat > "anra-workspace/backend/db/models.py" << 'ENDOFFILE'
from sqlalchemy import Column, Integer, String, Text, DateTime
from datetime import datetime
from db.database import Base


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id         = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(String, index=True, nullable=False)
    role       = Column(String, nullable=False)
    content    = Column(Text, nullable=False)
    timestamp  = Column(DateTime, default=datetime.utcnow)


class VaultItem(Base):
    __tablename__ = "vault_items"
    id         = Column(Integer, primary_key=True, autoincrement=True)
    title      = Column(String, nullable=False)
    content    = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)
ENDOFFILE

cat > "anra-workspace/backend/db/crud.py" << 'ENDOFFILE'
from sqlalchemy.orm import Session
from db.models import ChatMessage, VaultItem
from datetime import datetime


# ── CHAT ──────────────────────────────────────────────────────────────────────

def save_message(db: Session, session_id: str,
                 role: str, content: str) -> ChatMessage:
    msg = ChatMessage(session_id=session_id, role=role, content=content)
    db.add(msg)
    db.commit()
    db.refresh(msg)
    return msg


def get_history(db: Session, session_id: str,
                limit: int = 40) -> list:
    rows = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.timestamp.asc())
        .limit(limit)
        .all()
    )
    return [{"role": r.role, "content": r.content} for r in rows]


def delete_session(db: Session, session_id: str) -> int:
    count = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .delete()
    )
    db.commit()
    return count


def list_sessions(db: Session) -> list:
    rows = db.query(ChatMessage.session_id).distinct().all()
    return [r.session_id for r in rows]


# ── VAULT ─────────────────────────────────────────────────────────────────────

def get_vault(db: Session) -> list:
    return (
        db.query(VaultItem)
        .order_by(VaultItem.created_at.desc())
        .all()
    )


def save_vault_item(db: Session, title: str, content: str) -> VaultItem:
    item = VaultItem(title=title, content=content)
    db.add(item)
    db.commit()
    db.refresh(item)
    return item


def delete_vault_item(db: Session, item_id: int) -> bool:
    item = (
        db.query(VaultItem)
        .filter(VaultItem.id == item_id)
        .first()
    )
    if not item:
        return False
    db.delete(item)
    db.commit()
    return True
ENDOFFILE

cat > "anra-workspace/backend/routes/vault.py" << 'ENDOFFILE'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime
from db.database import get_db
from db.crud import get_vault, save_vault_item, delete_vault_item

router = APIRouter()


class VaultCreate(BaseModel):
    title: str
    content: str


class VaultResponse(BaseModel):
    id: int
    title: str
    content: str
    created_at: datetime

    class Config:
        from_attributes = True


@router.get("", response_model=list[VaultResponse])
def list_vault(db: Session = Depends(get_db)):
    return get_vault(db)


@router.post("", response_model=VaultResponse)
def create_vault_item(item: VaultCreate,
                      db: Session = Depends(get_db)):
    return save_vault_item(db, item.title, item.content)


@router.delete("/{item_id}")
def remove_vault_item(item_id: int,
                      db: Session = Depends(get_db)):
    success = delete_vault_item(db, item_id)
    if not success:
        raise HTTPException(status_code=404, detail="Item not found")
    return {"deleted": item_id}


@router.get("/count")
def vault_count(db: Session = Depends(get_db)):
    return {"count": len(get_vault(db))}
ENDOFFILE

cat > "anra-workspace/backend/routes/chat.py" << 'ENDOFFILE'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from services.ai_client import call_ai_with_fallback
from services.prompt_builder import build_system_prompt
from db.database import get_db
from db.crud import get_history, save_message, delete_session
from config import DEFAULT_MODEL
import uuid

router = APIRouter()


class ChatRequest(BaseModel):
    message: str
    session_id: str = "default"
    model: str = DEFAULT_MODEL
    vault_context: str = ""


class ChatResponse(BaseModel):
    reply: str
    session_id: str
    model_used: str


@router.get("/ping")
def chat_ping():
    return {"status": "chat online", "default_model": DEFAULT_MODEL}


@router.get("/new")
def new_session():
    return {"session_id": str(uuid.uuid4())}


@router.get("/history/{session_id}")
def chat_history(session_id: str,
                 db: Session = Depends(get_db)):
    return {
        "session_id": session_id,
        "messages": get_history(db, session_id)
    }


@router.delete("/{session_id}")
def clear_session(session_id: str,
                  db: Session = Depends(get_db)):
    removed = delete_session(db, session_id)
    return {"deleted": session_id, "messages_removed": removed}


@router.post("/send", response_model=ChatResponse)
async def chat_send(req: ChatRequest,
                    db: Session = Depends(get_db)):
    try:
        history = get_history(db, req.session_id)
        messages = history + [{"role": "user", "content": req.message}]

        system = build_system_prompt(vault_context=req.vault_context)

        result = await call_ai_with_fallback(
            messages=messages,
            system=system,
            primary_model=req.model
        )

        save_message(db, req.session_id, "user", req.message)
        save_message(db, req.session_id, "assistant", result["reply"])

        return ChatResponse(
            reply=result["reply"],
            session_id=req.session_id,
            model_used=result["model_used"]
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500,
                            detail=f"Chat failed: {str(e)}")
ENDOFFILE

cat > "anra-workspace/backend/app.py" << 'ENDOFFILE'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from db.database import init_db
from routes.health import router as health_router
from routes.chat import router as chat_router
from routes.vault import router as vault_router

app = FastAPI(title="AN-RA Workspace API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(chat_router, prefix="/chat")
app.include_router(vault_router, prefix="/vault")


@app.on_event("startup")
def startup():
    init_db()
    print("")
    print("AN-RA Backend — Phase 3")
    print("http://localhost:8000")
    print("http://localhost:8000/docs")
    print("")
ENDOFFILE

cd anra-workspace/frontend && npm install zustand && cd ../..

cat > "anra-workspace/frontend/src/store/appStore.js" << 'ENDOFFILE'
import { create } from 'zustand'

const useAppStore = create((set) => ({
  activePanel: 'mind',
  model: 'anthropic/claude-3.5-haiku',
  status: 'idle',
  sessionId: localStorage.getItem('anra_session_id') || null,

  setActivePanel: (panel) => set({ activePanel: panel }),
  setModel: (model) => set({ model }),
  setStatus: (status) => set({ status }),
  setSessionId: (id) => {
    localStorage.setItem('anra_session_id', id)
    set({ sessionId: id })
  },
}))

export default useAppStore
ENDOFFILE

cat > "anra-workspace/frontend/src/store/chatStore.js" << 'ENDOFFILE'
import { create } from 'zustand'
import { sendMessage, getHistory } from '../api'

const useChatStore = create((set, get) => ({
  messages: [],
  busy: false,
  error: null,

  setMessages: (messages) => set({ messages }),
  addMessage: (role, content) =>
    set((s) => ({ messages: [...s.messages, { role, content }] })),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearChat: () => set({ messages: [] }),

  send: async (message, sessionId, model) => {
    set({ busy: true, error: null })
    get().addMessage('user', message)
    try {
      const data = await sendMessage(message, sessionId, model)
      get().addMessage('assistant', data.reply)
    } catch (e) {
      set({ error: e.message })
    } finally {
      set({ busy: false })
    }
  },

  loadHistory: async (sessionId) => {
    try {
      const data = await getHistory(sessionId)
      set({ messages: data.messages || [] })
    } catch (e) {
      console.error('History load failed', e)
    }
  },
}))

export default useChatStore
ENDOFFILE

cat > "anra-workspace/frontend/src/store/vaultStore.js" << 'ENDOFFILE'
import { create } from 'zustand'
import { getVault, saveToVault, deleteVaultItem } from '../api'

const useVaultStore = create((set, get) => ({
  items: [],
  loading: false,

  setItems: (items) => set({ items }),
  setLoading: (loading) => set({ loading }),

  load: async () => {
    set({ loading: true })
    try {
      const data = await getVault()
      set({ items: data })
    } finally {
      set({ loading: false })
    }
  },

  save: async (title, content) => {
    await saveToVault(title, content)
    get().load()
  },

  remove: async (id) => {
    await deleteVaultItem(id)
    set((s) => ({ items: s.items.filter((i) => i.id !== id) }))
  },
}))

export default useVaultStore
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
  if (!res.ok) throw new Error(`Request failed: ${res.status}`)
  return res.json()
}

const get = async (url) => {
  const res = await fetch(`${BASE}${url}`)
  if (!res.ok) throw new Error(`Request failed: ${res.status}`)
  return res.json()
}

const del = async (url) => {
  const res = await fetch(`${BASE}${url}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`Request failed: ${res.status}`)
  return res.json()
}

// HEALTH
export const healthCheck = () => get('/health')

// CHAT
export const newSession = () => get('/chat/new')
export const sendMessage = (message, session_id, model) =>
  post('/chat/send', { message, session_id, model, vault_context: '' })
export const getHistory = (session_id) =>
  get(`/chat/history/${session_id}`)
export const deleteSession = (session_id) =>
  del(`/chat/${session_id}`)

// VAULT
export const getVault = () => get('/vault')
export const saveToVault = (title, content) =>
  post('/vault', { title, content })
export const deleteVaultItem = (id) => del(`/vault/${id}`)
export const getVaultCount = () => get('/vault/count')
ENDOFFILE

cat > "anra-workspace/frontend/src/components/Markdown.jsx" << 'ENDOFFILE'
import React from 'react'

const inlineStyles = {
  p: {
    color: 'var(--tx)',
    lineHeight: '1.8',
    margin: '4px 0',
  },
  strong: {
    color: 'var(--hi)',
    fontWeight: 500,
  },
  code: {
    background: 'rgba(255,255,255,.08)',
    padding: '2px 7px',
    borderRadius: '4px',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: '0.88em',
    color: '#aaa',
  },
  h3: {
    color: 'var(--hi)',
    fontFamily: "'Cinzel', serif",
    fontSize: '1em',
    margin: '10px 0 4px',
  },
  li: {
    color: 'var(--tx)',
    paddingLeft: '16px',
    lineHeight: '1.7',
    listStyle: 'disc',
  },
  pre: {
    background: 'rgba(0,0,0,.6)',
    border: '1px solid var(--b1)',
    borderRadius: '8px',
    padding: '12px 16px',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: '0.82em',
    color: '#7dd3fc',
    overflowX: 'auto',
    whiteSpace: 'pre',
    margin: '8px 0',
  },
}

function parseInline(text) {
  const parts = []
  const re = /(\*\*(.+?)\*\*|`([^`]+)`)/g
  let last = 0
  let m
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) {
      parts.push(<span key={last}>{text.slice(last, m.index)}</span>)
    }
    if (m[0].startsWith('**')) {
      parts.push(<strong key={m.index} style={inlineStyles.strong}>{m[2]}</strong>)
    } else {
      parts.push(<code key={m.index} style={inlineStyles.code}>{m[3]}</code>)
    }
    last = m.index + m[0].length
  }
  if (last < text.length) parts.push(<span key={last}>{text.slice(last)}</span>)
  return parts
}

function renderText(segment, segIdx) {
  const lines = segment.split('\n')
  const elements = []
  let listItems = []

  const flushList = (i) => {
    if (listItems.length) {
      elements.push(
        <ul key={`ul-${segIdx}-${i}`} style={{ margin: '4px 0', paddingLeft: 0 }}>
          {listItems}
        </ul>
      )
      listItems = []
    }
  }

  lines.forEach((line, i) => {
    if (line.startsWith('# ') || line.startsWith('## ') || line.startsWith('### ')) {
      flushList(i)
      const text = line.replace(/^#{1,3}\s/, '')
      elements.push(<h3 key={`h-${segIdx}-${i}`} style={inlineStyles.h3}>{text}</h3>)
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      const text = line.slice(2)
      listItems.push(
        <li key={`li-${segIdx}-${i}`} style={inlineStyles.li}>
          {parseInline(text)}
        </li>
      )
    } else if (line.trim() === '') {
      flushList(i)
      elements.push(<br key={`br-${segIdx}-${i}`} />)
    } else {
      flushList(i)
      elements.push(
        <p key={`p-${segIdx}-${i}`} style={inlineStyles.p}>
          {parseInline(line)}
        </p>
      )
    }
  })
  flushList('end')
  return elements
}

export default function Markdown({ content }) {
  if (!content) return null

  const parts = content.split(/(```[\s\S]*?```)/g)

  return (
    <div style={{ wordBreak: 'break-word' }}>
      {parts.map((part, idx) => {
        if (part.startsWith('```') && part.endsWith('```')) {
          const inner = part.slice(3, -3).replace(/^\w+\n/, '')
          return <pre key={idx} style={inlineStyles.pre}>{inner}</pre>
        }
        return <span key={idx}>{renderText(part, idx)}</span>
      })}
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/components/BottomNav.jsx" << 'ENDOFFILE'
import React from 'react'
import useAppStore from '../store/appStore'
import './BottomNav.css'

const TABS = [
  { id: 'home',   label: 'HOME',   icon: '⌂',    color: 'var(--gold)' },
  { id: 'mind',   label: 'MIND',   icon: '◈',    color: 'var(--cyan)' },
  { id: 'build',  label: 'BUILD',  icon: '⟨/⟩',  color: 'var(--plasma)' },
  { id: 'lab',    label: 'LAB',    icon: '⬡',    color: 'var(--green)' },
  { id: 'cosmos', label: 'COSMOS', icon: '✦',    color: 'var(--ember)' },
  { id: 'vault',  label: 'VAULT',  icon: '⊞',    color: 'var(--gold)' },
]

export default function BottomNav() {
  const activePanel = useAppStore((s) => s.activePanel)
  const setActivePanel = useAppStore((s) => s.setActivePanel)

  return (
    <nav className="bottom-nav">
      {TABS.map((tab) => {
        const isActive = activePanel === tab.id
        return (
          <button
            key={tab.id}
            className={`nav-tab${isActive ? ' nav-tab--active' : ''}`}
            style={isActive ? {
              color: tab.color,
              borderTopColor: tab.color,
            } : {}}
            onClick={() => setActivePanel(tab.id)}
            aria-label={tab.label}
          >
            <span className="nav-tab__icon">{tab.icon}</span>
            <span className="nav-tab__label">{tab.label}</span>
          </button>
        )
      })}
    </nav>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/components/BottomNav.css" << 'ENDOFFILE'
.bottom-nav {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  height: 56px;
  background: rgba(2, 3, 8, 0.97);
  backdrop-filter: blur(20px);
  -webkit-backdrop-filter: blur(20px);
  border-top: 1px solid var(--b1);
  display: flex;
  z-index: 900;
  padding: 0;
  margin: 0;
}

.nav-tab {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 3px;
  cursor: pointer;
  border: none;
  border-top: 2px solid transparent;
  background: transparent;
  color: var(--dim);
  transition: color 0.2s, border-top-color 0.2s, background 0.2s;
  min-height: 44px;
  padding: 0;
  -webkit-tap-highlight-color: transparent;
}

.nav-tab:hover {
  color: var(--tx);
  background: var(--s1);
}

.nav-tab--active {
  border-top-width: 2px;
  border-top-style: solid;
}

.nav-tab__icon {
  font-size: 1.1em;
  line-height: 1;
}

.nav-tab__label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.42em;
  letter-spacing: 1.5px;
  text-transform: uppercase;
  line-height: 1;
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/MindPanel.jsx" << 'ENDOFFILE'
import React, { useEffect, useRef, useState } from 'react'
import useChatStore from '../store/chatStore'
import useAppStore from '../store/appStore'
import useVaultStore from '../store/vaultStore'
import Markdown from '../components/Markdown'
import { newSession } from '../api'
import './MindPanel.css'

const MODELS = [
  { value: 'anthropic/claude-3.5-haiku', label: 'Claude 3.5 Haiku' },
  { value: 'anthropic/claude-3-opus',    label: 'Claude 3 Opus' },
  { value: 'openai/gpt-4o',              label: 'GPT-4o' },
  { value: 'openai/gpt-4o-mini',         label: 'GPT-4o Mini' },
  { value: 'google/gemini-flash-1.5',    label: 'Gemini Flash 1.5' },
]

export default function MindPanel() {
  const messages   = useChatStore((s) => s.messages)
  const busy       = useChatStore((s) => s.busy)
  const error      = useChatStore((s) => s.error)
  const send       = useChatStore((s) => s.send)
  const loadHistory = useChatStore((s) => s.loadHistory)

  const sessionId     = useAppStore((s) => s.sessionId)
  const setSessionId  = useAppStore((s) => s.setSessionId)
  const model         = useAppStore((s) => s.model)
  const setModel      = useAppStore((s) => s.setModel)

  const saveVault = useVaultStore((s) => s.save)

  const [input, setInput]       = useState('')
  const [saved, setSaved]       = useState({})
  const scrollRef               = useRef(null)

  useEffect(() => {
    const init = async () => {
      let sid = sessionId
      if (!sid) {
        const data = await newSession()
        sid = data.session_id
        setSessionId(sid)
      }
      await loadHistory(sid)
    }
    init()
  }, [])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [messages, busy])

  const handleSend = () => {
    const text = input.trim()
    if (!text || busy || !sessionId) return
    setInput('')
    send(text, sessionId, model)
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  const handleSaveToVault = async (content, idx) => {
    const title = content.slice(0, 60).replace(/\n/g, ' ') + '…'
    await saveVault(title, content)
    setSaved((s) => ({ ...s, [idx]: true }))
    setTimeout(() => setSaved((s) => ({ ...s, [idx]: false })), 2000)
  }

  return (
    <div className="mind-panel">
      <div className="mind-header">
        <div className="mind-title">
          <span className="mind-name">AN·<span>RA</span></span>
          <span className="mind-tag">MIND</span>
        </div>
        <select
          className="model-select"
          value={model}
          onChange={(e) => setModel(e.target.value)}
        >
          {MODELS.map((m) => (
            <option key={m.value} value={m.value}>{m.label}</option>
          ))}
        </select>
      </div>

      <div className="mind-messages" ref={scrollRef}>
        {messages.length === 0 && (
          <div className="mind-empty">
            <div className="mind-empty__glyph">◈</div>
            <div className="mind-empty__text">AN·RA is ready. Ask anything.</div>
          </div>
        )}

        {messages.map((msg, idx) => (
          <div
            key={idx}
            className={`message message--${msg.role}`}
          >
            {msg.role === 'user' ? (
              <span>{msg.content}</span>
            ) : (
              <div className="message__assistant-inner">
                <Markdown content={msg.content} />
                <button
                  className={`vault-btn${saved[idx] ? ' vault-btn--saved' : ''}`}
                  onClick={() => handleSaveToVault(msg.content, idx)}
                >
                  {saved[idx] ? 'SAVED ✓' : '⊞ VAULT'}
                </button>
              </div>
            )}
          </div>
        ))}

        {busy && (
          <div className="message message--assistant">
            <div className="thinking">
              <span className="thinking__label">AN·RA is thinking</span>
              <span className="thinking__dots">
                <span /><span /><span />
              </span>
            </div>
          </div>
        )}

        {error && (
          <div className="mind-error">⚠ {error}</div>
        )}
      </div>

      <div className="mind-input-area">
        <textarea
          className="mind-textarea"
          rows={3}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask AN·RA anything..."
          disabled={busy}
        />
        <button
          className="send-btn"
          onClick={handleSend}
          disabled={busy || !input.trim()}
        >
          SEND
        </button>
      </div>
    </div>
  )
}
ENDOFFILE

cat > "anra-workspace/frontend/src/panels/MindPanel.css" << 'ENDOFFILE'
.mind-panel {
  display: flex;
  flex-direction: column;
  height: 100vh;
  padding-top: 52px;
  padding-bottom: 56px;
  background: var(--bg);
  position: relative;
}

/* ── HEADER ── */
.mind-header {
  position: fixed;
  top: 52px;
  left: 0;
  right: 0;
  z-index: 800;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 20px;
  background: rgba(2, 3, 8, 0.95);
  backdrop-filter: blur(20px);
  border-bottom: 1px solid var(--b1);
  height: 52px;
}

.mind-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.mind-name {
  font-family: 'Cinzel', serif;
  font-size: 1.1rem;
  color: white;
  letter-spacing: 4px;
}

.mind-name span {
  color: var(--gold);
}

.mind-tag {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  color: var(--cyan);
  letter-spacing: 3px;
  border: 1px solid rgba(0, 229, 255, 0.3);
  border-radius: 4px;
  padding: 2px 8px;
}

.model-select {
  background: rgba(0, 0, 0, 0.5);
  border: 1px solid var(--b1);
  border-radius: 6px;
  color: var(--gold);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.65em;
  letter-spacing: 0.5px;
  padding: 6px 10px;
  cursor: pointer;
  outline: none;
  max-width: 180px;
}

.model-select:focus {
  border-color: rgba(255, 201, 60, 0.4);
}

/* ── MESSAGES ── */
.mind-messages {
  flex: 1;
  overflow-y: auto;
  padding: 114px 16px 16px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  scroll-behavior: smooth;
}

.mind-messages::-webkit-scrollbar {
  width: 4px;
}

.mind-messages::-webkit-scrollbar-track {
  background: transparent;
}

.mind-messages::-webkit-scrollbar-thumb {
  background: var(--b1);
  border-radius: 2px;
}

.mind-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  gap: 16px;
  flex: 1;
  padding: 60px 0;
}

.mind-empty__glyph {
  font-size: 2.5rem;
  color: var(--dim);
  opacity: 0.4;
}

.mind-empty__text {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--dim);
  letter-spacing: 1.5px;
}

.message {
  max-width: 100%;
  animation: fadeUp 0.2s ease;
}

@keyframes fadeUp {
  from { opacity: 0; transform: translateY(6px); }
  to   { opacity: 1; transform: translateY(0); }
}

.message--user {
  align-self: flex-end;
  background: rgba(0, 229, 255, 0.08);
  border: 1px solid rgba(0, 229, 255, 0.15);
  border-radius: 12px 12px 2px 12px;
  padding: 10px 14px;
  max-width: 80%;
  color: var(--hi);
  font-size: 0.9em;
  line-height: 1.6;
}

.message--assistant {
  align-self: flex-start;
  width: 100%;
  background: var(--s1);
  border: 1px solid var(--b1);
  border-radius: 2px 12px 12px 12px;
  padding: 14px 16px;
  position: relative;
}

.message__assistant-inner {
  position: relative;
}

.vault-btn {
  margin-top: 10px;
  background: transparent;
  border: 1px solid var(--b1);
  border-radius: 5px;
  color: var(--dim);
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.58em;
  letter-spacing: 1px;
  padding: 4px 10px;
  cursor: pointer;
  transition: all 0.2s;
  display: block;
}

.vault-btn:hover {
  color: var(--gold);
  border-color: rgba(255, 201, 60, 0.3);
}

.vault-btn--saved {
  color: var(--green);
  border-color: rgba(0, 255, 159, 0.3);
}

/* ── THINKING ── */
.thinking {
  display: flex;
  align-items: center;
  gap: 10px;
}

.thinking__label {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--cyan);
  letter-spacing: 1px;
}

.thinking__dots {
  display: flex;
  gap: 4px;
}

.thinking__dots span {
  display: block;
  width: 5px;
  height: 5px;
  border-radius: 50%;
  background: var(--cyan);
  animation: dot-pulse 1.2s ease-in-out infinite;
}

.thinking__dots span:nth-child(2) { animation-delay: 0.2s; }
.thinking__dots span:nth-child(3) { animation-delay: 0.4s; }

@keyframes dot-pulse {
  0%, 100% { opacity: 0.2; transform: scale(0.8); }
  50%       { opacity: 1;   transform: scale(1.2); }
}

/* ── ERROR ── */
.mind-error {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.72em;
  color: var(--red);
  letter-spacing: 1px;
  padding: 8px 12px;
  border: 1px solid rgba(255, 56, 96, 0.2);
  border-radius: 6px;
  background: rgba(255, 56, 96, 0.05);
}

/* ── INPUT ── */
.mind-input-area {
  position: fixed;
  bottom: 56px;
  left: 0;
  right: 0;
  z-index: 800;
  display: flex;
  gap: 10px;
  align-items: flex-end;
  padding: 10px 16px;
  background: rgba(2, 3, 8, 0.97);
  backdrop-filter: blur(20px);
  border-top: 1px solid var(--b1);
}

.mind-textarea {
  flex: 1;
  background: rgba(0, 0, 0, 0.4);
  border: 1px solid var(--b1);
  border-radius: 10px;
  color: var(--hi);
  font-family: 'Inter', system-ui, sans-serif;
  font-size: 0.9em;
  font-weight: 300;
  padding: 12px 14px;
  resize: none;
  outline: none;
  transition: border-color 0.2s;
  line-height: 1.6;
}

.mind-textarea::placeholder {
  color: var(--dim);
}

.mind-textarea:focus {
  border-color: rgba(0, 229, 255, 0.3);
}

.send-btn {
  background: linear-gradient(135deg, var(--cyan), var(--plasma));
  color: #000;
  border: none;
  border-radius: 8px;
  padding: 10px 20px;
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.65em;
  font-weight: 700;
  letter-spacing: 2px;
  cursor: pointer;
  transition: opacity 0.2s, transform 0.1s;
  white-space: nowrap;
  height: 42px;
}

.send-btn:hover:not(:disabled) {
  opacity: 0.85;
  transform: translateY(-1px);
}

.send-btn:active:not(:disabled) {
  transform: translateY(0);
}

.send-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}
ENDOFFILE

cat > "anra-workspace/frontend/src/App.jsx" << 'ENDOFFILE'
import React, { useEffect } from 'react'
import useAppStore from './store/appStore'
import BottomNav from './components/BottomNav'
import MindPanel from './panels/MindPanel'
import { newSession, healthCheck } from './api'

const Placeholder = ({ name }) => (
  <div style={{
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    height: '70vh',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: '0.75em',
    letterSpacing: '2px',
    color: 'var(--dim)',
  }}>
    [ {name} ] — Coming in next phase
  </div>
)

const renderPanel = (panel) => {
  switch (panel) {
    case 'mind':   return <MindPanel />
    case 'home':   return <Placeholder name="HOME" />
    case 'build':  return <Placeholder name="BUILD" />
    case 'lab':    return <Placeholder name="LAB" />
    case 'cosmos': return <Placeholder name="COSMOS" />
    case 'vault':  return <Placeholder name="VAULT" />
    default:       return <MindPanel />
  }
}

export default function App() {
  const activePanel  = useAppStore((s) => s.activePanel)
  const sessionId    = useAppStore((s) => s.sessionId)
  const setSessionId = useAppStore((s) => s.setSessionId)

  useEffect(() => {
    healthCheck().catch(() => {})
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
        <div className="top-bar__panel">
          {activePanel.toUpperCase()}
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
  top: 0;
  left: 0;
  right: 0;
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

.top-bar__brand span {
  color: var(--gold);
}

.top-bar__panel {
  font-family: 'JetBrains Mono', monospace;
  font-size: 0.6em;
  color: var(--dim);
  letter-spacing: 3px;
}

/* ── MAIN ── */
.app-main {
  flex: 1;
  overflow: hidden;
}

/* ── SCROLLBARS ── */
* {
  scrollbar-width: thin;
  scrollbar-color: var(--b1) transparent;
}
ENDOFFILE

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║      PHASE 3 + 4 COMPLETE ✓               ║"
echo "╠═══════════════════════════════════════════╣"
echo "║  PHASE 3 — Backend DB                     ║"
echo "║  backend/db/database.py                   ║"
echo "║  backend/db/models.py                     ║"
echo "║  backend/db/crud.py                       ║"
echo "║  backend/routes/vault.py                  ║"
echo "║  backend/routes/chat.py   (updated)       ║"
echo "║  backend/app.py           (overwritten)   ║"
echo "╠═══════════════════════════════════════════╣"
echo "║  PHASE 4 — Frontend UI                    ║"
echo "║  frontend/src/store/appStore.js           ║"
echo "║  frontend/src/store/chatStore.js          ║"
echo "║  frontend/src/store/vaultStore.js         ║"
echo "║  frontend/src/components/Markdown.jsx     ║"
echo "║  frontend/src/components/BottomNav.jsx    ║"
echo "║  frontend/src/components/BottomNav.css    ║"
echo "║  frontend/src/panels/MindPanel.jsx        ║"
echo "║  frontend/src/panels/MindPanel.css        ║"
echo "║  frontend/src/App.jsx     (overwritten)   ║"
echo "║  frontend/src/App.css     (overwritten)   ║"
echo "║  frontend/src/api.js      (overwritten)   ║"
echo "╠═══════════════════════════════════════════╣"
echo "║  Routes now live:                         ║"
echo "║  GET    /health                           ║"
echo "║  GET    /chat/ping                        ║"
echo "║  GET    /chat/new                         ║"
echo "║  POST   /chat/send                        ║"
echo "║  GET    /chat/history/{session_id}        ║"
echo "║  DELETE /chat/{session_id}               ║"
echo "║  GET    /vault                            ║"
echo "║  POST   /vault                            ║"
echo "║  DELETE /vault/{item_id}                  ║"
echo "║  GET    /vault/count                      ║"
echo "╠═══════════════════════════════════════════╣"
echo "║  NEXT STEPS:                              ║"
echo "║  1. cd anra-workspace/backend             ║"
echo "║  2. uvicorn app:app --reload              ║"
echo "║  3. cd anra-workspace/frontend            ║"
echo "║  4. npm run dev                           ║"
echo "║  5. open http://localhost:5173            ║"
echo "╠═══════════════════════════════════════════╣"
echo "║  Paste this output to orchestrator        ║"
echo "║  before Phase 5                           ║"
echo "╚═══════════════════════════════════════════╝"
