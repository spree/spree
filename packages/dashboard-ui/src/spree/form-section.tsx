import type { ReactNode } from 'react'
import { cn } from '../lib/utils'
import { FieldGroup, FieldLegend, FieldSet } from '../ui/field'

interface FormSectionProps {
  /** Names the group. Rendered as a legend, so it labels the fields inside it
   *  rather than merely preceding them. */
  title?: string
  description?: string
  /** Right-aligned beside the title — an "Add" button, a count, a toggle. */
  action?: ReactNode
  /** `plain` drops the card, for a section set off by dividers inside a sheet. */
  variant?: 'card' | 'plain'
  children: ReactNode
}

/**
 * A titled group of form fields.
 *
 * Built on FieldSet/FieldLegend rather than a heading beside a div: a heading
 * only precedes the inputs, while a legend is announced as the group they
 * belong to — the difference between "Pickup" read once and every control
 * under it being understood as part of pickup.
 */
export function FormSection({
  title,
  description,
  action,
  variant = 'card',
  children,
}: FormSectionProps) {
  const hasHeading = title || description || action

  return (
    <FieldSet
      className={cn(
        'gap-3',
        variant === 'plain' && 'rounded-none border-0 bg-transparent p-0 shadow-none',
      )}
    >
      {hasHeading && (
        <div className="flex items-start justify-between gap-2">
          <div className="flex flex-col gap-0.5">
            {title && (
              <FieldLegend variant="label" className="mb-0">
                {title}
              </FieldLegend>
            )}
            {description && <p className="text-muted-foreground text-xs">{description}</p>}
          </div>
          {action}
        </div>
      )}
      {/* The group paints the card that separates one section from the next.
          Sections are siblings, never nested, so no card ever sits inside
          another. */}
      <FieldGroup>{children}</FieldGroup>
    </FieldSet>
  )
}
