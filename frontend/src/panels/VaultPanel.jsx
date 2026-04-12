import React, { useState, useEffect } from 'react'
import useVaultStore from '../store/vaultStore'
import Markdown from '../components/Markdown'
import { useToast } from '../components/Toast'

function formatDate(iso) {
  const d = new Date(iso)
  return d.toLocaleDateString('en-GB', {
    day: '2-digit', month: 'short', year: 'numeric'
  })
}

function readTime(text) {
  const words = text.split(/\s+/).length
  const mins = Math.max(1, Math.ceil(words / 220))
  return `${mins} min read`
}

export default function VaultPanel() {
  const items       = useVaultStore((s) => s.items)
  const loading     = useVaultStore((s) => s.loading)
  const load        = useVaultStore((s) => s.load)
  const remove      = useVaultStore((s) => s.remove)
  const toast       = useToast()

  const [searchQuery,   setSearchQuery]   = useState('')
  const [expandedItem,  setExpandedItem]  = useState(null)

  useEffect(() => { load() }, [])

  const filtered = items.filter(item =>
    item.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
    item.content.toLowerCase().includes(searchQuery.toLowerCase())
  )

  const handleDelete = async (id) => {
    await remove(id)
    if (expandedItem?.id === id) setExpandedItem(null)
    if (toast) toast.info('ITEM DELETED')
  }

  const handleExport = () => {
    if (items.length === 0) return
    const text = items.map((item, idx) => {
      return `── ${idx + 1}. ${item.title} ──\n${formatDate(item.created_at)}\n\n${item.content}\n`
    }).join('\n' + '═'.repeat(60) + '\n\n')

    const header = `AN·RA VAULT EXPORT\n${new Date().toISOString()}\n${items.length} items\n${'═'.repeat(60)}\n\n`
    const blob = new Blob([header + text], { type: 'text/plain' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `anra-vault-${Date.now()}.txt`
    a.click()
    URL.revokeObjectURL(url)
    if (toast) toast.success('VAULT EXPORTED')
  }

  return (
    <div className="vault-panel panel-enter">
      <div className="vault-header">
        <div className="vault-title-row">
          <div>
            <div className="vault-title">AN·<span>RA</span></div>
            <div className="vault-subtitle">VAULT · SAVED IDEAS</div>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            {items.length > 0 && (
              <button className="vault-export-btn" onClick={handleExport}>
                ↓ EXPORT
              </button>
            )}
            <div className="vault-count">{items.length}</div>
          </div>
        </div>
        <input
          className="vault-search"
          type="text"
          placeholder="Search vault..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          id="vault-search"
          name="vault-search"
        />
      </div>

      <div className="vault-content">
        {loading && (
          <div className="vault-loading">Loading vault...</div>
        )}

        {!loading && items.length === 0 && (
          <div className="vault-empty">
            <div className="vault-empty__icon">⊞</div>
            <div className="vault-empty__text">Your vault is empty</div>
            <div className="vault-empty__sub">
              Save ideas from Mind, Build, and Lab to see them here
            </div>
          </div>
        )}

        {!loading && items.length > 0 && (
          <div className="vault-grid">
            {filtered.map((item) => (
              <div key={item.id} className="vault-card">
                <div className="vault-card__header">
                  <div className="vault-card__title">{item.title}</div>
                  <div className="vault-card__meta">
                    <span className="vault-card__date">{formatDate(item.created_at)}</span>
                    <span className="vault-card__read-time">{readTime(item.content)}</span>
                  </div>
                </div>
                <div className="vault-card__body">
                  {item.content.slice(0, 160)}
                  {item.content.length > 160 && '…'}
                </div>
                <div className="vault-card__footer">
                  <button
                    className="vault-expand-btn"
                    onClick={() => setExpandedItem(item)}
                  >
                    EXPAND
                  </button>
                  <button
                    className="vault-delete-btn"
                    onClick={() => handleDelete(item.id)}
                  >
                    DELETE
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      {expandedItem && (
        <div className="vault-overlay" onClick={() => setExpandedItem(null)}>
          <div className="vault-overlay__content" onClick={(e) => e.stopPropagation()}>
            <button
              className="vault-overlay__close"
              onClick={() => setExpandedItem(null)}
            >
              ✕ CLOSE
            </button>
            <div className="vault-overlay__title">{expandedItem.title}</div>
            <div className="vault-overlay__date">
              {formatDate(expandedItem.created_at)} · {readTime(expandedItem.content)}
            </div>
            <div className="vault-overlay__body">
              <Markdown content={expandedItem.content} />
            </div>
            <button
              className="vault-overlay__delete"
              onClick={() => handleDelete(expandedItem.id)}
            >
              DELETE ITEM
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
