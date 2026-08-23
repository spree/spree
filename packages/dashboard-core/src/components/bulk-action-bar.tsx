import {
  Button,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import type { QueryKey } from '@tanstack/react-query'
import { useQueryClient } from '@tanstack/react-query'
import { MoreHorizontalIcon } from 'lucide-react'
import type { ReactNode } from 'react'
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
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
  /** Called after a successful run to refresh the table / clear selection. */
  onDone: () => void
}

function interpolate(template: string, n: number) {
  return template.replace(/\{n\}/g, String(n))
}

export function BulkActionBar({ selectedIds, actions, onDone }: BulkActionBarProps) {
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

  // Filter by CanCanCan when subject is declared. Memoized so the layout below
  // can treat a change here as a real change: it re-measures the overflow
  // whenever the action set does, and a fresh array every render would make
  // that run on every render instead. Must stay above the early return —
  // hooks cannot be called conditionally.
  const visibleActions = useMemo(
    () =>
      actions.filter((a) => (a.subject ? permissions.can(a.action ?? 'update', a.subject) : true)),
    [actions, permissions],
  )

  if (count === 0) return null

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
      toastManager.add({
        type: 'success',
        title: interpolate(
          action.successMessage ?? t('admin.components.bulk_action_bar.default_success'),
          count,
        ),
      })
      onDone()
    } catch (err) {
      const message =
        err instanceof Error ? err.message : t('admin.components.bulk_action_bar.default_error')
      toastManager.add({ type: 'error', title: action.errorMessage ?? message })
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
  onClickAction,
  running,
  pendingForm,
  selectedIds,
  onClosePendingForm,
  onSubmitPendingForm,
}: BulkActionBarLayoutProps) {
  const { t } = useTranslation()

  const containerRef = useRef<HTMLDivElement | null>(null)
  const measureRef = useRef<HTMLDivElement | null>(null)
  // Width of the bar's leading section (clear button + label + divider).
  const leadingRef = useRef<HTMLDivElement | null>(null)
  const [visibleCount, setVisibleCount] = useState(actions.length)

  // Measure once on mount + whenever the container or action set changes.
  // +useLayoutEffect+ so the user never sees a flash of overflowing actions.
  useLayoutEffect(() => {
    function recompute() {
      const container = containerRef.current
      const measure = measureRef.current
      const leading = leadingRef.current
      if (!container || !measure || !leading) return

      // The bar spans the header row, so the budget is its own width less the
      // leading section (the "n selected" count + divider). The container sits
      // inside the host cell's padding and after the select-all checkbox, so
      // neither needs subtracting here.
      const available = container.clientWidth - leading.offsetWidth
      // +⋯+ button (icon-sm = 28px) + gap on each side + safety margin.
      const moreWidth = 64
      // One measured child per action, in order.
      const children = Array.from(measure.children).slice(0, actions.length) as HTMLElement[]
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
    window.addEventListener('resize', recompute)
    return () => {
      ro.disconnect()
      window.removeEventListener('resize', recompute)
    }
    // Re-measure when the action set changes, not only when the container
    // resizes: the list is filtered by permission, so it can gain or lose
    // buttons — and a language switch relabels them — with the bar's own width
    // unchanged. The measuring row is zero-width by design, so observing it
    // would not catch either case.
  }, [actions])

  const visible = actions.slice(0, visibleCount)
  const overflow = actions.slice(visibleCount)

  // `w-full` matters for more than layout: this is the element the overflow
  // calculation measures, and as a bare flex item it would size to its own
  // content instead of the header cell, leaving almost no budget and pushing
  // every action into the `⋯` menu.
  return (
    <>
      <div
        ref={containerRef}
        className="flex w-full items-center gap-0.5 overflow-hidden animate-in fade-in slide-in-from-left-2 duration-150 ease-out"
      >
        {/* No clear button: the bar sits beside the header's select-all
            checkbox, which already clears the selection. */}
        <div ref={leadingRef} className="flex items-center gap-0.5">
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
          // `overflow-hidden` on a zero-width box: the buttons keep their
          // natural `offsetWidth` for measurement, but nothing escapes to
          // stretch the table's scroll width — without it every list becomes
          // horizontally scrollable whenever rows are selected.
          className="pointer-events-none invisible absolute left-0 top-0 flex w-0 items-center gap-0.5 overflow-hidden"
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
      // `shrink-0` so the zero-width measuring layer can't squeeze these and
      // report a width smaller than the button really renders at. Hover is the
      // ghost variant's own `bg-accent` — no override needed now that the bar's
      // muted background sits well clear of it.
      className="shrink-0 gap-1.5 whitespace-nowrap px-2"
    >
      {action.icon}
      {action.label}
    </Button>
  )
}
