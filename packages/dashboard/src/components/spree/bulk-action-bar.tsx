import { usePermissions } from '@spree/dashboard-core'
import { Button, useConfirm } from '@spree/dashboard-ui'
import type { QueryKey } from '@tanstack/react-query'
import { useQueryClient } from '@tanstack/react-query'
import type { ReactNode } from 'react'
import { useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'

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
}

function interpolate(template: string, n: number) {
  return template.replace(/\{n\}/g, String(n))
}

export function BulkActionBar({ selectedIds, actions, onClear, onDone }: BulkActionBarProps) {
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
    <>
      {/* Sticky bar above the table body. Stays at the bottom of the viewport
          when the table is long, so the action set is always reachable. */}
      <div className="sticky bottom-4 z-20 mx-4 my-3 flex items-center gap-2 rounded-lg border bg-popover px-3 py-2 shadow-md">
        <span className="text-sm font-medium">
          {t('admin.components.bulk_action_bar.selected', { count })}
        </span>
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={onClear}
          className="text-muted-foreground"
        >
          {t('admin.actions.clear')}
        </Button>
        <div className="ml-auto flex flex-wrap items-center gap-1">
          {visibleActions.map((action) => (
            <Button
              key={action.key}
              type="button"
              variant="outline"
              size="sm"
              onClick={() => handleClick(action)}
              disabled={running}
            >
              {action.icon}
              {action.label}
            </Button>
          ))}
        </div>
      </div>
      {pendingForm?.form?.({
        ids: selectedIds,
        onCancel: () => setPendingForm(null),
        onSubmit: async (values) => {
          const action = pendingForm
          setPendingForm(null)
          await execute(action, values)
        },
      })}
    </>
  )
}
