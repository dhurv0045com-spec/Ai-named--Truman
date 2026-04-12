import React, { useState, useEffect, useRef, useCallback } from 'react'
import { getInsight } from '../api'
import useAppStore from '../store/appStore'
import useChatStore from '../store/chatStore'
import useVaultStore from '../store/vaultStore'

const IDLE_FIRST = 40000   // 40s before first insight
const IDLE_REPEAT = 80000  // 80s between subsequent insights

export default function ProactiveInsight() {
  const [insight, setInsight] = useState(null)
  const [visible, setVisible] = useState(false)
  const [loading, setLoading] = useState(false)
  const timerRef = useRef(null)
  const repeatRef = useRef(null)

  const setActivePanel = useAppStore((s) => s.setActivePanel)
  const model = useAppStore((s) => s.model)
  const sessionId = useAppStore((s) => s.sessionId)
  const chatBusy = useChatStore((s) => s.busy)
  const send = useChatStore((s) => s.send)
  const saveVault = useVaultStore((s) => s.save)

  const fetchInsight = useCallback(async () => {
    if (chatBusy || visible || loading) return
    setLoading(true)
    try {
      const data = await getInsight()
      if (data.insight) {
        setInsight(data.insight)
        setVisible(true)
      }
    } catch {
      // AI not configured — don't show anything
    } finally {
      setLoading(false)
    }
  }, [chatBusy, visible, loading])

  // Reset idle timer on any user interaction
  const resetTimer = useCallback(() => {
    if (timerRef.current) clearTimeout(timerRef.current)
    if (repeatRef.current) clearInterval(repeatRef.current)

    timerRef.current = setTimeout(() => {
      fetchInsight()
      // After first, repeat every IDLE_REPEAT
      repeatRef.current = setInterval(() => {
        fetchInsight()
      }, IDLE_REPEAT)
    }, IDLE_FIRST)
  }, [fetchInsight])

  useEffect(() => {
    const events = ['mousemove', 'keydown', 'touchstart', 'scroll', 'click']
    events.forEach((e) => window.addEventListener(e, resetTimer, { passive: true }))
    resetTimer()

    return () => {
      events.forEach((e) => window.removeEventListener(e, resetTimer))
      if (timerRef.current) clearTimeout(timerRef.current)
      if (repeatRef.current) clearInterval(repeatRef.current)
    }
  }, [resetTimer])

  const handleExplore = () => {
    if (!insight || !sessionId) return
    setVisible(false)
    setActivePanel('mind')
    setTimeout(() => {
      send(`Explore this insight deeper — what does it connect to, what does it imply, what would change if it were true?\n\n"${insight}"`, sessionId, model)
    }, 150)
  }

  const handleSave = async () => {
    if (!insight) return
    const title = insight.slice(0, 50) + '…'
    await saveVault(title, insight)
    setVisible(false)
  }

  const handleDismiss = () => {
    setVisible(false)
    resetTimer()
  }

  if (!visible || !insight) return null

  return (
    <div className="proactive-insight">
      <div className="proactive-insight__label">⟡ TRUMAN THOUGHT</div>
      <div className="proactive-insight__text">{insight}</div>
      <div className="proactive-insight__actions">
        <button className="proactive-btn proactive-btn--explore" onClick={handleExplore}>
          EXPLORE
        </button>
        <button className="proactive-btn proactive-btn--save" onClick={handleSave}>
          SAVE
        </button>
        <button className="proactive-btn proactive-btn--dismiss" onClick={handleDismiss}>
          ✕
        </button>
      </div>
    </div>
  )
}
