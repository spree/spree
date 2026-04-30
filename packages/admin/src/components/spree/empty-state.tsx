import type { ReactNode } from 'react'

interface EmptyStateProps {
  /** Optional icon (lucide-react icon, sized). Rendered above the title in muted color. */
  icon?: ReactNode
  /** Headline. */
  title: ReactNode
  /** Smaller helper text below the title. */
  description?: ReactNode
  /** Action button(s) — typically a "Create…" CTA. */
  action?: ReactNode
  /** Compact variant for inline use (table rows, cards). Default false. */
  compact?: boolean
}

/**
 * Empty state placeholder. Replaces `_no_resource_found.html.erb` and the
 * inline empty markup currently embedded in `<ResourceTable>`.
 *
 * Use full variant for page-level emptiness ("This store has no products yet"),
 * compact variant for inside cards/tables.
 */
export function EmptyState({ icon, title, description, action, compact = false }: EmptyStateProps) {
  return (
    <div
      className={
        compact
          ? 'flex flex-col items-center justify-center gap-2 py-6 text-center'
          : 'flex flex-col items-center justify-center gap-3 py-16 text-center'
      }
    >
      {icon && <div className="text-muted-foreground [&>svg]:size-8">{icon}</div>}
      <p className={compact ? 'text-sm font-medium' : 'text-base font-medium'}>{title}</p>
      {description && <p className="max-w-md text-sm text-muted-foreground">{description}</p>}
      {action && <div className="mt-2">{action}</div>}
    </div>
  )
}
