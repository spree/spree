import { useStore } from '@spree/dashboard-core'
import { useNavigate } from '@tanstack/react-router'
import type { ReactNode } from 'react'

/**
 * Renders the light markdown an assistant reply actually contains.
 *
 * Deliberately not a full markdown engine: replies here are short prose, and
 * the panel already renders records, tool activity and approvals as their own
 * components — so headings, tables and images have nothing to do. This covers
 * what a model emits in a sentence (bold, inline code, links, bullets) and
 * shows anything else as the plain text it is, which is what the previous
 * `whitespace-pre-wrap` did for everything.
 *
 * Dashboard paths become real router links, so an answer that names a record
 * is clickable in the same way the record rows are.
 */
export function AssistantMarkdown({ text }: { text: string }) {
  const blocks = text.trim().split(/\n{2,}/)

  return (
    <div className="max-w-[85%] space-y-2 text-sm">
      {blocks.map((block, blockIndex) => {
        const lines = block.split('\n')
        const isList = lines.every((line) => /^\s*([-*+]|\d+\.)\s+/.test(line))

        if (isList) {
          return (
            // biome-ignore lint/suspicious/noArrayIndexKey: blocks are positional and never reordered
            <ul key={blockIndex} className="list-disc space-y-1 ps-5">
              {lines.map((line, lineIndex) => (
                // biome-ignore lint/suspicious/noArrayIndexKey: as above
                <li key={lineIndex}>{renderInline(line.replace(/^\s*([-*+]|\d+\.)\s+/, ''))}</li>
              ))}
            </ul>
          )
        }

        return (
          // biome-ignore lint/suspicious/noArrayIndexKey: as above
          <p key={blockIndex} className="whitespace-pre-wrap">
            {renderInline(block)}
          </p>
        )
      })}
    </div>
  )
}

// Bold, inline code, and markdown links — split in one pass so the pieces
// cannot overlap.
const INLINE = /(\*\*[^*]+\*\*|`[^`]+`|\[[^\]]+\]\([^)]+\))/g

function renderInline(text: string): ReactNode[] {
  return text.split(INLINE).filter(Boolean).map(renderToken)
}

function renderToken(token: string, index: number): ReactNode {
  if (token.startsWith('**') && token.endsWith('**')) {
    return <strong key={index}>{token.slice(2, -2)}</strong>
  }

  if (token.startsWith('`') && token.endsWith('`')) {
    return (
      <code key={index} className="rounded bg-muted px-1 py-0.5 font-mono text-xs">
        {token.slice(1, -1)}
      </code>
    )
  }

  const link = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(token)
  if (link) {
    return <MarkdownLink key={index} label={link[1]} href={link[2]} />
  }

  return token
}

/**
 * A dashboard path routes in-app; anything else opens externally. An assistant
 * cannot be trusted to only ever produce internal links, so an off-site URL is
 * treated as untrusted and opened in a new tab without referrer.
 */
function MarkdownLink({ label, href }: { label: string; href: string }) {
  const { storeId } = useStore()
  const navigate = useNavigate()

  if (href.startsWith('/')) {
    // `navigate` rather than `<Link to>`: the path is built at runtime from
    // model output, which the router's literal route union cannot type.
    return (
      <button
        type="button"
        onClick={() => navigate({ to: `/${storeId}${href}` })}
        className="underline underline-offset-2"
      >
        {label}
      </button>
    )
  }

  return (
    <a
      href={href}
      target="_blank"
      rel="noreferrer noopener"
      className="underline underline-offset-2"
    >
      {label}
    </a>
  )
}
