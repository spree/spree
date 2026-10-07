import { cn } from '@spree/dashboard-ui'
import { useMemo, useRef } from 'react'
import { useTranslation } from 'react-i18next'

export type EmailPreviewWidth = 'desktop' | 'mobile'

/**
 * A rendered email in a sandboxed frame: no scripts, no navigation, nothing
 * the email's markup can reach in the dashboard.
 *
 * Each render gets a new frame. Changing a loaded frame's document adds an
 * entry to the page's history, so with live previews the browser's Back went
 * through every past render before leaving the page.
 */
export function EmailPreviewFrame({
  html,
  text,
  view = 'html',
  width = 'desktop',
  className,
}: {
  html?: string
  text?: string
  view?: 'html' | 'text'
  width?: EmailPreviewWidth
  className?: string
}) {
  const { t } = useTranslation()
  const renders = useRef(0)
  // biome-ignore lint/correctness/useExhaustiveDependencies: a new key for every new document
  const frameKey = useMemo(() => ++renders.current, [html])

  if (view === 'text') {
    return (
      <pre
        className={cn(
          'h-full min-h-96 overflow-auto whitespace-pre-wrap rounded-md border border-border bg-card p-4 font-mono text-xs',
          className,
        )}
      >
        {text}
      </pre>
    )
  }

  return (
    <div
      className={cn(
        'flex h-full min-h-96 justify-center rounded-md border border-border bg-muted p-2',
        className,
      )}
    >
      <iframe
        key={frameKey}
        title={t('admin.email_templates.preview.frame_title')}
        sandbox=""
        srcDoc={html ?? ''}
        className={cn(
          'h-full min-h-96 rounded bg-white transition-[width] duration-150',
          width === 'mobile' ? 'w-[375px]' : 'w-full',
        )}
      />
    </div>
  )
}
