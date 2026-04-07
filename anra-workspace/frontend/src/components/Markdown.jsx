import React from 'react'

const inlineStyles = {
  p: {
    color: 'var(--tx)',
    lineHeight: '1.8',
    margin: '4px 0',
  },
  strong: {
    color: 'var(--hi)',
    fontWeight: 500,
  },
  code: {
    background: 'rgba(255,255,255,.08)',
    padding: '2px 7px',
    borderRadius: '4px',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: '0.88em',
    color: '#aaa',
  },
  h3: {
    color: 'var(--hi)',
    fontFamily: "'Cinzel', serif",
    fontSize: '1em',
    margin: '10px 0 4px',
  },
  li: {
    color: 'var(--tx)',
    paddingLeft: '16px',
    lineHeight: '1.7',
    listStyle: 'disc',
  },
  pre: {
    background: 'rgba(0,0,0,.6)',
    border: '1px solid var(--b1)',
    borderRadius: '8px',
    padding: '12px 16px',
    fontFamily: "'JetBrains Mono', monospace",
    fontSize: '0.82em',
    color: '#7dd3fc',
    overflowX: 'auto',
    whiteSpace: 'pre',
    margin: '8px 0',
  },
}

function parseInline(text) {
  const parts = []
  const re = /(\*\*(.+?)\*\*|`([^`]+)`)/g
  let last = 0
  let m
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) {
      parts.push(<span key={last}>{text.slice(last, m.index)}</span>)
    }
    if (m[0].startsWith('**')) {
      parts.push(<strong key={m.index} style={inlineStyles.strong}>{m[2]}</strong>)
    } else {
      parts.push(<code key={m.index} style={inlineStyles.code}>{m[3]}</code>)
    }
    last = m.index + m[0].length
  }
  if (last < text.length) parts.push(<span key={last}>{text.slice(last)}</span>)
  return parts
}

function renderText(segment, segIdx) {
  const lines = segment.split('\n')
  const elements = []
  let listItems = []

  const flushList = (i) => {
    if (listItems.length) {
      elements.push(
        <ul key={`ul-${segIdx}-${i}`} style={{ margin: '4px 0', paddingLeft: 0 }}>
          {listItems}
        </ul>
      )
      listItems = []
    }
  }

  lines.forEach((line, i) => {
    if (line.startsWith('# ') || line.startsWith('## ') || line.startsWith('### ')) {
      flushList(i)
      const text = line.replace(/^#{1,3}\s/, '')
      elements.push(<h3 key={`h-${segIdx}-${i}`} style={inlineStyles.h3}>{text}</h3>)
    } else if (line.startsWith('- ') || line.startsWith('* ')) {
      const text = line.slice(2)
      listItems.push(
        <li key={`li-${segIdx}-${i}`} style={inlineStyles.li}>
          {parseInline(text)}
        </li>
      )
    } else if (line.trim() === '') {
      flushList(i)
      elements.push(<br key={`br-${segIdx}-${i}`} />)
    } else {
      flushList(i)
      elements.push(
        <p key={`p-${segIdx}-${i}`} style={inlineStyles.p}>
          {parseInline(line)}
        </p>
      )
    }
  })
  flushList('end')
  return elements
}

export default function Markdown({ content }) {
  if (!content) return null

  const parts = content.split(/(```[\s\S]*?```)/g)

  return (
    <div style={{ wordBreak: 'break-word' }}>
      {parts.map((part, idx) => {
        if (part.startsWith('```') && part.endsWith('```')) {
          const inner = part.slice(3, -3).replace(/^\w+\n/, '')
          return <pre key={idx} style={inlineStyles.pre}>{inner}</pre>
        }
        return <span key={idx}>{renderText(part, idx)}</span>
      })}
    </div>
  )
}
