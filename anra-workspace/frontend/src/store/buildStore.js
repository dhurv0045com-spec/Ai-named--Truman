import { create } from 'zustand'
import { generateCode, saveToVault } from '../api'

const useBuildStore = create((set, get) => ({
  results: [],
  busy: false,
  error: null,
  activeMode: 'general',

  setActiveMode: (mode) => set({ activeMode: mode }),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearResults: () => set({ results: [] }),

  generate: async (prompt, mode, model) => {
    set({ busy: true, error: null })
    try {
      const data = await generateCode(prompt, mode, model)
      const result = {
        id: Date.now(),
        prompt: data.prompt_echo,
        mode: data.mode,
        code: data.code,
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

  saveResultToVault: async (resultId) => {
    const result = get().results.find(r => r.id === resultId)
    if (!result) return
    await saveToVault(result.prompt, result.code)
  },
}))

export default useBuildStore
