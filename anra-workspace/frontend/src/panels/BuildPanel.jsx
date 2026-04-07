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
