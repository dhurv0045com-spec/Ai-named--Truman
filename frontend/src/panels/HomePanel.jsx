import React, { useState, useEffect, useMemo } from 'react'
import { getStats, getInsight, healthCheck } from '../api'
import useAppStore from '../store/appStore'

const PHASES = [
  { number: 1, title: 'Foundation',         status: 'complete', completion: 100, color: 'var(--green)',  icon: '⬢', desc: 'Core architecture, attention heads, tokenizer pipeline' },
  { number: 2, title: 'Language Interface',  status: 'complete', completion: 100, color: 'var(--green)',  icon: '◈', desc: 'Natural language comprehension, reasoning chains' },
  { number: 3, title: 'Memory Systems',      status: 'complete', completion: 100, color: 'var(--green)',  icon: '⊡', desc: 'Persistent memory, context recall, knowledge graph' },
  { number: 4, title: 'Workspace',           status: 'active',   completion: 75,  color: 'var(--cyan)',   icon: '⟐', desc: 'Live web dashboard, multi-panel AI environment' },
  { number: 5, title: 'Ouroboros',            status: 'planned',  completion: 0,   color: 'var(--dim)',    icon: '◎', desc: 'Self-improvement loops, autonomous code generation' },
  { number: 6, title: 'Symbolic Bridge',      status: 'planned',  completion: 0,   color: 'var(--dim)',    icon: '⊛', desc: 'Abstract reasoning, mathematical consciousness' },
]

const QUICK = [
  { id: 'mind',   icon: '◈', label: 'MIND',   color: 'var(--cyan)',   desc: 'Chat with TRUMAN' },
  { id: 'build',  icon: '⟨/⟩', label: 'BUILD', color: 'var(--plasma)', desc: 'Generate code' },
  { id: 'lab',    icon: '⬡', label: 'LAB',    color: 'var(--green)',  desc: 'Analyze ideas' },
  { id: 'cosmos', icon: '✦', label: 'COSMOS', color: 'var(--ember)',  desc: 'Explore space & science' },
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
  const [stats,   setStats]    = useState({ total_messages: 0, total_sessions: 0, vault_items: 0, ai_ready: false, provider: '—' })
  const [insight, setInsight]  = useState('')
  const [loadingInsight, setLoadingInsight] = useState(false)
  const [aiStatus, setAiStatus] = useState(null)
  const [expandedPhase, setExpandedPhase] = useState(null)

  const welcome = useMemo(() => getWelcomeMessage(), [])

  useEffect(() => {
    // Load stats - handle gracefully if backend hasn't set AI keys
    getStats()
      .then((data) => setStats(data))
      .catch(() => {})

    // Load health to check AI status
    healthCheck()
      .then((data) => setAiStatus(data.ai || null))
      .catch(() => {})

    // Try to fetch initial insight (will fail gracefully if no AI key)
    fetchInsight()
  }, [])

  const fetchInsight = async () => {
    setLoadingInsight(true)
    try {
      const data = await getInsight()
      setInsight(data.insight)
    } catch (e) {
      // If AI isn't configured, show a meaningful fallback
      setInsight('Configure your AI keys in Railway to unlock TRUMAN\'s live insights.')
    } finally {
      setLoadingInsight(false)
    }
  }

  return (
    <div className="home-panel panel-enter">
      <div className="home-hero">
        <div className="home-wordmark">AN·<span>RA</span></div>
        <div className="home-subtitle">ARTIFICIAL REASONING ARCHITECTURE</div>
        <div className="home-welcome">{welcome}</div>

        {/* AI Status Indicator */}
        {aiStatus && (
          <div className="ai-status-row">
            <span
              className="ai-status-dot"
              style={{
                background: aiStatus.ready ? 'var(--green)' : 'var(--gold)',
                boxShadow: aiStatus.ready
                  ? '0 0 8px var(--green-glow)'
                  : '0 0 8px var(--gold-glow)',
              }}
            />
            <span className="ai-status-text">
              {aiStatus.ready
                ? `AI: ${aiStatus.provider.toUpperCase()}${aiStatus.failover ? ' + FAILOVER' : ''}`
                : 'AI: NO KEY SET'
              }
            </span>
          </div>
        )}

        {/* Live Insight */}
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

      {/* Stats Grid */}
      <div className="home-stats">
        {[
          { label: 'MESSAGES',  value: stats.total_messages, color: 'var(--cyan)'   },
          { label: 'SESSIONS',  value: stats.total_sessions, color: 'var(--plasma)' },
          { label: 'VAULT',     value: stats.vault_items,    color: 'var(--gold)'   },
          { label: 'PHASE',     value: 4,                    color: 'var(--green)'  },
        ].map((s) => (
          <div key={s.label} className="stat-card">
            <div className="stat-number" style={{ color: s.color }}>{s.value}</div>
            <div className="stat-label">{s.label}</div>
          </div>
        ))}
      </div>

      <div className="section-label">BUILD PROGRESS</div>
      <div className="phase-grid">
        {PHASES.map((p, i) => (
          <div
            key={p.number}
            className={`phase-card${p.status === 'active' ? ' phase-card--active' : ''}`}
            style={{ animationDelay: `${i * 0.06}s`, cursor: 'pointer' }}
            onClick={() => setExpandedPhase(expandedPhase === p.number ? null : p.number)}
          >
            <div className="phase-num" style={{ color: p.color }}>
              <span style={{ marginRight: '6px' }}>{p.icon}</span>
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
            {expandedPhase === p.number && (
              <div className="phase-desc fade-in">{p.desc}</div>
            )}
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
            <span className="quick-desc">{q.desc}</span>
          </button>
        ))}
      </div>
    </div>
  )
}
