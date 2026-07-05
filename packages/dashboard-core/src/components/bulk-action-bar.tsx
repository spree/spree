import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  useConfirm,
} from '@spree/dashboard-ui'
import type { QueryKey } from '@tanstack/react-query'
import { useQueryClient } from '@tanstack/react-query'
import { MoreHorizontalIcon, XIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useEffect, useLayoutEffect, useRef, useState } from 'react'
import { createPortal } from 'react-dom'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { usePermissions } from '../providers/permission-provider'

/**
 * Context handed to a bulk action's `run` and `form` callbacks. `ids` is the
 * set of selected row IDs (prefixed). `formValues` is whatever the action's
 * `form` component resolved with — `undefined` for actions without a form.
 */
export interface BulkActionRunContext<TFormValues = unknown> {
  ids: string[]
  formValues?: TFormValues
}

export interface BulkActionFormProps<TFormValues = unknown> {
  ids: string[]
  onSubmit: (values: TFormValues) => void
  onCancel: () => void
}

/**
 * Declarative bulk action passed to `<ResourceTable>`. Three shapes:
 *
 * 1. Immediate — `run` is called as soon as the button is clicked. Use for
 *    one-click ops that don't need confirmation (rare).
 * 2. Confirm — `confirm` opens the standard confirm dialog before `run`.
 *    Use for destructive or otherwise unambiguous actions.
 * 3. Form — `form` renders a component (usually a Sheet) that collects
 *    parameters and resolves with `formValues` passed to `run`. Use for
 *    parameterised actions like "add tags…" or "move to group…".
 *
 * Visibility is gated by `subject` + action via CanCanCan. Actions without
 * a subject are always shown.
 */
export interface BulkAction<TFormValues = unknown> {
  key: string
  label: string
  icon?: ReactNode
  /** Optional Subject for CanCanCan visibility check. Pairs with `action`. */
  subject?: string
  /** CanCanCan action keyword (default: `'update'`). */
  action?: string
  /** Confirm dialog options. `{n}` in `title`/`message` is replaced by the count. */
  confirm?: {
    title?: string
    message: string
    confirmLabel?: string
    variant?: 'default' | 'destructive'
  }
  /** Render-prop for actions that need to collect form values before running. */
  form?: (props: BulkActionFormProps<TFormValues>) => ReactNode
  /** The mutation. Resolves with anything; errors surface a toast. */
  run: (ctx: BulkActionRunContext<TFormValues>) => Promise<unknown>
  /**
   * Extra query keys to invalidate after `run` succeeds. The table's own
   * `queryKey` is always invalidated — list this when the mutation also
   * affects records in other resources (e.g. assigning customers to a
   * group mutates the customer rows AND every group's `customers_count`).
   */
  invalidate?: QueryKey[]
  /** Toast message on success. Supports `{n}` substitution. */
  successMessage?: string
  /** Toast message on failure. */
  errorMessage?: string
}

interface BulkActionBarProps {
  selectedIds: string[]
  // The bar treats `formValues` opaquely (forwards from `form` to `run`) so it
  // doesn't care what the action's type parameter is. Concrete callers keep
  // the precise type via `BulkAction<MyFormValues>`.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  actions: BulkAction<any>[]
  onClear: () => void
  /** Called after a successful run to refresh the table / clear selection. */
  onDone: () => void
  /**
   * When set, the bar centers itself horizontally inside this element's
   * bounding rect on viewports wide enough to comfortably show it inside
   * (>= +md+ breakpoint). On smaller viewports it falls back to centering
   * against the visual viewport. Without this the bar always anchors to
   * the viewport.
   */
  anchorRef?: React.RefObject<HTMLElement | null>
}

function interpolate(template: string, n: number) {
  return template.replace(/\{n\}/g, String(n))
}

export function BulkActionBar({
  selectedIds,
  actions,
  onClear,
  onDone,
  anchorRef,
}: BulkActionBarProps) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const queryClient = useQueryClient()
  const { permissions } = usePermissions()
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const [pendingForm, setPendingForm] = useState<BulkAction<any> | null>(null)
  const [running, setRunning] = useState(false)

  const count = selectedIds.length

  // The bar unmounts visually when nothing is selected, but state survives
  // across mounts. Drop any pending form sheet so it doesn't resurface when
  // the user re-selects a *different* set of rows.
  useEffect(() => {
    if (count === 0) setPendingForm(null)
  }, [count])

  if (count === 0) return null

  // Filter by CanCanCan when subject is declared.
  const visibleActions = actions.filter((a) =>
    a.subject ? permissions.can(a.action ?? 'update', a.subject) : true,
  )

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  async function execute(action: BulkAction<any>, formValues?: unknown) {
    setRunning(true)
    try {
      await action.run({ ids: selectedIds, formValues })
      // Invalidate the action's declared cross-resource keys BEFORE `onDone`
      // (which invalidates the host table's own key). Without this, pages
      // like Customer Groups that cache `customers_count` won't refresh
      // when the user navigates back — they'd show stale counts until
      // either `staleTime` elapses or the user reloads.
      for (const key of action.invalidate ?? []) {
        queryClient.invalidateQueries({ queryKey: key })
      }
      toast.success(
        interpolate(
          action.successMessage ?? t('admin.components.bulk_action_bar.default_success'),
          count,
        ),
      )
      onDone()
    } catch (err) {
      const message =
        err instanceof Error ? err.message : t('admin.components.bulk_action_bar.default_error')
      toast.error(action.errorMessage ?? message)
    } finally {
      setRunning(false)
    }
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  async function handleClick(action: BulkAction<any>) {
    if (action.form) {
      setPendingForm(action)
      return
    }
    if (action.confirm) {
      const ok = await confirm({
        title: action.confirm.title ? interpolate(action.confirm.title, count) : undefined,
        message: interpolate(action.confirm.message, count),
        confirmLabel: action.confirm.confirmLabel,
        variant: action.confirm.variant,
      })
      if (!ok) return
    }
    await execute(action)
  }

  return (
    <BulkActionBarLayout
      count={count}
      actions={visibleActions}
      anchorRef={anchorRef}
      onClear={onClear}
      onClickAction={handleClick}
      running={running}
      pendingForm={pendingForm}
      selectedIds={selectedIds}
      onClosePendingForm={() => setPendingForm(null)}
      onSubmitPendingForm={async (values) => {
        const action = pendingForm
        if (!action) return
        setPendingForm(null)
        await execute(action, values)
      }}
    />
  )
}

interface BulkActionBarLayoutProps {
  count: number
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  actions: BulkAction<any>[]
  anchorRef?: React.RefObject<HTMLElement | null>
  onClear: () => void
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  onClickAction: (action: BulkAction<any>) => void
  running: boolean
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  pendingForm: BulkAction<any> | null
  selectedIds: string[]
  onClosePendingForm: () => void
  onSubmitPendingForm: (values: unknown) => void
}

/**
 * Splits the action list into "fits in the bar" + "overflow menu" based on
 * the bar's actual rendered width.
 *
 * Why a separate component: hoisting the measurement effects + refs out of
 * +BulkActionBar+ keeps the action-running logic readable and confines
 * resize-observer setup to one place.
 */
function BulkActionBarLayout({
  count,
  actions,
  anchorRef,
  onClear,
  onClickAction,
  running,
  pendingForm,
  selectedIds,
  onClosePendingForm,
  onSubmitPendingForm,
}: BulkActionBarLayoutProps) {
  const { t } = useTranslation()

  // The bar is centered (+w-fit+) so the parent doesn't constrain it; instead
  // we cap against the viewport with a sensible margin.
  const containerRef = useRef<HTMLDivElement | null>(null)
  const measureRef = useRef<HTMLDivElement | null>(null)
  // Width of the bar's leading section (clear button + label + divider).
  const leadingRef = useRef<HTMLDivElement | null>(null)
  const [visibleCount, setVisibleCount] = useState(actions.length)
  // JS-computed position so it's immune to transformed ancestors.
  const [barLeft, setBarLeft] = useState(0)
  const [barTop, setBarTop] = useState(0)

  // Max-width state so the bar never extends past its host region (the
  // table card on desktop, the visual viewport on mobile).
  const [maxWidth, setMaxWidth] = useState<number | null>(null)

  // Reposition + remeasure on viewport resize, scroll, and font load.
  useLayoutEffect(() => {
    function reposition() {
      const el = containerRef.current
      if (!el) return
      const width = el.offsetWidth
      const height = el.offsetHeight
      // visualViewport accounts for the mobile browser URL bar collapsing;
      // falls back to window dimensions on browsers without the API.
      const vv = window.visualViewport
      const vpWidth = vv?.width ?? window.innerWidth
      const vpHeight = vv?.height ?? window.innerHeight
      const vpLeft = vv?.offsetLeft ?? 0
      const vpTop = vv?.offsetTop ?? 0

      // Pin to viewport bottom. The bar should always stay reachable —
      // anchoring to the table card pinned it to the table's bottom, which
      // sits off-screen when the table is taller than the viewport.
      let left = vpLeft + Math.round((vpWidth - width) / 2)
      // Cap width at viewport - 2rem on mobile.
      let cap = vpWidth - 32
      // If an anchor element is provided, clamp the horizontal center AND
      // the max width to the anchor's bounding rect, so on desktop the bar
      // reads as part of the table region rather than free-floating across
      // the whole page.
      const anchor = anchorRef?.current
      if (anchor && vpWidth >= 768) {
        const rect = anchor.getBoundingClientRect()
        left = rect.left + Math.round((rect.width - width) / 2)
        cap = Math.round(rect.width * 0.9) // 90% of the table card width
      }
      setBarLeft(left)
      setBarTop(vpTop + vpHeight - height - 16) // 16px from bottom
      setMaxWidth(cap)
    }
    reposition()
    window.addEventListener('resize', reposition)
    window.addEventListener('scroll', reposition, true)
    window.visualViewport?.addEventListener('resize', reposition)
    window.visualViewport?.addEventListener('scroll', reposition)
    // Track the anchor's own size/position changes (sidebar collapse,
    // pagination footer height swaps, etc.).
    let ro: ResizeObserver | undefined
    if (anchorRef?.current) {
      ro = new ResizeObserver(reposition)
      ro.observe(anchorRef.current)
    }
    return () => {
      window.removeEventListener('resize', reposition)
      window.removeEventListener('scroll', reposition, true)
      window.visualViewport?.removeEventListener('resize', reposition)
      window.visualViewport?.removeEventListener('scroll', reposition)
      ro?.disconnect()
    }
    // Re-run when the anchor element resolves (refs are null on first render
    // and populated on the next commit). The +ResizeObserver+ + window
    // listeners re-attach to whatever anchor the consumer passed.
  }, [anchorRef?.current])

  // Measure once on mount + whenever the container or action set changes.
  // +useLayoutEffect+ so the user never sees a flash of overflowing actions.
  useLayoutEffect(() => {
    function recompute() {
      const measure = measureRef.current
      const leading = leadingRef.current
      if (!measure || !leading) return

      // Compute available action-area width against the same cap that the
      // bar's +max-width+ uses (table card width on desktop, viewport on
      // mobile) so the overflow count matches what the user will see.
      const anchor = anchorRef?.current
      const vpWidth = document.documentElement.clientWidth
      const cap =
        anchor && vpWidth >= 768
          ? Math.round(anchor.getBoundingClientRect().width * 0.9)
          : vpWidth - 32
      // 16px for the bar's own +p-1+ + border + subpixel safety pad.
      const available = cap - 16 - leading.offsetWidth
      // +⋯+ button (icon-sm = 28px) + gap on each side + safety margin.
      // 64px keeps the dropdown comfortably visible on narrow viewports
      // and gives the menu room to position without spilling off-screen.
      const moreWidth = 64
      const children = Array.from(measure.children) as HTMLElement[]
      const widths = children.map((el) => el.offsetWidth)

      let used = 0
      let n = 0
      for (let i = 0; i < widths.length; i++) {
        // If this is the last action and the rest fit without +⋯+, take all.
        const reserve = i === widths.length - 1 ? 0 : moreWidth
        if (used + widths[i] + reserve <= available) {
          used += widths[i]
          n = i + 1
        } else {
          break
        }
      }
      setVisibleCount(n)
    }

    recompute()
    const ro = new ResizeObserver(recompute)
    if (containerRef.current) ro.observe(containerRef.current)
    if (anchorRef?.current) ro.observe(anchorRef.current)
    window.addEventListener('resize', recompute)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', recompute)
    }
    // Re-run only when the anchor element resolves (refs are null on first
    // render and populated on commit). Changes to +actions+ don't need an
    // explicit dep — the +ResizeObserver+ on the container fires when
    // children render/unrender, which re-triggers +recompute+.
  }, [anchorRef?.current])

  const visible = actions.slice(0, visibleCount)
  const overflow = actions.slice(visibleCount)

  // JS-driven positioning: +position: fixed+ silently re-anchors to a
  // transformed/contained ancestor (sidebar wrapper, Card, etc.) on this
  // app. Portaling to +document.body+ should sidestep that, but in
  // practice the bar still landed at the table's bottom on mobile. So we
  // set explicit +top/left+ in pixels from +window+ measurements every
  // frame the viewport changes. No CSS positioning, no ambiguity.
  const bar = (
    <>
      <div
        ref={containerRef}
        style={{
          position: 'fixed',
          left: `${barLeft}px`,
          top: `${barTop}px`,
          maxWidth: maxWidth != null ? `${maxWidth}px` : 'calc(100vw - 2rem)',
        }}
        className="z-50 flex w-fit items-center gap-0.5 rounded-xl border bg-popover p-1 shadow-md"
      >
        <div ref={leadingRef} className="flex items-center gap-0.5">
          <Button
            type="button"
            variant="ghost"
            size="icon-sm"
            onClick={onClear}
            aria-label={t('admin.actions.clear')}
            className="text-muted-foreground"
          >
            <XIcon className="size-4" />
          </Button>
          <span className="whitespace-nowrap px-1.5 text-sm">
            {t('admin.components.bulk_action_bar.selected', { count })}
          </span>
          <div className="mx-1 h-5 w-px bg-border" aria-hidden />
        </div>

        {visible.map((action) => (
          <BulkActionButton
            key={action.key}
            action={action}
            disabled={running}
            onClick={() => onClickAction(action)}
          />
        ))}

        {overflow.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button
                type="button"
                variant="ghost"
                size="icon-sm"
                aria-label={t('admin.actions.more_actions')}
              >
                <MoreHorizontalIcon className="size-4" />
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end">
              {overflow.map((action) => (
                <DropdownMenuItem
                  key={action.key}
                  onClick={() => onClickAction(action)}
                  disabled={running}
                  className="py-1.5"
                >
                  {action.icon}
                  {action.label}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )}

        {/* Off-screen measuring layer: rendered with the same button styling
            as the visible row so +offsetWidth+ reflects the real width.
            +aria-hidden+ + +inert+-equivalent (no pointer events, no focus). */}
        <div
          ref={measureRef}
          aria-hidden
          className="pointer-events-none invisible absolute left-0 top-0 flex items-center gap-0.5"
        >
          {actions.map((action) => (
            <BulkActionButton
              key={action.key}
              action={action}
              disabled
              onClick={() => undefined}
              tabIndex={-1}
            />
          ))}
        </div>
      </div>
      {pendingForm?.form?.({
        ids: selectedIds,
        onCancel: onClosePendingForm,
        onSubmit: onSubmitPendingForm,
      })}
    </>
  )

  if (typeof document === 'undefined') return bar
  return createPortal(bar, document.body)
}

function BulkActionButton({
  action,
  disabled,
  onClick,
  tabIndex,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  action: BulkAction<any>
  disabled: boolean
  onClick: () => void
  tabIndex?: number
}) {
  return (
    <Button
      type="button"
      variant="ghost"
      size="sm"
      onClick={onClick}
      disabled={disabled}
      tabIndex={tabIndex}
      className="gap-1.5 whitespace-nowrap px-2"
    >
      {action.icon}
      {action.label}
    </Button>
  )
}
