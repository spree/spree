import { cva, type VariantProps } from 'class-variance-authority'
import type * as React from 'react'
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
          'border-border bg-card/50 text-foreground/75 [a]:hover:bg-muted [a]:hover:text-muted-foreground',
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

/**
 * Semantic tone of a status, independent of how it is drawn. `StatusBadge`
 * renders it as a coloured dot, `Badge` as a tinted pill — same vocabulary,
 * two presentations.
 */
type StatusTone = 'success' | 'warning' | 'destructive' | 'info' | 'neutral'

/**
 * Maps an order/payment/product status code to its semantic tone.
 *
 * Kept as one table because the same codes surface in tables, cards, page
 * headers and filter menus — a local copy in any one of those is how two
 * surfaces end up disagreeing about what "pending" looks like. Extend it
 * rather than branching on status at a call site.
 */
const statusToneMap: Record<string, StatusTone> = {
  active: 'success',
  authorized: 'info',
  complete: 'success',
  completed: 'success',
  paid: 'success',
  fulfilled: 'success',
  delivered: 'success',
  unfulfilled: 'warning',
  proposed: 'warning',
  published: 'success',
  approved: 'success',
  verified: 'success',
  unverified: 'destructive',
  unavailable: 'neutral',
  unsupported: 'neutral',
  revoked: 'destructive',
  expired: 'destructive',
  ready: 'warning',
  available: 'success',
  draft: 'neutral',
  pending: 'warning',
  processing: 'warning',
  inactive: 'neutral',
  confirm: 'neutral',
  resumed: 'neutral',
  partial: 'info',
  // What a carrier reports about a consignment in flight. `pending` and
  // `delivered` are already above — they mean the same thing here.
  pre_transit: 'info',
  in_transit: 'info',
  out_for_delivery: 'info',
  available_for_pickup: 'warning',
  return_to_sender: 'destructive',
  failure: 'destructive',
  unknown: 'neutral',
  archived: 'neutral',
  returned: 'success',
  backorder: 'warning',
  balance_due: 'warning',
  credit_owed: 'warning',
  canceled: 'destructive',
  suspended: 'destructive',
  invited: 'info',
  onboarding: 'warning',
  incomplete: 'neutral',
  ready_for_review: 'warning',
  failed: 'destructive',
  void: 'destructive',
  error: 'destructive',
  rejected: 'destructive',
  used_up: 'destructive',
  // Returns, exchanges and claims: amber while the merchant still owes an
  // action, green once settled, muted when it went nowhere.
  requested: 'warning',
  open: 'warning',
  received: 'warning',
  refunded: 'success',
  resolved: 'success',
  denied: 'destructive',
  // Gift cards.
  partially_redeemed: 'info',
  redeemed: 'neutral',
  // Price lists — `scheduled` is live-but-not-yet, which is the same shape as
  // any other "waiting on the clock" state.
  scheduled: 'info',
  // Boolean filter values. A yes/no pair is a state like any other — "in
  // stock: no" is the row an operator is looking for, and reading it in the
  // same green/red the rest of the app uses saves them parsing the word.
  true: 'success',
  false: 'destructive',
}

// Dot fills, by tone. These read the same `--status-*` ramps the tinted Badge
// variants use, but take the *reading* step rather than the fill step: a 6px
// dot needs the saturated end of the ramp to register at all, where a pill can
// rely on area.
const dotToneClasses: Record<StatusTone, string> = {
  success: 'bg-success',
  warning: 'bg-warning',
  destructive: 'bg-danger',
  info: 'bg-info',
  neutral: 'bg-muted-foreground/50',
}

/**
 * Bare status dot. Decorative by construction — it carries no accessible name,
 * so it must always sit beside text that says the same thing. Use it to align
 * a status with its label in a menu or list; use `StatusBadge` when you want
 * the dot and its label together.
 */
function StatusDot({ status, className }: { status: string; className?: string }) {
  const tone = statusToneMap[status] ?? 'neutral'
  return (
    <span
      aria-hidden
      className={cn('inline-block size-1.5 shrink-0 rounded-full', dotToneClasses[tone], className)}
    />
  )
}

/**
 * Status indicator: a coloured dot beside the label, rather than a tinted pill.
 *
 * A table column of pills reads as a column of coloured blocks — the eye lands
 * on the fills instead of the words, and a row where three statuses sit side by
 * side becomes a bar chart of nothing. A dot puts the colour where it belongs:
 * a small mark that the label does the talking for. Colour is never the only
 * channel, since the label is always rendered.
 *
 * Stays headless: pass a translated `label` from the app layer; without one it
 * humanizes the code itself (`balance_due` → `balance due`) as a best-effort
 * fallback.
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
  return (
    <span
      data-slot="status-badge"
      data-status={status}
      className={cn(
        'inline-flex w-fit shrink-0 items-center gap-1.5 whitespace-nowrap text-sm capitalize',
        className,
      )}
    >
      <StatusDot status={status} />
      {label ?? status.replace(/_/g, ' ')}
    </span>
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
  if (dashWhenInactive && !active) {
    return <span className={cn('text-muted-foreground', className)}>—</span>
  }
  // Boolean states read through the same map as every other status, so an
  // "Active / Inactive" column and a "Paid / Failed" one agree on what green
  // and red mean. The tick the active case used to carry is redundant beside
  // a dot that already says the same thing.
  return (
    <StatusBadge
      status={active ? 'true' : 'false'}
      label={active ? resolvedActiveLabel : resolvedInactiveLabel}
      className={className}
    />
  )
}

export type { StatusTone }
export { ActiveBadge, Badge, badgeVariants, StatusBadge, StatusDot, statusToneMap }
