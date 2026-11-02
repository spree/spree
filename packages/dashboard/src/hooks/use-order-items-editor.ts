import { zodResolver } from '@hookform/resolvers/zod'
import type { Order, Variant } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, useResourceKey } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { useEffect, useRef, useState } from 'react'
import { useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  buildOrderItemsPayload,
  type OrderEditFormValues,
  type OrderItemsPayload,
  orderEditFormSchema,
  orderToEditForm,
} from '../schemas/order'
import { useOrderMutation } from './use-order'

function editFormFor(order: Order): OrderEditFormValues {
  return orderToEditForm(order.items ?? [], order.fulfillments ?? [])
}

/**
 * Staged line-item editing for one order: the form behind the items table,
 * the picker hand-off and the save. Quantity changes, removals, added variants
 * and (on drafts) negotiated prices live in form state until `save`, which is
 * a single `PATCH /orders/:id` the server runs in one transaction.
 *
 * The order edit page is built on it, and so can any page that edits an
 * order's lines in its own layout — render `OrderEditItemsTable` with `form`
 * and `fields`, `AddLineItemDialog` with `stageVariant`, and
 * `OrderTotalsCard` with `items`.
 *
 * `save` replaces the form with the saved lines when it finishes, so lock the
 * editing controls while `isSaving`: pass `disabled={isSaving}` to
 * `OrderEditItemsTable` and disable whatever opens the picker. Anything typed
 * meanwhile would be erased; a variant picked meanwhile is ignored.
 */
export function useOrderItemsEditor(order: Order | undefined) {
  const { t } = useTranslation()

  const form = useForm<OrderEditFormValues>({
    resolver: zodResolver(orderEditFormSchema),
    defaultValues: { items: [] },
  })

  const { fields, append } = useFieldArray({ control: form.control, name: 'items' })
  // Watched, not read once: the totals card previews staged edits, so it has
  // to re-render on every keystroke in the items table.
  const items = form.watch('items')

  // Hydrate from the server rows, unless the merchant has staged edits in
  // flight on this same order. A different order always replaces the rows:
  // staged lines of one order must never be saved against another.
  const hydratedOrderId = useRef<string | undefined>(undefined)
  // The order on screen right now — undefined while the next one loads —
  // which a save in flight checks before it touches the form.
  const shownOrderId = useRef<string | undefined>(undefined)
  shownOrderId.current = order?.id
  // The order the form's saved values come from: the `order` prop, or what a
  // save read back when the caller's prop has not caught up yet.
  const [savedOrder, setSavedOrder] = useState<Order | undefined>(order)

  function rebaseline(next: Order) {
    hydratedOrderId.current = next.id
    setSavedOrder(next)
    form.reset(editFormFor(next))
  }

  useEffect(() => {
    if (!order) return
    // The saved side follows every refresh — discard and the totals read it —
    // even when staged edits keep the form from re-hydrating.
    setSavedOrder(order)
    if (form.formState.isDirty && hydratedOrderId.current === order.id) return
    hydratedOrderId.current = order.id
    form.reset(editFormFor(order))
  }, [order, form])

  // Covers the whole save, the read-back included: the form is replaced at
  // the end, so nothing may be staged until then. The ref answers the same
  // question synchronously for `stageVariant`.
  const [isSaving, setIsSaving] = useState(false)
  const savingRef = useRef(false)

  const queryClient = useQueryClient()
  const orderKey = useResourceKey('orders', order?.id ?? '')
  const saveMutation = useOrderMutation(order?.id ?? '', (payload: OrderItemsPayload) =>
    adminClient.orders.update(order?.id ?? '', { items: payload }),
  )

  /**
   * Saves the staged edits. Resolves `true` once they are saved (or there was
   * nothing to send), `false` when the server rejected them — field errors are
   * then on the form, anything else was toasted. Also `false` when the page
   * moved to another order while the save was in flight: the save went through
   * for the order it was made on, but nothing the caller does next (leaving the
   * page, refreshing) applies to the order it now shows.
   */
  async function save(values: OrderEditFormValues): Promise<boolean> {
    // Rows the merchant staged and then unstaged net out to nothing, so the
    // payload can legitimately be empty even on a dirty form.
    const payload = buildOrderItemsPayload(values.items)
    const startedAt = Date.now()
    // The order these rows belong to. If the page moves to another order
    // while the save is in flight, nothing below may touch the form.
    const savingOrderId = order?.id
    const stillShown = () => shownOrderId.current === savingOrderId

    // One save at a time: the first to finish would unlock the editor while
    // the other is still in flight.
    if (savingRef.current) return false

    if (payload.length > 0 && !savingOrderId) {
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
      return false
    }

    if (payload.length === 0) {
      if (!stillShown()) return false
      // Nothing was sent, so every remaining row is as the server has it:
      // re-baseline them as they are, server totals included. Leaving the
      // form dirty would trip the unsaved-changes guard on the way out.
      form.reset({
        items: values.items
          .filter((item) => !item.added && !item.removed)
          .map((item) => ({ ...item, revert_price: false })),
      })
      return true
    }

    savingRef.current = true
    setIsSaving(true)
    let patched = false
    try {
      await saveMutation.mutateAsync(payload)
      patched = true
    } catch (err) {
      if (!stillShown()) return false
      if (mapSpreeErrorsToForm(err, form.setError)) return false
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
      return false
    } finally {
      // A failed save unlocks here; one that went through stays locked until
      // the read-back below has replaced the form.
      if (!patched) {
        savingRef.current = false
        setIsSaving(false)
      }
    }

    try {
      if (!stillShown()) return false
      // Re-baseline on what the server saved — the client cannot know a saved
      // line's adjustments. The mutation awaits the order refetch, so a page
      // that loads the order through `useOrder` already has it in the cache;
      // any other page reads it once here.
      const cached = queryClient.getQueryState<Order>(orderKey)
      const saved =
        cached?.data && cached.dataUpdatedAt >= startedAt
          ? cached.data
          : await adminClient.orders
              .get(savingOrderId as string, { expand: ['items', 'fulfillments'] })
              .catch(() => null)
      if (!stillShown()) return false
      if (saved) {
        rebaseline(saved)
      } else {
        // The lines were saved but could not be read back. Keep what was
        // sent as the saved values, so the form is pristine and the next
        // read of the order re-hydrates it with the server's totals.
        toastManager.add({ type: 'warning', title: t('admin.orders.edit.saved_not_reloaded') })
        form.reset({
          items: values.items
            .filter((item) => !item.removed)
            .map((item) => ({
              ...item,
              added: false,
              saved_quantity: item.quantity,
              saved_price: item.price,
              revert_price: false,
            })),
        })
      }
      return true
    } finally {
      savingRef.current = false
      setIsSaving(false)
    }
  }

  /** Drops every staged edit and returns to the saved lines. */
  function discard() {
    const saved = savedOrder?.id === order?.id ? savedOrder : order
    if (saved) form.reset(editFormFor(saved))
  }

  /**
   * Stages a picked variant. Picking one the order already carries (or one that
   * is sitting removed) bumps the existing row rather than adding a duplicate —
   * the endpoint is keyed by variant, so two rows for one variant could not both
   * survive a save.
   */
  function stageVariant(variant: Variant, quantity: number) {
    // The post-save reset would erase a row staged while the save is pending.
    if (savingRef.current) return
    const current = form.getValues('items')
    const existingIndex = current.findIndex((item) => item.variant_id === variant.id)

    if (existingIndex >= 0) {
      const existing = current[existingIndex]
      form.setValue(
        `items.${existingIndex}`,
        {
          ...existing,
          removed: false,
          quantity: existing.removed ? quantity : existing.quantity + quantity,
        },
        { shouldDirty: true, shouldValidate: true },
      )
      return
    }

    append({
      variant_id: variant.id,
      quantity,
      removed: false,
      added: true,
      saved_quantity: 0,
      fulfilled_quantity: 0,
      // Seeded as both current and saved value, so an untouched price is
      // omitted from the payload and the server prices the line itself.
      price: variant.price?.amount ?? '0',
      saved_price: variant.price?.amount ?? '0',
      price_source: null,
      catalog_price: variant.price?.amount ?? null,
      revert_price: false,
      name: variant.product_name,
      options_text: variant.options_text ?? '',
      thumbnail_url: variant.thumbnail_url,
      total: null,
    })
  }

  return {
    form,
    fields,
    items,
    save,
    discard,
    stageVariant,
    isSaving,
    /**
     * The order as last saved — render `OrderTotalsCard` against it. Usually
     * the `order` passed in; after a save on a page whose `order` has not
     * refreshed yet, the order the save read back.
     */
    savedOrder: savedOrder?.id === order?.id ? savedOrder : order,
  }
}
