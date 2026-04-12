import React, { useEffect, useState } from 'react'
import useAppStore from './store/appStore'
import useChatStore from './store/chatStore'
import useLabStore from './store/labStore'
import useBuildStore from './store/buildStore'
import useCosmosStore from './store/cosmosStore'
import { ToastProvider } from './components/Toast'
import BottomNav from './components/BottomNav'
import Starfield from './components/Starfield'
import QuickCapture from './components/QuickCapture'
import ProactiveInsight from './components/ProactiveInsight'
import MindPanel from './panels/MindPanel'
import BuildPanel from './panels/BuildPanel'
import HomePanel from './panels/HomePanel'
import LabPanel from './panels/LabPanel'
import CosmosPanel from './panels/CosmosPanel'
import VaultPanel from './panels/VaultPanel'
import { newSession, healthCheck } from './api'

const renderPanel = (panel) => {
  switch (panel) {
    case 'home':   return <HomePanel key="home" />
    case 'mind':   return <MindPanel key="mind" />
    case 'build':  return <BuildPanel key="build" />
    case 'lab':    return <LabPanel key="lab" />
    case 'cosmos': return <CosmosPanel key="cosmos" />
    case 'vault':  return <VaultPanel key="vault" />
    default:       return <HomePanel key="home" />
  }
}

export default function App() {
  const activePanel  = useAppStore((s) => s.activePanel)
  const sessionId    = useAppStore((s) => s.sessionId)
  const setSessionId = useAppStore((s) => s.setSessionId)

  // Global busy state — any panel thinking = BUSY
  const chatBusy   = useChatStore((s) => s.busy)
  const labBusy    = useLabStore((s) => s.busy)
  const buildBusy  = useBuildStore((s) => s.busy)
  const cosmosBusy = useCosmosStore((s) => s.busy)
  const globalBusy = chatBusy || labBusy || buildBusy || cosmosBusy

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

  // Determine status label + color
  const statusLabel = !backendOk ? 'OFFLINE' : globalBusy ? 'BUSY' : 'READY'
  const statusColor = !backendOk ? 'var(--red)' : globalBusy ? 'var(--cyan)' : 'var(--green)'
  const statusClass = globalBusy ? 'status-dot status-dot--busy' : 'status-dot'

  return (
    <ToastProvider>
      {/* Animated starfield */}
      <Starfield />

      {/* Ambient gradient layer on top of stars */}
      <div className="ambient-bg" />

      <div className="app-shell">
        <header className="top-bar">
          <div className="top-bar__brand">
            AN·<span>RA</span>
          </div>
          <div className="top-bar__right">
            <span className="status-label">{statusLabel}</span>
            <div
              className={statusClass}
              style={{
                background: statusColor,
                boxShadow: `0 0 8px ${statusColor}`,
              }}
            />
          </div>
        </header>

        <main className="app-main">
          {renderPanel(activePanel)}
        </main>

        <BottomNav />

        {/* FAB + Quick Capture */}
        <QuickCapture />

        {/* Proactive insight system */}
        <ProactiveInsight />
      </div>
    </ToastProvider>
  )
}
