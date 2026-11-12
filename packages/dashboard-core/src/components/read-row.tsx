import { cn } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/**
 * One labelled value in a sidebar card: the label on the left, the value on
 * the right, with a placeholder when unset. `stacked` puts a long free-text
 * value (notes, a reason) under its label instead, where right-aligned
 * paragraphs would be hard to read.
 */
export function ReadRow({
  label,
  children,
  stacked = false,
}: {
  label: string
  children: ReactNode
  stacked?: boolean
}) {
  const { t } = useTranslation()
  const value = children ?? (
    <span className="text-muted-foreground">{t('admin.sellers.not_provided')}</span>
  )
  if (stacked) {
    return (
      <div className="flex flex-col gap-1 text-base">
        <span className="text-muted-foreground">{label}</span>
        <span className="whitespace-pre-line">{value}</span>
      </div>
    )
  }
  return (
    <div className={cn('flex items-start justify-between gap-3 text-base')}>
      <span className="shrink-0 text-muted-foreground">{label}</span>
      <span className="min-w-0 text-right">{value}</span>
    </div>
  )
}
