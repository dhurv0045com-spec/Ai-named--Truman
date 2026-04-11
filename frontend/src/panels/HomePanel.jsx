import React, { useState, useEffect, useMemo } from 'react'
import { getStats, getInsight } from '../api'
import useAppStore from '../store/appStore'

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

function getWelcomeMessage() {
  const hour = new Date().getHours()
  if (hour >= 0 && hour < 5)   return 'Late session. The sharpest ideas surface now.'
  if (hour >= 5 && hour < 9)   return 'Early start. The mind is clear — let\'s build.'
  if (hour >= 9 && hour < 12)  return 'Morning cycle active. What are we solving?'
  if (hour >= 12 && hour < 17) return 'Afternoon operations. Deep work territory.'
  if (hour >= 17 && hour < 21) return 'Evening session. Time to think differently.'
  return 'Night mode. This is where the real work happens.'
}

export default function HomePanel() {
  const setActivePanel = useAppStore((s) => s.setActivePanel)
  const [stats,   setStats]   = useState(null)
  const [insight, setInsight] = useState('')
  const [loadingInsight, setLoadingInsight] = useState(false)

  const welcome = useMemo(() => getWelcomeMessage(), [])

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
    <div className="home-panel panel-enter">
      <div className="home-hero">
        <div className="home-wordmark">AN·<span>RA</span></div>
        <div className="home-subtitle">ARTIFICIAL REASONING ARCHITECTURE</div>
        <div className="home-welcome">{welcome}</div>

        <div className="insight-box">
          {loadingInsight ? (
            <div className="insight-loading">
              <span /><span /><span />
            </div>
          ) : (
            <p className="insight-text">{insight || 'Awaiting first thought...'}</p>
          )}
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

      <div className="section-label">BUILD PROGRESS</div>
      <div className="phase-grid">
        {PHASES.map((p, i) => (
          <div
            key={p.number}
            className={`phase-card${p.status === 'active' ? ' phase-card--active' : ''}`}
            style={{ animationDelay: `${i * 0.06}s` }}
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

      <div className="section-label">QUICK ACCESS</div>
      <div className="quick-grid">
        {QUICK.map((q) => (
          <button
            key={q.id}
            className="quick-btn"
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
