// ALL backend calls go through this file only.
// Never call fetch() from any component directly.

const BASE = '/api'

const post = async (url, body) => {
  const res = await fetch(`${BASE}${url}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

const get = async (url) => {
  const res = await fetch(`${BASE}${url}`)
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

const del = async (url) => {
  const res = await fetch(`${BASE}${url}`, { method: 'DELETE' })
  if (!res.ok) throw new Error(`Failed: ${res.status}`)
  return res.json()
}

// HEALTH
export const healthCheck = () => get('/health')

// CHAT
export const newSession    = () => get('/chat/new')
export const sendMessage   = (message, session_id, model) =>
  post('/chat/send', { message, session_id, model, vault_context: '' })
export const getHistory    = (session_id) => get(`/chat/history/${session_id}`)
export const deleteSession = (session_id) => del(`/chat/${session_id}`)

// VAULT
export const getVault       = () => get('/vault')
export const saveToVault    = (title, content) => post('/vault', { title, content })
export const deleteVaultItem= (id) => del(`/vault/${id}`)
export const getVaultCount  = () => get('/vault/count')

// BUILD
export const generateCode = (prompt, mode, model) =>
  post('/build/code', { prompt, mode, model })
export const buildPing = () => get('/build/ping')

// LAB
export const runLab  = (idea, mode, model, context = '') =>
  post('/lab/run', { idea, mode, model, context })
export const labPing = () => get('/lab/ping')

// COSMOS
export const getCosmosSections = () => get('/cosmos/sections')
export const getCosmosSection  = (category) => get(`/cosmos/${category}`)
export const askCosmos         = (question, category) =>
  post('/cosmos/ask', { question, category })

// INSIGHTS
export const getInsight = () => get('/insights/probe')
export const getStats   = () => get('/insights/stats')
