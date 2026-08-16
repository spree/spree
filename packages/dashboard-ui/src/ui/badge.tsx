import { cva, type VariantProps } from 'class-variance-authority'
import { CheckIcon } from 'lucide-react'
import * as React from 'react'
import { useTranslation } from 'react-i18next'
import { cn } from '../lib/utils'
import { Slot } from './slot'

const badgeVariants = cva(
  // No `border-transparent` here: it and a variant's `border-*` have the same
  // specificity, so the one Tailwind emits last wins regardless of the order
  // they appear in the class list — which silently erased the outline
  // variant's border. Each variant states its own border colour instead.
  'group/badge inline-flex h-5 w-fit shrink-0 items-center justify-center gap-1 overflow-hidden rounded-4xl border px-2 py-0.5 text-xs font-medium whitespace-nowrap transition-[color,background-color,border-color,box-shadow] duration-100 ease-out focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 aria-invalid:border-destructive aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 [&>svg]:pointer-events-none [&>svg]:size-3!',
  {
    variants: {
      variant: {
        default: 'border-transparent bg-primary text-primary-foreground [a]:hover:bg-primary/80',
        secondary:
          'border-transparent bg-secondary text-secondary-foreground [a]:hover:bg-secondary/80',
        // The four status variants below share one recipe: a tint from the
        // status ramp, text from the same ramp's reading step, and a border
        // that firms the shape up on busy surfaces. Both themes get real
        // colours rather than one hue at reduced opacity — an opacity tint
        // takes on whatever sits behind it, which turns a badge muddy over a
        // striped table row and washes it out entirely on a dark card. Linked
        // badges darken to the border step on hover, which is the next stop up
        // the same ramp rather than a second colour.
        destructive:
          'border-danger-border bg-danger-bg text-danger focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 [a]:hover:bg-danger-border',
        success: 'border-success-border bg-success-bg text-success [a]:hover:bg-success-border',
        info: 'border-info-border bg-info-bg text-info [a]:hover:bg-info-border',
        warning: 'border-warning-border bg-warning-bg text-warning [a]:hover:bg-warning-border',
        outline:
          'border-border text-foreground/75 [a]:hover:bg-muted [a]:hover:text-muted-foreground',
        ghost:
          'border-transparent hover:bg-muted hover:text-muted-foreground dark:hover:bg-muted/50',
        link: 'border-transparent text-primary underline-offset-4 hover:underline',
      },
    },
    defaultVariants: {
      variant: 'default',
    },
  },
)

function Badge({
  className,
  variant = 'default',
  asChild = false,
  ...props
}: React.ComponentProps<'span'> & VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
  const Comp = asChild ? Slot : 'span'

  return (
    <Comp
      data-slot="badge"
      data-variant={variant}
      className={cn(badgeVariants({ variant }), className)}
      {...props}
    />
  )
}

// Maps order/payment/etc. status strings to one of the canonical Badge
// variants. Success-y states ("active", "paid", "shipped", …) route through
// the `success` variant so the UI stays color-coded; everything else leans
// on the canonical shadcn variants with shape + label carrying meaning.
const statusVariantMap: Record<string, VariantProps<typeof badgeVariants>['variant']> = {
  active: 'success',
  authorized: 'info',
  complete: 'success',
  completed: 'success',
  paid: 'success',
  fulfilled: 'success',
  delivered: 'success',
  unfulfilled: 'warning',
  published: 'success',
  approved: 'success',
  verified: 'success',
  unverified: 'destructive',
  unavailable: 'secondary',
  unsupported: 'secondary',
  revoked: 'destructive',
  expired: 'destructive',
  ready: 'warning',
  draft: 'outline',
  pending: 'warning',
  processing: 'warning',
  inactive: 'secondary',
  confirm: 'outline',
  resumed: 'secondary',
  partial: 'info',
  archived: 'secondary',
  returned: 'success',
  backorder: 'warning',
  balance_due: 'warning',
  credit_owed: 'warning',
  canceled: 'destructive',
  suspended: 'destructive',
  invited: 'info',
  onboarding: 'warning',
  ready_for_review: 'warning',
  failed: 'destructive',
  void: 'destructive',
  error: 'destructive',
  rejected: 'destructive',
}

/**
 * Status pill whose color is derived from the raw status code. Stays headless:
 * pass a translated `label` from the app layer; without one it humanizes the
 * code itself (`balance_due` → `balance due`) as a best-effort fallback.
 */
function StatusBadge({
  status,
  label,
  className,
}: {
  status: string
  label?: string
  className?: string
}) {
  const variant = statusVariantMap[status] ?? 'outline'
  return (
    <Badge variant={variant} className={cn('capitalize', className)}>
      {label ?? status.replace(/_/g, ' ')}
    </Badge>
  )
}

/**
 * Boolean-state badge — mirrors the Rails admin's `active_badge` helper.
 *
 * Renders a `success` (check + label) badge when `active`, an `outline`
 * badge with the inactive label otherwise. Use it for "Yes/No" or
 * "Enabled/Disabled" cells in tables and detail rows.
 *
 * @example  Default Yes/No
 *   <ActiveBadge active={user.confirmed} />
 *
 * @example  Custom labels
 *   <ActiveBadge active={sl.pickup_enabled} activeLabel="Enabled" inactiveLabel="Disabled" />
 *
 * @example  Hide inactive (renders a muted dash instead — matches the
 *   pre-existing `<Badge> : <span>—</span>` pattern in stock-locations).
 *   <ActiveBadge active={sl.pickup_enabled} activeLabel="Enabled" dashWhenInactive />
 */
function ActiveBadge({
  active,
  activeLabel,
  inactiveLabel,
  dashWhenInactive = false,
  className,
}: {
  active: boolean | null | undefined
  activeLabel?: string
  inactiveLabel?: string
  dashWhenInactive?: boolean
  className?: string
}) {
  const { t } = useTranslation()
  const resolvedActiveLabel = activeLabel ?? t('admin.common.yes')
  const resolvedInactiveLabel = inactiveLabel ?? t('admin.common.no')
  if (active) {
    return (
      <Badge variant="success" className={className}>
        <CheckIcon />
        {resolvedActiveLabel}
      </Badge>
    )
  }
  if (dashWhenInactive) {
    return <span className={cn('text-muted-foreground', className)}>—</span>
  }
  return (
    <Badge variant="outline" className={className}>
      {resolvedInactiveLabel}
    </Badge>
  )
}

export { ActiveBadge, Badge, badgeVariants, StatusBadge }
