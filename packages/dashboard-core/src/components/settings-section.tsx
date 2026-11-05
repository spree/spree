import { Card } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'

export interface SettingsSectionProps {
  title: ReactNode
  description?: ReactNode
  /** Sits at the end of the heading row, such as an Add or Edit button. */
  action?: ReactNode
  /** Classes for the card that holds `children`. */
  className?: string
  children: ReactNode
}

/**
 * One block of a settings page: a heading and a line of description above
 * the card that holds its fields. The heading sits outside the card, so a
 * page of several blocks reads as titled sections rather than a stack of
 * boxes each carrying its own title bar.
 */
export function SettingsSection({
  title,
  description,
  action,
  className,
  children,
}: SettingsSectionProps) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-end justify-between gap-4">
        <div className="flex min-w-0 flex-col gap-1">
          <h2 className="font-semibold text-base">{title}</h2>
          {description && <p className="text-muted-foreground text-sm">{description}</p>}
        </div>
        {action && <div className="shrink-0">{action}</div>}
      </div>
      <Card className={className}>{children}</Card>
    </section>
  )
}
