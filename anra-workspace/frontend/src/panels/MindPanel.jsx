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
