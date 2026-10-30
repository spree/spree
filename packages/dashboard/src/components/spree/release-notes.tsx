import DOMPurify from 'dompurify'
import { useMemo } from 'react'

// Styles the HTML GitHub renders as the dashboard's own text. Headings are a
// step smaller because they sit under the notification's own heading.
const PROSE = [
  'min-w-0 break-words text-sm [&>:first-child]:mt-0',
  '[&_h1]:mt-6 [&_h1]:mb-2 [&_h1]:font-semibold [&_h1]:text-base',
  '[&_h2]:mt-6 [&_h2]:mb-2 [&_h2]:font-semibold [&_h2]:text-base',
  '[&_h3]:mt-4 [&_h3]:mb-1 [&_h3]:font-semibold [&_h3]:text-sm',
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
  return purifier.sanitize(html, { FORBID_ATTR: ['style'] })
}

/** Release notes from GitHub, rendered as the dashboard's own text. */
export function ReleaseNotes({ html }: { html: string }) {
  const clean = useMemo(() => sanitize(html), [html])

  // biome-ignore lint/security/noDangerouslySetInnerHtml: sanitized by DOMPurify above
  return <div className={PROSE} dangerouslySetInnerHTML={{ __html: clean }} />
}
