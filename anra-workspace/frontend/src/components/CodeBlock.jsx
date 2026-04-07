import React, { useState } from 'react'
import './CodeBlock.css'

const KEYWORDS = new Set([
  'def','class','import','from','return','if','else','elif',
  'for','while','async','await','with','as','try','except',
  'True','False','None','in','not','and','or','pass','raise',
  'yield','lambda','global','nonlocal','del','is','break','continue'
])

function tokenizeLine(line) {
  const tokens = []

  // Comment
  const commentIdx = line.indexOf('#')
  if (commentIdx !== -1) {
    const pre = line.slice(0, commentIdx)
    const comment = line.slice(commentIdx)
    if (pre) tokens.push(...tokenizeLine(pre))
    tokens.push({ type: 'comment', value: comment })
    return tokens
  }

  // Decorator
  if (line.trimStart().startsWith('@')) {
    tokens.push({ type: 'decorator', value: line })
    return tokens
  }

  const re = /("""[\s\S]*?"""|'''[\s\S]*?'''|"[^"]*"|'[^']*'|\b\d+\.?\d*\b|[A-Za-z_]\w*\s*(?=\()|[A-Za-z_]\w*|[^\w\s]|\s+)/g
  let m
  while ((m = re.exec(line)) !== null) {
    const val = m[0]
    if (/^("""[\s\S]*?"""|'''[\s\S]*?'''|"[^"]*"|'[^']*')$/.test(val)) {
      tokens.push({ type: 'string', value: val })
    } else if (/^\d+\.?\d*$/.test(val)) {
      tokens.push({ type: 'number', value: val })
    } else if (/^[A-Za-z_]\w*\s*\($/.test(val)) {
      const name = val.replace(/\s*\($/, '')
      tokens.push({ type: 'function', value: name })
      tokens.push({ type: 'plain', value: val.slice(name.length) })
    } else if (KEYWORDS.has(val.trim()) && /^[A-Za-z_]\w*$/.test(val.trim())) {
      tokens.push({ type: 'keyword', value: val })
    } else {
      tokens.push({ type: 'plain', value: val })
    }
  }
  return tokens
}

const TOKEN_CLASSES = {
  keyword:   'tok-keyword',
  string:    'tok-string',
  comment:   'tok-comment',
  number:    'tok-number',
  function:  'tok-function',
  decorator: 'tok-decorator',
  plain:     'tok-plain',
}

export default function CodeBlock({ code = '', language = 'python' }) {
  const [copied, setCopied] = useState(false)

  const handleCopy = () => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }

  const lines = code.split('\n')

  return (
    <div className="codeblock">
      <div className="codeblock__header">
        <span className="codeblock__lang">{language.toUpperCase()}</span>
        <button className="codeblock__copy" onClick={handleCopy}>
          {copied ? 'COPIED ✓' : 'COPY'}
        </button>
      </div>
      <div className="codeblock__body">
        <div className="codeblock__numbers">
          {lines.map((_, i) => (
            <div key={i} className="codeblock__lineno">{i + 1}</div>
          ))}
        </div>
        <pre className="codeblock__code">
          {lines.map((line, i) => {
            const tokens = tokenizeLine(line)
            return (
              <div key={i} className="codeblock__line">
                {tokens.map((tok, j) => (
                  <span key={j} className={TOKEN_CLASSES[tok.type] || 'tok-plain'}>
                    {tok.value}
                  </span>
                ))}
              </div>
            )
          })}
        </pre>
      </div>
    </div>
  )
}
