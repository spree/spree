import { Card, SectionTitle } from '@spree/dashboard-ui'
import type { ReactNode } from 'react'

export interface SettingsSectionProps {
  title: ReactNode
  /** An icon element set in a tile before the title, like a `Section` heading. */
  icon?: ReactNode
  description?: ReactNode
  /** Sits at the end of the heading row, such as an Add or Edit button. */
  action?: ReactNode
  /** Classes for the card that holds `children`. */
  className?: string
  children: ReactNode
}

/**
 * One block of a settings page: a heading above the card that holds its
 * fields, with any description at the top of the card. The heading sits
 * outside the card, so a page of several blocks reads as titled sections
 * rather than a stack of boxes each carrying its own title bar.
 */
export function SettingsSection({
  title,
  icon,
  description,
  action,
  className,
  children,
}: SettingsSectionProps) {
  return (
    <section className="flex flex-col gap-3">
      <div className="flex items-center justify-between gap-4">
        <SectionTitle>
          {icon}
          {title}
        </SectionTitle>
        {action && <div className="shrink-0">{action}</div>}
      </div>
      <Card className={className}>
        {/* Inside the card, as the first line of what it holds. */}
        {description && <p className="px-4 pt-4 text-muted-foreground text-base">{description}</p>}
        {children}
      </Card>
    </section>
  )
}
