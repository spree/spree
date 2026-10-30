import DOMPurify from 'dompurify'
import { useMemo } from 'react'

// Styles the HTML GitHub renders as the dashboard's own text.
const PROSE = [
  'min-w-0 break-words text-sm [&>:first-child]:mt-0',
  '[&_h3]:mt-6 [&_h3]:mb-2 [&_h3]:font-semibold [&_h3]:text-base',
  '[&_h4]:mt-4 [&_h4]:mb-1 [&_h4]:font-semibold [&_h4]:text-sm',
  '[&_p]:my-2 [&_p]:leading-relaxed [&_hr]:my-4',
  '[&_ul]:my-2 [&_ul]:list-disc [&_ul]:space-y-1 [&_ul]:ps-5',
  '[&_ol]:my-2 [&_ol]:list-decimal [&_ol]:space-y-1 [&_ol]:ps-5',
  '[&_a]:font-medium [&_a]:underline [&_a]:underline-offset-3 [&_a:hover]:text-foreground',
  '[&_img]:my-3 [&_img]:h-auto [&_img]:max-w-full [&_img]:rounded-md [&_img]:border',
  '[&_code]:rounded [&_code]:bg-muted [&_code]:px-1 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-xs',
  '[&_pre]:my-3 [&_pre]:overflow-x-auto [&_pre]:rounded-md [&_pre]:bg-muted [&_pre]:p-3 [&_pre]:font-mono [&_pre]:text-xs',
  '[&_pre_code]:bg-transparent [&_pre_code]:p-0',
  '[&_table]:my-3 [&_th]:pe-4 [&_th]:text-start [&_th]:font-medium [&_td]:pe-4 [&_td]:py-0.5',
].join(' ')

// The notes sit under the notification's own h3, so their headings move down
// to keep the page outline in order: h1 and h2 become h3, h3 becomes h4.
const HEADING_LEVEL: Record<string, string> = { 1: '3', 2: '3', 3: '4', 4: '5', 5: '6', 6: '6' }

let purifier: ReturnType<typeof DOMPurify> | undefined

// GitHub already sanitizes the notes it renders. They are sanitized again here
// so nothing a release author writes can run script in the dashboard.
function sanitize(html: string): string {
  if (!purifier) {
    purifier = DOMPurify(window)
    purifier.addHook('afterSanitizeAttributes', (node) => {
      if (node.tagName === 'A') {
        node.setAttribute('target', '_blank')
        node.setAttribute('rel', 'noopener noreferrer')
      }
      if (node.tagName === 'IMG') node.setAttribute('loading', 'lazy')
    })
  }
  const clean = purifier.sanitize(html, {
    FORBID_TAGS: ['style', 'form', 'input', 'button', 'select', 'textarea'],
    FORBID_ATTR: ['style'],
  })
  // Safe on sanitized output: a literal "<" outside a tag is escaped as "&lt;".
  return clean.replace(
    /<(\/?)h([1-6])\b/g,
    (_, slash, level) => `<${slash}h${HEADING_LEVEL[level]}`,
  )
}

/** Release notes from GitHub, rendered as the dashboard's own text. */
export function ReleaseNotes({ html }: { html: string }) {
  const clean = useMemo(() => sanitize(html), [html])

  // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized by DOMPurify above
  return <div className={PROSE} dangerouslySetInnerHTML={{ __html: clean }} />
}
