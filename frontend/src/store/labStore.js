import { create } from 'zustand'
import { runLab, saveToVault } from '../api'

const useLabStore = create((set, get) => ({
  results: [],
  busy: false,
  error: null,
  activeMode: 'analyze',

  setActiveMode: (mode) => set({ activeMode: mode }),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearResults: () => set({ results: [] }),

  run: async (idea, mode, model, context = '') => {
    set({ busy: true, error: null })
    try {
      const data = await runLab(idea, mode, model, context)
      const result = {
        id: Date.now(),
        idea: data.idea_echo,
        mode: data.mode,
        result: data.result,
        model_used: data.model_used,
        timestamp: new Date().toISOString()
      }
      set((s) => ({ results: [result, ...s.results] }))
    } catch (e) {
      set({ error: e.message })
    } finally {
      set({ busy: false })
    }
  },

  saveToVault: async (resultId) => {
    const r = get().results.find(x => x.id === resultId)
    if (!r) return
    await saveToVault(r.idea, r.result)
  },
}))

export default useLabStore
