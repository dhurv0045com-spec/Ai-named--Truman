import React, { useState, useRef, useEffect } from 'react'
import useChatStore from '../store/chatStore'
import useAppStore from '../store/appStore'
import { useToast } from './Toast'

export default function QuickCapture() {
  const [open, setOpen] = useState(false)
  const [text, setText] = useState('')
  const send = useChatStore((s) => s.send)
  const sessionId = useAppStore((s) => s.sessionId)
  const model = useAppStore((s) => s.model)
  const setActivePanel = useAppStore((s) => s.setActivePanel)
  const toast = useToast()
  const inputRef = useRef(null)

  useEffect(() => {
    if (open && inputRef.current) {
      inputRef.current.focus()
    }
  }, [open])

  const handleExpand = async () => {
    const raw = text.trim()
    if (!raw || !sessionId) return

    // Prefix with expansion prompt
    const prompt = `Expand and deepen this raw idea — go to the root of it. Find what makes it interesting, what it connects to, and where it could lead:\n\n"${raw}"`

    setOpen(false)
    setText('')
    setActivePanel('mind')

    // Small delay so panel transition completes
    setTimeout(() => {
      send(prompt, sessionId, model)
    }, 150)

    if (toast) toast.info('EXPANDING IDEA...')
  }

  const handleKeyDown = (e) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleExpand()
    }
    if (e.key === 'Escape') {
      setOpen(false)
      setText('')
    }
  }

  return (
    <>
      {/* FAB */}
      <button
        className="fab"
        onClick={() => setOpen(true)}
        aria-label="Quick capture"
      >
        <span className="fab-icon">+</span>
      </button>

      {/* Modal */}
      {open && (
        <div className="capture-overlay" onClick={() => { setOpen(false); setText('') }}>
          <div className="capture-modal" onClick={(e) => e.stopPropagation()}>
            <div className="capture-header">
              <span className="capture-title">QUICK CAPTURE</span>
              <button className="capture-close" onClick={() => { setOpen(false); setText('') }}>✕</button>
            </div>
            <textarea
              ref={inputRef}
              className="capture-input"
              rows={4}
              value={text}
              onChange={(e) => setText(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder="Drop a raw idea, fragment, question — anything..."
            />
            <button
              className="capture-expand-btn"
              onClick={handleExpand}
              disabled={!text.trim()}
            >
              ⟡ EXPAND
            </button>
            <div className="capture-hint">
              Opens in MIND with AI expansion
            </div>
          </div>
        </div>
      )}
    </>
  )
}
