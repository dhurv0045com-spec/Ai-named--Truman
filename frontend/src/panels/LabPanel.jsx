import React, { useState } from 'react'
import useLabStore from '../store/labStore'
import useAppStore from '../store/appStore'
import Markdown from '../components/Markdown'
import { useToast } from '../components/Toast'

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
  const toast = useToast()

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
    if (toast) toast.success('SAVED TO VAULT')
    setTimeout(() => setSaved((s) => ({ ...s, [id]: false })), 2000)
  }

  return (
    <div className="lab-panel panel-enter">
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
          style={{ minHeight: '100px' }}
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
            <span className="lab-think-label">TRUMAN is analysing</span>
            <span className="lab-dots"><span /><span /><span /></span>
          </div>
        )}

        {results.map((r) => (
          <div key={r.id} className="lab-card">
            <div className="lab-card__header">
              <span className="lab-idea">{r.idea}</span>
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
