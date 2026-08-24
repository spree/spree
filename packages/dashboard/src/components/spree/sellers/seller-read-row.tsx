import type { ReactNode } from 'react'
import { useTranslation } from 'react-i18next'

/** One labelled value in a sidebar card, with a placeholder when unset. */
export function ReadRow({ label, children }: { label: string; children: ReactNode }) {
  const { t } = useTranslation()
  return (
    <div className="flex items-start justify-between gap-3 text-sm">
      <span className="text-muted-foreground">{label}</span>
      <span className="text-right">
        {children ?? (
          <span className="text-muted-foreground">{t('admin.sellers.not_provided')}</span>
        )}
      </span>
    </div>
  )
}
