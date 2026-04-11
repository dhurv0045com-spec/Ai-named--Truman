import { create } from 'zustand'

const useAppStore = create((set) => ({
  activePanel: 'mind',
  model: 'anthropic/claude-3.5-haiku',
  status: 'idle',
  sessionId: localStorage.getItem('anra_session_id') || null,

  setActivePanel: (panel) => set({ activePanel: panel }),
  setModel: (model) => set({ model }),
  setStatus: (status) => set({ status }),
  setSessionId: (id) => {
    localStorage.setItem('anra_session_id', id)
    set({ sessionId: id })
  },
}))

export default useAppStore
