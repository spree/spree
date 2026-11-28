import { GONE_STATUSES, PageHeader } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
  Button,
  Card,
  ErrorState,
  FormActions,
  ResourceLayout,
  Section,
  SectionHeader,
  SectionTitle,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { InfoIcon, PackageIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { AddLineItemDialog } from '../../../../../components/spree/orders/line-item-dialogs'
import { OrderEditItemsTable } from '../../../../../components/spree/orders/order-edit-items-table'
import { OrderTotalsCard } from '../../../../../components/spree/orders/order-totals-card'
import { useOrder } from '../../../../../hooks/use-order'
import { useOrderChangePreview } from '../../../../../hooks/use-order-change-preview'
import { useOrderItemsEditor } from '../../../../../hooks/use-order-items-editor'
import type { OrderEditFormValues } from '../../../../../schemas/order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId/edit')({
  component: OrderEditPage,
})

/**
 * Line-item management for drafts and placed orders. Quantity changes,
 * removals and picker additions are staged in form state and applied together
 * on Save, in one transaction. On a placed order the totals card shows the
 * server's preview of the staged edits, and Save applies them as an order
 * change (docs/plans/6.1-order-change-substrate.md).
 */
function OrderEditPage() {
  const { t } = useTranslation()
  const { storeId, orderId } = Route.useParams()
  const navigate = useNavigate()
  const { data: order, isLoading, error, refetch } = useOrder(orderId)
  const [addingItem, setAddingItem] = useState(false)
  const editor = useOrderItemsEditor(order)
  const { form } = editor
  const preview = useOrderChangePreview(order, editor.items)

  async function onSubmit(values: OrderEditFormValues) {
    // Editing is a detour from the order, not a place to stay: hand the
    // merchant back the view that shows what the edit did.
    if (await editor.save(values)) {
      navigate({ to: '/$storeId/orders/$orderId', params: { storeId, orderId } })
    }
  }

  // Not while the picker is open: a variant picked during the save would be
  // ignored, and the dialog closes on pick with no word of it.
  useFormSubmitShortcut(form, (values) => (addingItem ? undefined : onSubmit(values)))

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
            backTo={`orders/${orderId}`}
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
          <p className="text-base text-destructive" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <ResourceLayout
          header={
            <PageHeader
              title={t('admin.orders.edit.title')}
              subtitle={t('admin.orders.edit.subtitle', { number: order.number })}
              backTo={`orders/${orderId}`}
              actions={
                <>
                  <Button
                    type="button"
                    variant="outline"
                    disabled={editor.isSaving}
                    onClick={() => setAddingItem(true)}
                  >
                    <PlusIcon className="size-4" />
                    {t('admin.orders.edit.actions.add_product')}
                  </Button>
                  <FormActions form={form} onDiscard={editor.discard} />
                </>
              }
            />
          }
          main={
            <Section>
              <SectionHeader>
                <SectionTitle>
                  <PackageIcon />
                  {t('admin.orders.edit.items_title')}
                </SectionTitle>
              </SectionHeader>
              <Card>
                {/* Unit prices are negotiable pre-placement only: a placed
                    order's money edits stay fees and discounts. */}
                <OrderEditItemsTable
                  form={form}
                  fields={editor.fields}
                  pricesEditable={order.status === 'draft'}
                  disabled={editor.isSaving}
                  currency={order.currency}
                />
              </Card>
            </Section>
          }
          sidebar={
            <OrderTotalsCard
              order={editor.savedOrder ?? order}
              items={editor.items}
              preview={preview.preview}
              previewPending={preview.isPending}
              previewError={preview.error}
            />
          }
        />
      </form>

      {addingItem && (
        <AddLineItemDialog
          searchParams={{ order_id: orderId }}
          open={addingItem}
          onOpenChange={setAddingItem}
          onSelect={editor.stageVariant}
        />
      )}
    </>
  )
}
