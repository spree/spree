import { zodResolver } from '@hookform/resolvers/zod'
import { type Order, SpreeError, type Variant } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm } from '@spree/dashboard-core'
import { toastManager } from '@spree/dashboard-ui'
import { useEffect } from 'react'
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

  // Hydrate (and re-baseline after save) from the server rows, unless the
  // merchant has staged edits in flight.
  useEffect(() => {
    if (!order || form.formState.isDirty) return
    form.reset(orderToEditForm(order.items ?? [], order.fulfillments ?? []))
  }, [order, form])

  const saveMutation = useOrderMutation(order?.id ?? '', (payload: OrderItemsPayload) =>
    adminClient.orders.update(order?.id ?? '', { items: payload }),
  )

  /**
   * Saves the staged edits. Resolves `true` once they are saved (or there was
   * nothing to send), `false` when the server rejected them — field errors are
   * then on the form, anything else was toasted.
   */
  async function save(values: OrderEditFormValues): Promise<boolean> {
    // Rows the merchant staged and then unstaged net out to nothing, so the
    // payload can legitimately be empty even on a dirty form.
    const payload = buildOrderItemsPayload(values.items)

    try {
      if (payload.length > 0) await saveMutation.mutateAsync(payload)
      // Drop the rows that are gone and re-baseline the rest, so the form is
      // pristine before the refetch lands — leaving it dirty would trip the
      // unsaved-changes guard on the way out.
      form.reset({
        items: values.items
          .filter((item) => !item.removed)
          .map((item) => {
            // A revert re-prices server-side; carry the catalog estimate until
            // the refetch corrects it.
            const reverted = item.revert_price
            const price = reverted ? (item.catalog_price ?? item.price) : item.price

            return {
              ...item,
              added: false,
              saved_quantity: item.quantity,
              price,
              saved_price: price,
              price_source: reverted
                ? null
                : item.price !== item.saved_price
                  ? 'manual'
                  : item.price_source,
              revert_price: false,
            }
          }),
      })
      return true
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return false
      if (err instanceof SpreeError) throw err
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
      return false
    }
  }

  /** Drops every staged edit and returns to the saved lines. */
  function discard() {
    if (!order) return
    form.reset(orderToEditForm(order.items ?? [], order.fulfillments ?? []))
  }

  /**
   * Stages a picked variant. Picking one the order already carries (or one that
   * is sitting removed) bumps the existing row rather than adding a duplicate —
   * the endpoint is keyed by variant, so two rows for one variant could not both
   * survive a save.
   */
  function stageVariant(variant: Variant, quantity: number) {
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
    isSaving: saveMutation.isPending,
  }
}
