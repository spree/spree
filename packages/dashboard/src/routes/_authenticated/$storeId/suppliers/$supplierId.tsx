import type { Supplier } from '@spree/admin-sdk'
import {
  adminClient,
  Money,
  PageHeader,
  RecordMetadataCard,
  Slot,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Empty,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
  ErrorState,
  Pagination,
  ResourceLayout,
  Section,
  SectionActions,
  SectionHeader,
  SectionTitle,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@spree/dashboard-ui'
import { PlusIcon, TruckIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { InventoryStatusBadge } from '../../../../components/spree/inventory-status-badge'
import { ResourceDetailSkeleton } from '../../../../components/spree/route-pending'
import {
  SupplierFormFields,
  type SupplierFormPart,
  useSupplierForm,
} from '../../../../components/spree/supplier-form'
import { useSupplierPurchaseOrders } from '../../../../hooks/use-purchase-orders'
import { useDeleteSupplier, useSupplier, useUpdateSupplier } from '../../../../hooks/use-suppliers'

export const Route = createFileRoute('/_authenticated/$storeId/suppliers/$supplierId')({
  component: SupplierPage,
})

function SupplierPage() {
  const { t } = useTranslation()
  const { supplierId } = Route.useParams()
  const { data: supplier, isLoading, error, refetch } = useSupplier(supplierId)

  if (isLoading) return <ResourceDetailSkeleton />
  if (error || !supplier) {
    return (
      <ErrorState
        title={t('admin.suppliers.detail.load_error')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <SupplierBody key={supplier.id} supplier={supplier} />
}

function SupplierBody({ supplier }: { supplier: Supplier }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { permissions } = usePermissions()
  const deleteMutation = useDeleteSupplier()
  const canEdit = permissions.can('update', Subject.Supplier)

  async function handleDelete() {
    await deleteMutation.mutateAsync(supplier.id)
    navigate({ to: '/$storeId/suppliers', params: { storeId } })
  }

  return (
    <ResourceLayout
      header={
        <PageHeader
          title={supplier.name}
          backTo="suppliers"
          resource={{ id: supplier.id }}
          jsonPreview={{
            title: `Supplier ${supplier.name}`,
            fetch: () => adminClient.suppliers.get(supplier.id),
            endpoint: `/api/v3/admin/suppliers/${supplier.id}`,
          }}
          // A supplier with a purchasing history is kept, so the orders naming
          // it keep meaning something (the model's `restrict_with_error`).
          onDelete={
            permissions.can('destroy', Subject.Supplier) && supplier.can_be_deleted
              ? handleDelete
              : undefined
          }
          deleteConfirmTitle={t('admin.suppliers.delete_confirm.title')}
          deleteConfirmMessage={t('admin.suppliers.delete_confirm.message', {
            name: supplier.name,
          })}
        />
      }
      main={
        <>
          <PurchaseOrdersSection supplier={supplier} />
          <RecordMetadataCard metadata={supplier.metadata} />
          <Slot name="supplier.form_main" context={{ supplier, canEdit }} />
        </>
      }
      sidebar={
        <>
          <SupplierPartCard
            supplier={supplier}
            canEdit={canEdit}
            part="details"
            title={t('admin.suppliers.detail.details')}
          />
          <SupplierPartCard
            supplier={supplier}
            canEdit={canEdit}
            part="address"
            title={t('admin.suppliers.detail.address')}
          />
          <Slot name="supplier.form_sidebar" context={{ supplier, canEdit }} />
        </>
      }
    />
  )
}

/** One half of the supplier — its details or its address — with its own Save. */
function SupplierPartCard({
  supplier,
  canEdit,
  part,
  title,
}: {
  supplier: Supplier
  canEdit: boolean
  part: SupplierFormPart
  title: string
}) {
  const { t } = useTranslation()
  const updateMutation = useUpdateSupplier(supplier.id)
  const { form, set, save, submitAttempted, isDirty } = useSupplierForm(
    supplier,
    (payload) => updateMutation.mutateAsync(payload),
    part,
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <fieldset disabled={!canEdit} className="min-w-0">
          <SupplierFormFields form={form} set={set} submitAttempted={submitAttempted} part={part} />
        </fieldset>
        {canEdit && (
          <div className="flex justify-end">
            <Button
              type="button"
              size="sm"
              disabled={updateMutation.isPending || !isDirty}
              onClick={() => save()}
            >
              {updateMutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </div>
        )}
      </CardContent>
    </Card>
  )
}

function PurchaseOrdersSection({ supplier }: { supplier: Supplier }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const { permissions } = usePermissions()
  const [page, setPage] = useState(1)
  const { data, isLoading } = useSupplierPurchaseOrders(supplier.id, page)

  const orders = data?.data ?? []
  const meta = data?.meta

  return (
    <Section>
      <SectionHeader>
        <SectionTitle>
          <TruckIcon />
          {t('admin.purchase_orders.title')}
          {meta?.count ? <Badge variant="outline">{meta.count}</Badge> : null}
        </SectionTitle>
        {permissions.can('create', Subject.PurchaseOrder) && (
          <SectionActions>
            <Button size="sm" variant="outline" asChild>
              <Link
                to="/$storeId/purchase-orders/new"
                params={{ storeId }}
                search={{ supplier_id: supplier.id }}
              >
                <PlusIcon className="size-4" />
                {t('admin.purchase_orders.new_cta')}
              </Link>
            </Button>
          </SectionActions>
        )}
      </SectionHeader>

      <Card>
        {isLoading || orders.length === 0 ? (
          <CardContent>
            {isLoading ? (
              <p className="text-muted-foreground text-sm">{t('admin.common.loading')}</p>
            ) : (
              <Empty className="p-4">
                <EmptyHeader>
                  <EmptyMedia variant="icon">
                    <TruckIcon />
                  </EmptyMedia>
                  <EmptyTitle>{t('admin.suppliers.detail.orders_empty')}</EmptyTitle>
                </EmptyHeader>
              </Empty>
            )}
          </CardContent>
        ) : (
          <>
            <Table roundedTop>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.purchase_orders.columns.number')}</TableHead>
                  <TableHead>{t('admin.fields.status.label')}</TableHead>
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.units')}
                  </TableHead>
                  <TableHead className="text-right">
                    {t('admin.purchase_orders.columns.subtotal')}
                  </TableHead>
                  <TableHead>{t('admin.purchase_orders.columns.expected')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {orders.map((order) => (
                  <TableRow key={order.id}>
                    <TableCell>
                      <Link
                        to="/$storeId/purchase-orders/$purchaseOrderId"
                        params={{ storeId, purchaseOrderId: order.id }}
                        className="font-medium tabular-nums hover:underline"
                      >
                        {order.number}
                      </Link>
                    </TableCell>
                    <TableCell>
                      <InventoryStatusBadge status={order.status} resource="purchase_orders" />
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      {order.quantity_received_total} / {order.quantity_ordered_total}
                    </TableCell>
                    <TableCell className="text-right tabular-nums">
                      <Money amount={order.subtotal} currency={order.currency} />
                    </TableCell>
                    <TableCell className="whitespace-nowrap text-muted-foreground text-sm">
                      {order.expected_at ?? '—'}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {meta && meta.pages > 1 && <Pagination inset meta={meta} onPageChange={setPage} />}
          </>
        )}
      </Card>
    </Section>
  )
}
