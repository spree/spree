import type { LineItem, Order } from '@spree/admin-sdk'
import { adminClient, PageHeader } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  ErrorState,
  ResourceLayout,
  Separator,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { PackageIcon, PencilIcon, PlusIcon, Trash2Icon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  AddLineItemDialog,
  EditQuantityDialog,
} from '../../../../../components/spree/orders/line-item-dialogs'
import { useOrder, useOrderMutation } from '../../../../../hooks/use-order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId/edit')({
  component: OrderEditPage,
})

/**
 * One row of the items table. Every action fires its own request against the
 * line-item endpoints and the order re-reads from the server — there is no
 * pending-edit buffer, so totals only move once a write has landed.
 */
function LineItemRow({ orderId, item }: { orderId: string; item: LineItem }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const [editingQuantity, setEditingQuantity] = useState(false)

  const removeMutation = useOrderMutation(orderId, () =>
    adminClient.orders.items.delete(orderId, item.id),
  )

  async function handleRemove() {
    const confirmed = await confirm({
      title: t('admin.orders.edit.confirm.remove_title'),
      message: t('admin.orders.edit.confirm.remove_message', { name: item.name }),
      confirmLabel: t('admin.orders.edit.actions.remove'),
      variant: 'destructive',
    })
    if (confirmed) removeMutation.mutate(undefined)
  }

  return (
    <>
      <TableRow>
        <TableCell>
          <div className="flex items-center gap-3">
            {item.thumbnail_url ? (
              <img
                src={item.thumbnail_url}
                alt={item.name}
                className="size-12 shrink-0 rounded-lg border object-cover"
              />
            ) : (
              <div className="flex size-12 shrink-0 items-center justify-center rounded-lg border bg-muted">
                <PackageIcon className="size-5 text-muted-foreground" />
              </div>
            )}
            <div className="min-w-0">
              <div className="truncate text-sm font-medium">{item.name}</div>
              {item.options_text && (
                <div className="truncate text-xs text-muted-foreground">{item.options_text}</div>
              )}
            </div>
          </div>
        </TableCell>
        <TableCell className="text-right whitespace-nowrap">{item.display_price}</TableCell>
        <TableCell className="text-right">{item.quantity}</TableCell>
        <TableCell className="text-right whitespace-nowrap">{item.display_total}</TableCell>
        <TableCell className="text-right">
          <div className="flex items-center justify-end gap-1">
            <Button
              variant="ghost"
              size="icon"
              onClick={() => setEditingQuantity(true)}
              aria-label={t('admin.orders.edit.actions.edit_quantity_for', { name: item.name })}
            >
              <PencilIcon className="size-4" />
            </Button>
            <Button
              variant="ghost"
              size="icon"
              onClick={handleRemove}
              disabled={removeMutation.isPending}
              aria-label={t('admin.orders.edit.actions.remove_item', { name: item.name })}
            >
              <Trash2Icon className="size-4 text-destructive" />
            </Button>
          </div>
        </TableCell>
      </TableRow>

      {editingQuantity && (
        <EditQuantityDialog
          orderId={orderId}
          lineItemId={item.id}
          currentQuantity={item.quantity}
          open={editingQuantity}
          onOpenChange={setEditingQuantity}
        />
      )}
    </>
  )
}

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
      <CardHeader className="px-5 py-4">
        <CardTitle>{t('admin.orders.edit.totals_title')}</CardTitle>
      </CardHeader>

      <Separator />

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
 * Post-placement line-item management: add a product, change a quantity,
 * remove an item. Each interaction is one request, immediately applied.
 */
function OrderEditPage() {
  const { t } = useTranslation()
  const { storeId, orderId } = Route.useParams()
  const { data: order, isLoading, error, refetch } = useOrder(orderId)
  const [addingItem, setAddingItem] = useState(false)

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

  const items = order.items ?? []

  return (
    <>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.orders.edit.title')}
            subtitle={t('admin.orders.edit.subtitle', { number: order.number })}
            backTo={`${storeId}/orders/${orderId}`}
            actions={
              <Button onClick={() => setAddingItem(true)}>
                <PlusIcon className="size-4" />
                {t('admin.orders.edit.actions.add_product')}
              </Button>
            }
          />
        }
        main={
          <Card>
            <CardHeader>
              <CardTitle>{t('admin.orders.edit.items_title')}</CardTitle>
            </CardHeader>
            <CardContent>
              {items.length === 0 ? (
                <p className="py-8 text-center text-muted-foreground">
                  {t('admin.orders.edit.empty')}
                </p>
              ) : (
                <Table>
                  <TableHeader>
                    <TableRow>
                      <TableHead>{t('admin.orders.edit.columns.product')}</TableHead>
                      <TableHead className="text-right">
                        {t('admin.orders.edit.columns.unit_price')}
                      </TableHead>
                      <TableHead className="text-right">
                        {t('admin.fields.quantity.label')}
                      </TableHead>
                      <TableHead className="text-right">
                        {t('admin.orders.edit.columns.line_total')}
                      </TableHead>
                      <TableHead className="w-24" />
                    </TableRow>
                  </TableHeader>
                  <TableBody>
                    {items.map((item) => (
                      <LineItemRow key={item.id} orderId={orderId} item={item} />
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        }
        sidebar={<OrderTotalsCard order={order} />}
      />

      {addingItem && (
        <AddLineItemDialog orderId={orderId} open={addingItem} onOpenChange={setAddingItem} />
      )}
    </>
  )
}
