import { create } from 'zustand'
import { getVault, saveToVault, deleteVaultItem } from '../api'

const useVaultStore = create((set, get) => ({
  items: [],
  loading: false,

  setItems: (items) => set({ items }),
  setLoading: (loading) => set({ loading }),

  load: async () => {
    set({ loading: true })
    try {
      const data = await getVault()
      set({ items: data })
    } finally {
      set({ loading: false })
    }
  },

  save: async (title, content) => {
    await saveToVault(title, content)
    get().load()
  },

  remove: async (id) => {
    await deleteVaultItem(id)
    set((s) => ({ items: s.items.filter((i) => i.id !== id) }))
  },
}))

export default useVaultStore
