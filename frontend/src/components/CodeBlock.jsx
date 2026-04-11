import React, { useState, useRef, useEffect } from 'react'
import hljs from 'highlight.js/lib/core'
import python from 'highlight.js/lib/languages/python'
import javascript from 'highlight.js/lib/languages/javascript'
import typescript from 'highlight.js/lib/languages/typescript'
import bash from 'highlight.js/lib/languages/bash'
import json from 'highlight.js/lib/languages/json'
import sql from 'highlight.js/lib/languages/sql'
import css from 'highlight.js/lib/languages/css'
import xml from 'highlight.js/lib/languages/xml'
import rust from 'highlight.js/lib/languages/rust'
import go from 'highlight.js/lib/languages/go'
import yaml from 'highlight.js/lib/languages/yaml'

hljs.registerLanguage('python', python)
hljs.registerLanguage('javascript', javascript)
hljs.registerLanguage('js', javascript)
hljs.registerLanguage('typescript', typescript)
hljs.registerLanguage('ts', typescript)
hljs.registerLanguage('bash', bash)
hljs.registerLanguage('shell', bash)
hljs.registerLanguage('json', json)
hljs.registerLanguage('sql', sql)
hljs.registerLanguage('css', css)
hljs.registerLanguage('html', xml)
hljs.registerLanguage('xml', xml)
hljs.registerLanguage('rust', rust)
hljs.registerLanguage('go', go)
hljs.registerLanguage('yaml', yaml)

export default function CodeBlock({ code = '', language = 'text' }) {
  const [copied, setCopied] = useState(false)
  const codeRef = useRef(null)

  useEffect(() => {
    if (codeRef.current) {
      try {
        if (language && language !== 'text' && hljs.getLanguage(language)) {
          const result = hljs.highlight(code, { language })
          codeRef.current.innerHTML = result.value
        } else {
          const result = hljs.highlightAuto(code)
          codeRef.current.innerHTML = result.value
        }
      } catch {
        codeRef.current.textContent = code
      }
    }
  }, [code, language])

  const handleCopy = () => {
    navigator.clipboard.writeText(code).then(() => {
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    })
  }

  return (
    <div className="codeblock">
      <div className="codeblock__header">
        <span className="codeblock__lang">{language.toUpperCase()}</span>
        <button
          className={`codeblock__copy${copied ? ' codeblock__copy--copied' : ''}`}
          onClick={handleCopy}
        >
          {copied ? 'COPIED ✓' : 'COPY'}
        </button>
      </div>
      <div className="codeblock__body">
        <pre><code ref={codeRef}>{code}</code></pre>
      </div>
    </div>
  )
}
