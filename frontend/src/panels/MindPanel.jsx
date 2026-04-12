import React, { useEffect, useRef, useState } from 'react'
import useChatStore from '../store/chatStore'
import useAppStore from '../store/appStore'
import useVaultStore from '../store/vaultStore'
import useLabStore from '../store/labStore'
import Markdown from '../components/Markdown'
import { useToast } from '../components/Toast'
import { newSession } from '../api'

const MODELS = [
  { value: 'anthropic/claude-3.5-haiku', label: 'Claude 3.5 Haiku' },
  { value: 'anthropic/claude-3-opus',    label: 'Claude 3 Opus' },
  { value: 'openai/gpt-4o',              label: 'GPT-4o' },
  { value: 'openai/gpt-4o-mini',         label: 'GPT-4o Mini' },
  { value: 'google/gemini-flash-1.5',    label: 'Gemini Flash 1.5' },
  { value: 'deepseek/deepseek-chat',     label: 'DeepSeek Chat' },
]

const SUGGESTIONS = [
  'Explain transformers from scratch',
  'Compare LSTM vs Transformer',
  'What makes a good system design?',
  'Write a learning roadmap for AI',
  'Break down attention mechanisms',
  'Explain backpropagation intuitively',
]

export default function MindPanel() {
  const messages    = useChatStore((s) => s.messages)
  const busy        = useChatStore((s) => s.busy)
  const error       = useChatStore((s) => s.error)
  const send        = useChatStore((s) => s.send)
  const loadHistory = useChatStore((s) => s.loadHistory)

  const sessionId    = useAppStore((s) => s.sessionId)
  const setSessionId = useAppStore((s) => s.setSessionId)
  const model        = useAppStore((s) => s.model)
  const setModel     = useAppStore((s) => s.setModel)
  const setActivePanel = useAppStore((s) => s.setActivePanel)

  const saveVault  = useVaultStore((s) => s.save)
  const labSetMode = useLabStore((s) => s.setActiveMode)
  const toast      = useToast()

  const [input, setInput] = useState('')
  const [saved, setSaved] = useState({})
  const scrollRef = useRef(null)
  const textareaRef = useRef(null)

  useEffect(() => {
    const init = async () => {
      let sid = sessionId
      if (!sid) {
        try {
          const data = await newSession()
          sid = data.session_id
          setSessionId(sid)
        } catch { return }
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

  // Auto-grow textarea
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = Math.min(textareaRef.current.scrollHeight, 120) + 'px'
    }
  }, [input])

  const handleSend = (text) => {
    const msg = (text || input).trim()
    if (!msg || busy || !sessionId) return
    setInput('')
    send(msg, sessionId, model)
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSend()
    }
  }

  const handleCopy = (content) => {
    navigator.clipboard.writeText(content)
    if (toast) toast.success('COPIED')
  }

  const handleSaveToVault = async (content, idx) => {
    const title = content.slice(0, 60).replace(/\n/g, ' ') + '…'
    await saveVault(title, content)
    setSaved((s) => ({ ...s, [idx]: true }))
    if (toast) toast.success('SAVED TO VAULT')
    setTimeout(() => setSaved((s) => ({ ...s, [idx]: false })), 2000)
  }

  const handleSendToLab = (content) => {
    // Pre-fill the lab with this content for analysis
    labSetMode('analyze')
    setActivePanel('lab')
    if (toast) toast.info('SENT TO LAB')
  }

  return (
    <div className="mind-panel panel-enter">
      <div className="mind-header">
        <div className="mind-title">
          <span className="mind-name">AN·<span>RA</span></span>
          <span className="mind-tag">MIND</span>
        </div>
        <select
          className="model-select"
          value={model}
          onChange={(e) => setModel(e.target.value)}
          id="model-selector"
          name="model-selector"
        >
          {MODELS.map((m) => (
            <option key={m.value} value={m.value}>{m.label}</option>
          ))}
        </select>
      </div>

      <div className="mind-messages" ref={scrollRef}>
        {messages.length === 0 && !busy && (
          <div className="mind-empty">
            <div className="mind-empty__glyph">◈</div>
            <div className="mind-empty__text">TRUMAN is ready. Ask anything.</div>
            <div className="mind-empty__suggestions">
              {SUGGESTIONS.map((q) => (
                <button
                  key={q}
                  className="suggest-pill"
                  onClick={() => handleSend(q)}
                >
                  {q}
                </button>
              ))}
            </div>
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
                <div className="message__actions">
                  <button
                    className="msg-action-btn"
                    onClick={() => handleCopy(msg.content)}
                    title="Copy"
                  >
                    ⊡ COPY
                  </button>
                  <button
                    className={`msg-action-btn${saved[idx] ? ' msg-action-btn--saved' : ''}`}
                    onClick={() => handleSaveToVault(msg.content, idx)}
                    title="Save to Vault"
                  >
                    {saved[idx] ? '✓ SAVED' : '⊞ VAULT'}
                  </button>
                  <button
                    className="msg-action-btn"
                    onClick={() => handleSendToLab(msg.content)}
                    title="Send to Lab"
                  >
                    ⬡ LAB
                  </button>
                </div>
              </div>
            )}
          </div>
        ))}

        {busy && (
          <div className="message message--assistant">
            <div className="thinking-indicator">
              <div className="thinking-wave">
                <span /><span /><span /><span /><span />
              </div>
              <span className="thinking-label">TRUMAN is thinking</span>
            </div>
          </div>
        )}

        {error && (
          <div className="mind-error">⚠ {error}</div>
        )}
      </div>

      <div className="mind-input-area">
        <textarea
          ref={textareaRef}
          className="mind-textarea"
          rows={1}
          value={input}
          onChange={(e) => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Ask TRUMAN anything..."
          disabled={busy}
          id="mind-input"
          name="mind-input"
        />
        <button
          className="send-btn"
          onClick={() => handleSend()}
          disabled={busy || !input.trim()}
        >
          {busy ? '...' : 'SEND'}
        </button>
      </div>
    </div>
  )
}
