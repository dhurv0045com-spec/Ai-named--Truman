import React from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import rehypeHighlight from 'rehype-highlight'
import CodeBlock from './CodeBlock'

export default function Markdown({ content }) {
  if (!content) return null

  return (
    <div className="anra-markdown">
      <ReactMarkdown
        remarkPlugins={[remarkGfm]}
        rehypePlugins={[rehypeHighlight]}
        components={{
          code({ node, inline, className, children, ...props }) {
            const match = /language-(\w+)/.exec(className || '')
            if (!inline && (match || String(children).includes('\n'))) {
              return (
                <CodeBlock
                  code={String(children).replace(/\n$/, '')}
                  language={match ? match[1] : 'text'}
                />
              )
            }
            return <code className={className} {...props}>{children}</code>
          }
        }}
      >
        {content}
      </ReactMarkdown>
    </div>
  )
}
