import React from 'react'
import useAppStore from '../store/appStore'

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
