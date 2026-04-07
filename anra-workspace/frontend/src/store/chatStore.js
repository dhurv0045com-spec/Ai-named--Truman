import { create } from 'zustand'
import { sendMessage, getHistory } from '../api'

const useChatStore = create((set, get) => ({
  messages: [],
  busy: false,
  error: null,

  setMessages: (messages) => set({ messages }),
  addMessage: (role, content) =>
    set((s) => ({ messages: [...s.messages, { role, content }] })),
  setBusy: (busy) => set({ busy }),
  setError: (error) => set({ error }),
  clearChat: () => set({ messages: [] }),

  send: async (message, sessionId, model) => {
    set({ busy: true, error: null })
    get().addMessage('user', message)
    try {
      const data = await sendMessage(message, sessionId, model)
      get().addMessage('assistant', data.reply)
    } catch (e) {
      set({ error: e.message })
    } finally {
      set({ busy: false })
    }
  },

  loadHistory: async (sessionId) => {
    try {
      const data = await getHistory(sessionId)
      set({ messages: data.messages || [] })
    } catch (e) {
      console.error('History load failed', e)
    }
  },
}))

export default useChatStore
