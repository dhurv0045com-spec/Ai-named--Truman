import React, { useState } from 'react'
import useBuildStore from '../store/buildStore'
import useAppStore from '../store/appStore'
import Markdown from '../components/Markdown'
import { useToast } from '../components/Toast'

const MODES = [
  { id: 'numpy',   label: 'NUMPY',   color: 'var(--cyan)' },
  { id: 'pytorch', label: 'PYTORCH', color: 'var(--plasma)' },
  { id: 'fastapi', label: 'FASTAPI', color: 'var(--green)' },
  { id: 'algo',    label: 'ALGO',    color: 'var(--gold)' },
  { id: 'explain', label: 'EXPLAIN', color: 'var(--ember)' },
  { id: 'general', label: 'GENERAL', color: 'var(--hi)' },
]

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
  const toast = useToast()

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
    if (toast) toast.success('SAVED TO VAULT')
    setTimeout(() => setSaved((s) => ({ ...s, [id]: false })), 2000)
  }

  return (
    <div className="build-panel panel-enter">
      <div className="build-left">
        <div className="build-header">
          <span className="build-name">AN·<span>RA</span></span>
          <span className="build-tag">BUILD · CODE GENERATION</span>
        </div>

        <div className="build-modes">
          {MODES.map((m) => (
            <button
              key={m.id}
              className={`mode-btn${activeMode === m.id ? ' mode-btn--active' : ''}`}
              style={activeMode === m.id ? {
                color: m.color,
                borderColor: m.color,
                background: `color-mix(in srgb, ${m.color} 8%, transparent)`,
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
          placeholder={"Describe what you want to build..."}
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
            <span className="gen-label">TRUMAN is writing code</span>
            <span className="gen-dots"><span /><span /><span /></span>
          </div>
        )}

        {results.map((r) => (
          <div key={r.id} className="result-card">
            <div className="result-card__header">
              <span className="result-prompt">{r.prompt}</span>
              <div className="result-badges">
                <span className="badge badge--mode">{r.mode.toUpperCase()}</span>
                <span className="badge badge--model">{r.model_used.split('/').pop()}</span>
              </div>
            </div>
            <div className="result-card__body">
              <Markdown content={r.code} />
            </div>
            <div className="result-card__footer">
              <button
                className={`vault-save-btn${saved[r.id] ? ' vault-save-btn--saved' : ''}`}
                onClick={() => handleSave(r.id)}
              >
                {saved[r.id] ? 'SAVED ✓' : '⊞ VAULT'}
              </button>
              <button className="btn btn--ghost" onClick={clearResults}>
                CLEAR
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
