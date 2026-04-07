import React, { useEffect, useState } from 'react'
import useAppStore from './store/appStore'
import BottomNav from './components/BottomNav'
import MindPanel from './panels/MindPanel'
import BuildPanel from './panels/BuildPanel'
import HomePanel from './panels/HomePanel'
import LabPanel from './panels/LabPanel'
import CosmosPanel from './panels/CosmosPanel'
import VaultPanel from './panels/VaultPanel'
import { newSession, healthCheck } from './api'

const renderPanel = (panel) => {
  switch (panel) {
    case 'home':   return <HomePanel />
    case 'mind':   return <MindPanel />
    case 'build':  return <BuildPanel />
    case 'lab':    return <LabPanel />
    case 'cosmos': return <CosmosPanel />
    case 'vault':  return <VaultPanel />
    default:       return <MindPanel />
  }
}

export default function App() {
  const activePanel  = useAppStore((s) => s.activePanel)
  const sessionId    = useAppStore((s) => s.sessionId)
  const setSessionId = useAppStore((s) => s.setSessionId)

  const [backendOk, setBackendOk] = useState(false)

  useEffect(() => {
    healthCheck()
      .then(() => setBackendOk(true))
      .catch(() => setBackendOk(false))
    if (!sessionId) {
      newSession()
        .then((data) => setSessionId(data.session_id))
        .catch(() => {})
    }
  }, [])

  return (
    <div className="app-shell">
      <header className="top-bar">
        <div className="top-bar__brand">
          AN·<span>RA</span>
        </div>
        <div className="top-bar__right">
          <div
            className="status-dot"
            style={{
              background: backendOk ? 'var(--green)' : 'var(--red)',
              boxShadow: backendOk
                ? '0 0 8px var(--green)'
                : '0 0 8px var(--red)',
            }}
          />
        </div>
      </header>

      <main className="app-main">
        {renderPanel(activePanel)}
      </main>

      <BottomNav />
    </div>
  )
}
