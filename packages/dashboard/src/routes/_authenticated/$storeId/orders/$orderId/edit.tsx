import { zodResolver } from '@hookform/resolvers/zod'
import { type Order, SpreeError, type Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  ErrorState,
  FormActions,
  ResourceLayout,
  Separator,
  toastManager,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { InfoIcon, PlusIcon } from 'lucide-react'
import { type ReactNode, useEffect, useState } from 'react'
import { useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { AddLineItemDialog } from '../../../../../components/spree/orders/line-item-dialogs'
import { OrderEditItemsTable } from '../../../../../components/spree/orders/order-edit-items-table'
import { useOrder, useOrderMutation } from '../../../../../hooks/use-order'
import { GONE_STATUSES } from '../../../../../lib/fulfillment-items'
import {
  buildOrderItemsPayload,
  type OrderEditFormValues,
  type OrderItemsPayload,
  orderEditFormSchema,
  orderToEditForm,
} from '../../../../../schemas/order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId/edit')({
  component: OrderEditPage,
})

function TotalRow({ label, value, bold }: { label: string; value: ReactNode; bold?: boolean }) {
  return (
    <div className="flex items-center justify-between px-5 py-2.5">
      <span className="text-sm">{label}</span>
      <span className={cn('text-sm', bold && 'font-bold')}>{value}</span>
    </div>
  )
}

/**
 * The order's totals as the server currently has them. Deliberately not a
 * projection: 6.0 cannot compute what an edit would cost without writing the
 * rows, so this only ever reflects writes that already landed.
 */
function OrderTotalsCard({ order }: { order: Order }) {
  const { t } = useTranslation()

  return (
    <Card className="gap-0 py-0">
      <CardHeader>
        <CardTitle>{t('admin.orders.edit.totals_title')}</CardTitle>
      </CardHeader>

      <div className="py-2">
        <TotalRow label={t('admin.fields.subtotal.label')} value={order.display_item_total} />

        {Number.parseFloat(order.delivery_total) > 0 && (
          <TotalRow label={t('admin.fields.shipping.label')} value={order.display_delivery_total} />
        )}

        {Number.parseFloat(order.discount_total) !== 0 && (
          <TotalRow
            label={t('admin.orders.detail.summary.promotions')}
            value={order.display_discount_total}
          />
        )}

        {Number.parseFloat(order.included_tax_total) > 0 && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={order.display_included_tax_total}
          />
        )}

        {Number.parseFloat(order.additional_tax_total) > 0 && (
          <TotalRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={order.display_additional_tax_total}
          />
        )}

        <Separator />

        <TotalRow label={t('admin.fields.total.label')} value={order.display_total} bold />
      </div>

      <Separator />

      <CardContent className="px-5 py-4">
        <p className="text-xs text-muted-foreground">{t('admin.orders.edit.totals_hint')}</p>
      </CardContent>
    </Card>
  )
}

/**
 * Post-placement line-item management. Quantity changes, removals and picker
 * additions are staged in form state and applied together on Save, which is a
 * single `PATCH /orders/:id` the server runs in one transaction.
 */
function OrderEditPage() {
  const { t } = useTranslation()
  const { storeId, orderId } = Route.useParams()
  const navigate = useNavigate()
  const { data: order, isLoading, error, refetch } = useOrder(orderId)
  const [addingItem, setAddingItem] = useState(false)

  const form = useForm<OrderEditFormValues>({
    resolver: zodResolver(orderEditFormSchema),
    defaultValues: { items: [] },
  })

  const { fields, append } = useFieldArray({ control: form.control, name: 'items' })

  // Hydrate (and re-baseline after save) from the server rows, unless the
  // merchant has staged edits in flight.
  useEffect(() => {
    if (!order || form.formState.isDirty) return
    form.reset(orderToEditForm(order.items ?? [], order.fulfillments ?? []))
  }, [order, form])

  const saveMutation = useOrderMutation(orderId, (items: OrderItemsPayload) =>
    adminClient.orders.update(orderId, { items }),
  )

  async function onSubmit(values: OrderEditFormValues) {
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
          .map((item) => ({ ...item, added: false, saved_quantity: item.quantity })),
      })
      // Editing is a detour from the order, not a place to stay: hand the
      // merchant back the view that shows what the edit did.
      navigate({ to: '/$storeId/orders/$orderId', params: { storeId, orderId } })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  /**
   * Stages a picked variant. Picking one the order already carries (or one that
   * is sitting removed) bumps the existing row rather than adding a duplicate —
   * the endpoint is keyed by variant, so two rows for one variant could not both
   * survive a save.
   */
  function stageVariant(variant: Variant, quantity: number) {
    const items = form.getValues('items')
    const existingIndex = items.findIndex((item) => item.variant_id === variant.id)

    if (existingIndex >= 0) {
      const existing = items[existingIndex]
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
      name: variant.product_name,
      options_text: variant.options_text ?? '',
      thumbnail_url: variant.thumbnail_url,
      display_price: formatPrice(variant.price),
      display_total: '',
    })
  }

  if (!order && isLoading) return null

  if (error || !order) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_order')}
        description={t('admin.orders.detail.load_failed_message', { orderId })}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  // The header hides its edit link on fulfilled orders, but the URL stays
  // reachable — and the per-row clamps below would still allow additions.
  if (GONE_STATUSES.includes(order.fulfillment_status ?? '')) {
    return (
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.orders.edit.title')}
            subtitle={t('admin.orders.edit.subtitle', { number: order.number })}
            backTo={`${storeId}/orders/${orderId}`}
          />
        }
        main={
          <Alert variant="warning">
            <InfoIcon />
            <AlertDescription>{t('admin.orders.edit.fully_fulfilled')}</AlertDescription>
          </Alert>
        }
      />
    )
  }

  return (
    <>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {form.formState.errors.root?.message && (
          <p className="text-sm text-destructive" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <ResourceLayout
          header={
            <PageHeader
              title={t('admin.orders.edit.title')}
              subtitle={t('admin.orders.edit.subtitle', { number: order.number })}
              backTo={`${storeId}/orders/${orderId}`}
              actions={
                <>
                  <Button type="button" variant="outline" onClick={() => setAddingItem(true)}>
                    <PlusIcon className="size-4" />
                    {t('admin.orders.edit.actions.add_product')}
                  </Button>
                  <FormActions
                    form={form}
                    onDiscard={() =>
                      form.reset(orderToEditForm(order.items ?? [], order.fulfillments ?? []))
                    }
                  />
                </>
              }
            />
          }
          main={
            <Card>
              <CardHeader>
                <CardTitle>{t('admin.orders.edit.items_title')}</CardTitle>
              </CardHeader>
              <CardContent className="p-0">
                <OrderEditItemsTable form={form} fields={fields} />
              </CardContent>
            </Card>
          }
          sidebar={<OrderTotalsCard order={order} />}
        />
      </form>

      {addingItem && (
        <AddLineItemDialog open={addingItem} onOpenChange={setAddingItem} onSelect={stageVariant} />
      )}
    </>
  )
}
