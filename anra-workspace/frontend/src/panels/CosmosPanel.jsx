import React, { useState, useEffect, useRef } from 'react'
import useCosmosStore from '../store/cosmosStore'
import Markdown from '../components/Markdown'
import './CosmosPanel.css'

const SUGGESTIONS = {
  india:    ['How did Chandrayaan-3 land?', 'What is Gaganyaan?', 'Compare ISRO vs NASA budget'],
  mars:     ['How long to travel to Mars?', 'Can Mars be terraformed?', 'What has Perseverance found?'],
  sun:      ['What is a solar flare?', 'How does Aditya-L1 work?', 'How long until the Sun dies?'],
  raptor:   ['How does full-flow combustion work?', 'Compare Raptor vs Merlin', 'Why methane fuel?'],
  universe: ['What is dark matter?', 'What did JWST discover?', 'How big is the observable universe?'],
  ai:       ['What is a transformer?', 'How did AlphaFold work?', 'What is AN-RA building toward?'],
}

export default function CosmosPanel() {
  const sections       = useCosmosStore((s) => s.sections)
  const activeSection  = useCosmosStore((s) => s.activeSection)
  const sectionData    = useCosmosStore((s) => s.sectionData)
  const conversation   = useCosmosStore((s) => s.conversation)
  const busy           = useCosmosStore((s) => s.busy)
  const loadSections   = useCosmosStore((s) => s.loadSections)
  const loadSection    = useCosmosStore((s) => s.loadSection)
  const ask            = useCosmosStore((s) => s.ask)

  const [input, setInput] = useState('')
  const scrollRef = useRef(null)

  useEffect(() => {
    loadSections()
    loadSection('universe')
  }, [])

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight
    }
  }, [conversation, busy])

  const handleAsk = () => {
    if (!input.trim() || busy) return
    ask(input.trim())
    setInput('')
  }

  const accent = sectionData?.accent || 'var(--cyan)'

  return (
    <div className="cosmos-panel">
      <div className="cosmos-pills-row">
        {sections.map((s) => (
          <button
            key={s.key}
            className={`cosmos-pill${activeSection === s.key ? ' cosmos-pill--active' : ''}`}
            style={activeSection === s.key ? {
              color: s.accent,
              borderColor: s.accent,
            } : {}}
            onClick={() => loadSection(s.key)}
          >
            {s.key.toUpperCase()}
          </button>
        ))}
      </div>

      <div className="cosmos-body">
        <div className="cosmos-info">
          {sectionData && (
            <>
              <div className="cosmos-title">{sectionData.title}</div>
              <div className="cosmos-accent-bar" style={{ background: accent }} />
              <div className="cosmos-summary">{sectionData.summary}</div>

              <div className="cosmos-facts">
                {sectionData.facts?.map((f, i) => (
                  <div
                    key={i}
                    className="cosmos-fact"
                    style={{ borderLeftColor: accent }}
                  >
                    {f}
                  </div>
                ))}
              </div>

              {sectionData.missions && (
                <div className="cosmos-missions">
                  {sectionData.missions.map((m) => (
                    <span key={m} className="cosmos-mission-pill">{m}</span>
                  ))}
                </div>
              )}

              {sectionData.next && (
                <div className="cosmos-next">
                  <span className="cosmos-next-label">NEXT →</span>
                  {sectionData.next}
                </div>
              )}
            </>
          )}
        </div>

        <div className="cosmos-convo">
          <div className="cosmos-messages" ref={scrollRef}>
            {conversation.length === 0 && (
              <div className="cosmos-suggestions">
                {(SUGGESTIONS[activeSection] || []).map((q) => (
                  <button
                    key={q}
                    className="cosmos-suggest-pill"
                    onClick={() => { setInput(q); ask(q) }}
                  >
                    {q}
                  </button>
                ))}
              </div>
            )}

            {conversation.map((msg, i) => (
              <div key={i} className={`cosmos-msg cosmos-msg--${msg.role}`}>
                {msg.role === 'user'
                  ? <span>{msg.content}</span>
                  : <Markdown content={msg.content} />
                }
              </div>
            ))}

            {busy && (
              <div className="cosmos-msg cosmos-msg--assistant">
                <span className="cosmos-thinking">AN·RA is exploring</span>
              </div>
            )}
          </div>

          <div className="cosmos-input-row">
            <textarea
              className="cosmos-textarea"
              rows={2}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter' && !e.shiftKey) {
                  e.preventDefault()
                  handleAsk()
                }
              }}
              placeholder={`Ask AN·RA about ${sectionData?.title || 'the cosmos'}...`}
              style={{ '--focus-accent': accent }}
              disabled={busy}
            />
            <button
              className="cosmos-ask-btn"
              style={{ background: accent }}
              onClick={handleAsk}
              disabled={busy || !input.trim()}
            >
              ASK
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
