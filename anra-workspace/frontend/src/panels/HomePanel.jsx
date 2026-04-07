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
