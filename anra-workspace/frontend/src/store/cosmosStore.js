import { create } from 'zustand'
import { getCosmosSections, getCosmosSection,
         askCosmos, getInsight } from '../api'

const useCosmosStore = create((set, get) => ({
  sections: [],
  activeSection: 'universe',
  sectionData: null,
  conversation: [],
  busy: false,
  insight: '',

  setActiveSection: (key) => set({ activeSection: key }),
  setBusy: (busy) => set({ busy }),
  setInsight: (text) => set({ insight: text }),

  loadSections: async () => {
    const data = await getCosmosSections()
    set({ sections: data.sections })
  },

  loadSection: async (key) => {
    set({ busy: true, conversation: [] })
    try {
      const data = await getCosmosSection(key)
      set({ sectionData: data, activeSection: key })
    } finally {
      set({ busy: false })
    }
  },

  ask: async (question) => {
    set({ busy: true })
    set((s) => ({
      conversation: [...s.conversation,
        { role: 'user', content: question }]
    }))
    try {
      const data = await askCosmos(question, get().activeSection)
      set((s) => ({
        conversation: [...s.conversation,
          { role: 'assistant', content: data.answer }]
      }))
    } finally {
      set({ busy: false })
    }
  },

  fetchInsight: async () => {
    const data = await getInsight()
    set({ insight: data.insight })
  },
}))

export default useCosmosStore
