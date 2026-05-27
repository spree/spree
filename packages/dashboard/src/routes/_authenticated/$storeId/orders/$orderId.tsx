import type { Order, Variant } from '@spree/admin-sdk'
import { adminClient, formatPrice, getInitials, useResourceMutation } from '@spree/dashboard-core'
import {
  AddressBlock,
  Avatar,
  AvatarFallback,
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  cn,
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
  ErrorState,
  Field,
  FieldGroup,
  FieldLabel,
  Input,
  MetadataCard,
  RelativeTime,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Separator,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Skeleton,
  StatusBadge,
  Switch,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute } from '@tanstack/react-router'
import {
  CheckCircleIcon,
  CreditCardIcon,
  EllipsisVerticalIcon,
  ExternalLinkIcon,
  MailIcon,
  MapPinIcon,
  PackageIcon,
  PencilIcon,
  PlusIcon,
  RotateCcwIcon,
  ShieldCheckIcon,
  ShoppingCartIcon,
  TrashIcon,
  TruckIcon,
  XCircleIcon,
} from 'lucide-react'
import { type FormEvent, useEffect, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { AddressFormDialog, type AddressParams } from '@/components/spree/address-form-dialog'
import { CustomFieldsCard } from '@/components/spree/custom-fields/custom-fields-card'
import { PageHeader } from '@/components/spree/page-header'
import { TagCombobox } from '@/components/spree/tag-combobox'
import { orderQueryKey, useOrder, useOrderMutation } from '@/hooks/use-order'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId')({
  component: OrderDetailPage,
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function formatDate(iso: string | null) {
  if (!iso) return '—'
  return new Date(iso).toLocaleDateString('en-US', {
    month: 'short',
    day: 'numeric',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  })
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function OrderDetailPage() {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const { data: order, isLoading, error, refetch } = useOrder(orderId)

  if (isLoading) return <OrderSkeleton />
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

  return (
    <ResourceLayout
      header={<OrderHeader order={order} />}
      main={
        <>
          <LineItemsCard order={order} />
          <ShipmentsCard order={order} />
          <PaymentsCard order={order} />
          <OrderSummaryCard order={order} />
          <CustomFieldsCard ownerType="Spree::Order" ownerId={order.id} resourceLabel="orders" />
          <MetadataCard metadata={order.metadata} />
        </>
      }
      sidebar={
        <>
          <CustomerCard order={order} />
          <TagsCard order={order} />
          <DiscountsCard order={order} />
          <SpecialInstructionsCard order={order} />
          <InternalNoteCard order={order} />
        </>
      }
    />
  )
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

function OrderHeader({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const confirm = useConfirm()

  const backFallback = order.completed_at ? 'orders' : 'orders/drafts'

  const cancelMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.cancel(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.canceled'),
    errorMessage: t('admin.orders.detail.errors.cancel_failed'),
  })
  const completeMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.complete(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.completed'),
    errorMessage: t('admin.orders.detail.errors.complete_failed'),
  })
  const approveMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.approve(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.approved'),
    errorMessage: t('admin.orders.detail.errors.approve_failed'),
  })
  const resumeMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.resume(orderId),
    invalidate: [orderQueryKey(orderId)],
    successMessage: t('admin.orders.detail.messages.resumed'),
    errorMessage: t('admin.orders.detail.errors.resume_failed'),
  })
  const resendMutation = useResourceMutation({
    mutationFn: () => adminClient.orders.resendConfirmation(orderId, {}),
    successMessage: t('admin.orders.detail.messages.confirmation_sent'),
    errorMessage: t('admin.orders.detail.errors.confirmation_send_failed'),
  })

  const badges = (
    <>
      {order.payment_status && <StatusBadge status={order.payment_status} />}
      {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
    </>
  )

  const subtitle = order.completed_at ? (
    <RelativeTime iso={order.completed_at} prefix="Completed" />
  ) : undefined

  const dropdownItems = (
    <>
      {order.status === 'draft' && (
        <DropdownMenuItem
          onClick={async () => {
            if (
              await confirm({
                message: t('admin.orders.detail.confirm.complete_message'),
                confirmLabel: 'Complete',
              })
            ) {
              completeMutation.mutate(undefined)
            }
          }}
          disabled={completeMutation.isPending}
        >
          <CheckCircleIcon className="size-4" />
          {t('admin.orders.detail.dropdown.complete_order')}
        </DropdownMenuItem>
      )}
      {order.considered_risky && !order.approved_at && (
        <DropdownMenuItem
          onClick={async () => {
            if (
              await confirm({
                title: t('admin.pages.orders.detail.dialogs.approve_title'),
                message: t('admin.orders.detail.confirm.approve_message'),
                confirmLabel: t('admin.pages.orders.detail.actions.approve'),
              })
            ) {
              approveMutation.mutate(undefined)
            }
          }}
          disabled={approveMutation.isPending}
        >
          <ShieldCheckIcon className="size-4" />
          {t('admin.pages.orders.detail.actions.approve')}
        </DropdownMenuItem>
      )}
      {order.status === 'canceled' && (
        <DropdownMenuItem
          onClick={async () => {
            if (
              await confirm({
                message: t('admin.orders.detail.confirm.resume_message'),
                confirmLabel: t('admin.pages.orders.detail.actions.resume'),
              })
            ) {
              resumeMutation.mutate(undefined)
            }
          }}
          disabled={resumeMutation.isPending}
        >
          <RotateCcwIcon className="size-4" />
          {t('admin.pages.orders.detail.actions.resume')}
        </DropdownMenuItem>
      )}
      {order.completed_at && (
        <>
          <DropdownMenuItem>
            <ExternalLinkIcon className="size-4" />
            {t('admin.orders.detail.dropdown.preview_order')}
          </DropdownMenuItem>
          <DropdownMenuItem
            onClick={() => resendMutation.mutate(undefined)}
            disabled={resendMutation.isPending}
          >
            <MailIcon className="size-4" />
            {t('admin.orders.detail.dropdown.resend_confirmation')}
          </DropdownMenuItem>
          <DropdownMenuSeparator />
        </>
      )}
      {order.status !== 'canceled' && (
        <DropdownMenuItem
          variant="destructive"
          onClick={async () => {
            if (
              await confirm({
                title: t('admin.pages.orders.detail.dialogs.cancel_title'),
                message: t('admin.orders.detail.confirm.cancel_message'),
                variant: 'destructive',
                confirmLabel: t('admin.pages.orders.detail.actions.cancel'),
              })
            ) {
              cancelMutation.mutate(undefined)
            }
          }}
          disabled={cancelMutation.isPending}
        >
          <XCircleIcon className="size-4" />
          {t('admin.pages.orders.detail.actions.cancel')}
        </DropdownMenuItem>
      )}
    </>
  )

  return (
    <PageHeader
      title={order.number}
      subtitle={subtitle}
      backTo={backFallback}
      badges={badges}
      dropdownItems={dropdownItems}
      resource={{ id: order.id, number: order.number }}
      jsonPreview={{
        title: `Order ${order.number}`,
        queryKey: ['json', 'order', orderId],
        queryFn: () => adminClient.orders.get(orderId),
        endpoint: `/api/v3/admin/orders/${orderId}`,
      }}
    />
  )
}

// ---------------------------------------------------------------------------
// Line Items
// ---------------------------------------------------------------------------

function AddLineItemDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const [search, setSearch] = useState('')
  const [selectedVariant, setSelectedVariant] = useState<Variant | null>(null)
  const [quantity, setQuantity] = useState(1)

  const { data: variantsData } = useQuery({
    queryKey: ['variants', 'search', search],
    queryFn: () => adminClient.variants.list({ search, limit: 10 }),
    enabled: search.length >= 3,
    staleTime: 30_000,
  })

  const variants = variantsData?.data ?? []

  const mutation = useOrderMutation(orderId, (params: { variant_id: string; quantity: number }) =>
    adminClient.orders.items.create(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!selectedVariant) return
    mutation.mutate(
      { variant_id: selectedVariant.id, quantity },
      {
        onSuccess: () => {
          onOpenChange(false)
          setSelectedVariant(null)
          setSearch('')
          setQuantity(1)
        },
      },
    )
  }

  return (
    <Sheet open={open} onOpenChange={(o) => onOpenChange(o as boolean)}>
      <SheetContent side="right">
        <SheetHeader>
          <SheetTitle>Add Line Item</SheetTitle>
          <SheetDescription>{t('admin.orders.detail.variant_search.description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={handleSubmit} className="flex flex-col flex-1 overflow-hidden">
          <div className="flex-1 overflow-y-auto p-4">
            <FieldGroup>
              <Field>
                <FieldLabel>{t('admin.orders.detail.variant_search.label')}</FieldLabel>
                <Input
                  placeholder="Type product name or SKU (min 3 chars)..."
                  value={search}
                  onChange={(e) => {
                    setSearch(e.target.value)
                    setSelectedVariant(null)
                  }}
                  autoFocus
                />
                {search.length >= 3 && variants.length > 0 && !selectedVariant && (
                  <div className="mt-1 rounded-lg border border-border bg-popover text-popover-foreground shadow-xs max-h-[280px] overflow-y-auto">
                    {variants.map((v) => (
                      <button
                        key={v.id}
                        type="button"
                        onClick={() => {
                          setSelectedVariant(v)
                          setSearch('')
                        }}
                        className="flex w-full items-center gap-3 px-3 py-2.5 text-left text-sm hover:bg-muted transition-colors border-b last:border-0"
                      >
                        <div className="min-w-0 flex-1">
                          <div className="font-medium truncate">{v.product_name ?? v.sku}</div>
                          <div className="text-xs text-muted-foreground">
                            {v.options_text && <span>{v.options_text} · </span>}
                            {t('admin.orders.detail.variant_search.sku_prefix')}: {v.sku || '—'}
                          </div>
                        </div>
                        <div className="text-sm font-medium whitespace-nowrap">
                          {formatPrice(v.price)}
                        </div>
                      </button>
                    ))}
                  </div>
                )}
                {search.length >= 3 && variants.length === 0 && !selectedVariant && (
                  <p className="mt-1 text-xs text-muted-foreground">
                    {t('admin.orders.detail.variant_search.empty')}
                  </p>
                )}
              </Field>

              {selectedVariant && (
                <div className="flex items-center justify-between rounded-lg border border-primary/30 bg-primary/5 p-3">
                  <div>
                    <div className="text-sm font-medium">
                      {selectedVariant.product_name ?? selectedVariant.sku}
                    </div>
                    <div className="text-xs text-muted-foreground">
                      {selectedVariant.options_text && (
                        <span>{selectedVariant.options_text} · </span>
                      )}
                      {t('admin.orders.detail.variant_search.sku_prefix')}:{' '}
                      {selectedVariant.sku || '—'} · {formatPrice(selectedVariant.price)}
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={() => setSelectedVariant(null)}
                    className="rounded p-1 text-muted-foreground hover:bg-accent hover:text-foreground"
                    aria-label={t('admin.a11y.clear_selection')}
                  >
                    <XCircleIcon className="size-4" />
                  </button>
                </div>
              )}

              <Field>
                <FieldLabel htmlFor="quantity">Quantity</FieldLabel>
                <Input
                  id="quantity"
                  type="number"
                  min={1}
                  value={quantity}
                  onChange={(e) => setQuantity(Number(e.target.value) || 1)}
                />
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={!selectedVariant || mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditQuantityDialog({
  orderId,
  lineItemId,
  currentQuantity,
  open,
  onOpenChange,
}: {
  orderId: string
  lineItemId: string
  currentQuantity: number
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const mutation = useOrderMutation(orderId, (params: { quantity: number }) =>
    adminClient.orders.items.update(orderId, lineItemId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { quantity: Number(fd.get('quantity')) || 1 },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.edit_quantity.title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.edit_quantity.description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="edit-quantity">Quantity</FieldLabel>
                <Input
                  id="edit-quantity"
                  name="quantity"
                  type="number"
                  min={1}
                  defaultValue={currentQuantity}
                />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function LineItemsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const confirm = useConfirm()

  const items = order.items ?? []
  const [addOpen, setAddOpen] = useState(false)
  const [editItem, setEditItem] = useState<{ id: string; quantity: number } | null>(null)

  const deleteMutation = useOrderMutation(orderId, (lineItemId: string) =>
    adminClient.orders.items.delete(orderId, lineItemId),
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <ShoppingCartIcon className="size-4" />
            {t('admin.pages.orders.detail.section_items')}
            {items.length > 0 && <Badge variant="outline">{items.length}</Badge>}
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon data-icon="inline-start" />
              {t('admin.actions.add')}
            </Button>
          </CardAction>
        </CardHeader>
        {items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-muted-foreground">
                  <th className="p-3 pl-5 text-left font-normal">
                    {t('admin.orders.detail.items_table.item')}
                  </th>
                  <th className="p-3 text-right font-normal">
                    {t('admin.orders.detail.items_table.price')}
                  </th>
                  <th className="p-3 text-right font-normal">
                    {t('admin.orders.detail.items_table.qty')}
                  </th>
                  <th className="p-3 text-right font-normal">
                    {t('admin.orders.detail.items_table.tax')}
                  </th>
                  <th className="p-3 text-right font-normal">
                    {t('admin.orders.detail.items_table.discount')}
                  </th>
                  <th className="p-3 text-right font-normal">
                    {t('admin.orders.detail.items_table.total')}
                  </th>
                  <th className="p-3 pr-5 w-10" />
                </tr>
              </thead>
              <tbody>
                {items.map((item) => (
                  <tr key={item.id} className="border-b last:border-b-0">
                    <td className="p-3 pl-5">
                      <div className="flex items-center gap-3">
                        {item.thumbnail_url ? (
                          <img
                            src={item.thumbnail_url}
                            alt={item.name}
                            className="size-10 rounded-lg border object-cover"
                          />
                        ) : (
                          <div className="flex size-10 items-center justify-center rounded-lg border bg-muted">
                            <PackageIcon className="size-4 text-muted-foreground" />
                          </div>
                        )}
                        <div className="min-w-0">
                          <div className="truncate font-medium">{item.name}</div>
                          {item.options_text && (
                            <div className="truncate text-xs text-muted-foreground">
                              {item.options_text}
                            </div>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="p-3 text-right whitespace-nowrap">{item.display_price}</td>
                    <td className="p-3 text-right">{item.quantity}</td>
                    <td className="p-3 text-right whitespace-nowrap">
                      {item.display_additional_tax_total}
                    </td>
                    <td className="p-3 text-right whitespace-nowrap">
                      {Number.parseFloat(item.discount_total) !== 0
                        ? item.display_discount_total
                        : '—'}
                    </td>
                    <td className="p-3 text-right font-medium whitespace-nowrap">
                      {item.display_total}
                    </td>
                    <td className="p-3 pr-5">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            onClick={() => setEditItem({ id: item.id, quantity: item.quantity })}
                          >
                            <PencilIcon className="size-4" />
                            {t('admin.orders.detail.dropdown.edit_quantity')}
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t('admin.orders.detail.confirm.remove_item_message'),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.actions.remove'),
                                })
                              ) {
                                deleteMutation.mutate(item.id)
                              }
                            }}
                          >
                            <TrashIcon className="size-4" />
                            {t('admin.actions.remove')}
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <CardContent>
            <p className="text-center text-muted-foreground py-8">No line items</p>
          </CardContent>
        )}
      </Card>

      <AddLineItemDialog orderId={orderId} open={addOpen} onOpenChange={setAddOpen} />

      {editItem && (
        <EditQuantityDialog
          orderId={orderId}
          lineItemId={editItem.id}
          currentQuantity={editItem.quantity}
          open={!!editItem}
          onOpenChange={(open) => !open && setEditItem(null)}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Shipments
// ---------------------------------------------------------------------------

function EditTrackingDialog({
  orderId,
  fulfillmentId,
  currentTracking,
  open,
  onOpenChange,
}: {
  orderId: string
  fulfillmentId: string
  currentTracking: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const mutation = useOrderMutation(orderId, (params: { tracking: string }) =>
    adminClient.orders.fulfillments.update(orderId, fulfillmentId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { tracking: fd.get('tracking') as string },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit Tracking</DialogTitle>
          <DialogDescription>{t('admin.orders.detail.tracking.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="tracking">
                  {t('admin.orders.detail.tracking.label')}
                </FieldLabel>
                <Input id="tracking" name="tracking" defaultValue={currentTracking ?? ''} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function ShipmentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const confirm = useConfirm()

  const fulfillments = order.fulfillments ?? []
  const [editTracking, setEditTracking] = useState<{
    id: string
    tracking: string | null
  } | null>(null)

  const fulfillMutation = useOrderMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.fulfill(orderId, fulfillmentId, {}),
  )
  const cancelFulfillmentMutation = useOrderMutation(orderId, (fulfillmentId: string) =>
    adminClient.orders.fulfillments.cancel(orderId, fulfillmentId, {}),
  )

  if (fulfillments.length === 0) return null

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <TruckIcon className="size-4" />
            {t('admin.pages.orders.detail.section_shipments')}
            <Badge variant="outline">{fulfillments.length}</Badge>
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {fulfillments.map((fulfillment) => (
            <div key={fulfillment.id} className="rounded-lg border p-4 flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <StatusBadge status={fulfillment.status} />
                  <span className="text-sm font-medium">{fulfillment.number}</span>
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs">
                      <EllipsisVerticalIcon className="size-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem
                      onClick={() =>
                        setEditTracking({ id: fulfillment.id, tracking: fulfillment.tracking })
                      }
                    >
                      <PencilIcon className="size-4" />
                      {fulfillment.tracking ? 'Edit Tracking' : 'Add Tracking'}
                    </DropdownMenuItem>
                    {fulfillment.status === 'ready' && (
                      <DropdownMenuItem
                        onClick={async () => {
                          if (
                            await confirm({
                              message: t('admin.orders.detail.confirm.ship_message'),
                              variant: 'default',
                              confirmLabel: t('admin.pages.orders.detail.actions.ship'),
                            })
                          ) {
                            fulfillMutation.mutate(fulfillment.id)
                          }
                        }}
                      >
                        <TruckIcon className="size-4" />
                        {t('admin.pages.orders.detail.actions.ship')}
                      </DropdownMenuItem>
                    )}
                    {['pending', 'ready'].includes(fulfillment.status) && (
                      <>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          className="text-destructive focus:text-destructive"
                          onClick={async () => {
                            if (
                              await confirm({
                                message: t('admin.orders.detail.confirm.cancel_shipment_message'),
                                variant: 'destructive',
                                confirmLabel: t('admin.actions.cancel'),
                              })
                            ) {
                              cancelFulfillmentMutation.mutate(fulfillment.id)
                            }
                          }}
                        >
                          <XCircleIcon className="size-4" />
                          {t('admin.actions.cancel')}
                        </DropdownMenuItem>
                      </>
                    )}
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              {fulfillment.delivery_method && (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">{fulfillment.delivery_method.name}</span>
                  <span>{fulfillment.display_cost}</span>
                </div>
              )}

              {fulfillment.stock_location && (
                <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                  <MapPinIcon className="size-3" />
                  {fulfillment.stock_location.name}
                </div>
              )}

              {fulfillment.tracking && (
                <div className="text-sm">
                  <span className="text-muted-foreground">
                    {t('admin.orders.detail.tracking.prefix')}:{' '}
                  </span>
                  {fulfillment.tracking_url ? (
                    <a
                      href={fulfillment.tracking_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:underline"
                    >
                      {fulfillment.tracking}
                    </a>
                  ) : (
                    <span>{fulfillment.tracking}</span>
                  )}
                </div>
              )}

              {fulfillment.fulfilled_at && (
                <span className="text-xs text-muted-foreground">
                  <RelativeTime
                    iso={fulfillment.fulfilled_at}
                    prefix={t('admin.orders.detail.tracking.shipped_prefix')}
                    fallback=""
                  />
                </span>
              )}
            </div>
          ))}
        </CardContent>
      </Card>

      {editTracking && (
        <EditTrackingDialog
          orderId={orderId}
          fulfillmentId={editTracking.id}
          currentTracking={editTracking.tracking}
          open={!!editTracking}
          onOpenChange={(open) => !open && setEditTracking(null)}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Payments
// ---------------------------------------------------------------------------

function PaymentsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const confirm = useConfirm()
  const [addOpen, setAddOpen] = useState(false)

  const payments = order.payments ?? []

  const captureMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.capture(orderId, paymentId, {}),
  )
  const voidMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.void(orderId, paymentId, {}),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <CreditCardIcon className="size-4" />
          {t('admin.pages.orders.detail.section_payments')}
          {payments.length > 0 && <Badge variant="outline">{payments.length}</Badge>}
        </CardTitle>
        <CardAction className="flex items-center gap-2">
          {order.payment_status && <StatusBadge status={order.payment_status} />}
          <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
            <PlusIcon data-icon="inline-start" />
            {t('admin.actions.add')}
          </Button>
        </CardAction>
      </CardHeader>
      {payments.length === 0 ? (
        <CardContent>
          <p className="text-center text-muted-foreground py-8">
            {t('admin.pages.orders.detail.empty_payments')}
          </p>
        </CardContent>
      ) : (
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b bg-muted/50 text-muted-foreground">
                <th className="p-3 pl-5 text-left font-normal">
                  {t('admin.orders.detail.payments_table.number')}
                </th>
                <th className="p-3 text-left font-normal">
                  {t('admin.orders.detail.payments_table.method')}
                </th>
                <th className="p-3 text-left font-normal">
                  {t('admin.orders.detail.payments_table.state')}
                </th>
                <th className="p-3 text-right font-normal">
                  {t('admin.orders.detail.payments_table.amount')}
                </th>
                <th className="p-3 pr-5 w-10" />
              </tr>
            </thead>
            <tbody>
              {payments.map((payment) => (
                <tr key={payment.id} className="border-b last:border-b-0">
                  <td className="p-3 pl-5 font-medium">{payment.number}</td>
                  <td className="p-3 text-muted-foreground">
                    {payment.payment_method?.name ?? '—'}
                  </td>
                  <td className="p-3">
                    <StatusBadge status={payment.status} />
                  </td>
                  <td className="p-3 text-right font-medium whitespace-nowrap">
                    {payment.display_amount}
                  </td>
                  <td className="p-3 pr-5">
                    {(payment.status === 'checkout' ||
                      payment.status === 'pending' ||
                      payment.status === 'completed') && (
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          {(payment.status === 'checkout' || payment.status === 'pending') && (
                            <DropdownMenuItem
                              onClick={async () => {
                                if (
                                  await confirm({
                                    message: t('admin.orders.detail.confirm.capture_message'),
                                    variant: 'default',
                                    confirmLabel: t('admin.pages.orders.detail.actions.capture'),
                                  })
                                ) {
                                  captureMutation.mutate(payment.id)
                                }
                              }}
                            >
                              <CreditCardIcon className="size-4" />
                              {t('admin.pages.orders.detail.actions.capture')}
                            </DropdownMenuItem>
                          )}
                          {(payment.status === 'checkout' ||
                            payment.status === 'pending' ||
                            payment.status === 'completed') && (
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onClick={async () => {
                                if (
                                  await confirm({
                                    message: t('admin.orders.detail.confirm.void_message'),
                                    variant: 'destructive',
                                    confirmLabel: t('admin.pages.orders.detail.actions.void'),
                                  })
                                ) {
                                  voidMutation.mutate(payment.id)
                                }
                              }}
                            >
                              <XCircleIcon className="size-4" />
                              {t('admin.pages.orders.detail.actions.void')}
                            </DropdownMenuItem>
                          )}
                        </DropdownMenuContent>
                      </DropdownMenu>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <AddPaymentDialog order={order} open={addOpen} onOpenChange={setAddOpen} />
    </Card>
  )
}

function AddPaymentDialog({
  order,
  open,
  onOpenChange,
}: {
  order: Order
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const orderId = order.id
  const customerId = order.customer_id ?? undefined
  const [paymentMethodId, setPaymentMethodId] = useState<string>('')
  const [sourceId, setSourceId] = useState<string>('')
  const [amount, setAmount] = useState<string>(order.amount_due ?? '')
  const [capture, setCapture] = useState(false)

  // Re-seed amount from outstanding balance whenever the dialog opens.
  useEffect(() => {
    if (open) setAmount(order.amount_due ?? '')
  }, [open, order.amount_due])

  const { data: methodsData } = useQuery({
    queryKey: ['payment-methods'],
    queryFn: () => adminClient.paymentMethods.list({ limit: 50 }),
    enabled: open,
    staleTime: 60_000,
  })
  const paymentMethods = methodsData?.data ?? []
  const selectedMethod = paymentMethods.find((m) => m.id === paymentMethodId)
  const sourceRequired = selectedMethod?.source_required ?? false

  const { data: cardsData } = useQuery({
    queryKey: ['customer-credit-cards', customerId],
    queryFn: () =>
      customerId
        ? adminClient.customers.creditCards.list(customerId, { limit: 50 })
        : Promise.resolve(null),
    enabled: open && Boolean(customerId) && sourceRequired,
    staleTime: 30_000,
  })
  const savedCards = cardsData?.data ?? []
  const canSubmit = Boolean(paymentMethodId) && (!sourceRequired || Boolean(sourceId))

  const mutation = useOrderMutation(orderId, () =>
    adminClient.orders.payments.create(orderId, {
      payment_method_id: paymentMethodId,
      ...(sourceId ? { source_id: sourceId } : {}),
      ...(amount ? { amount: Number(amount) } : {}),
    }),
  )

  const captureMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.capture(orderId, paymentId, {}),
  )

  function reset() {
    setPaymentMethodId('')
    setSourceId('')
    setAmount('')
    setCapture(false)
  }

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    if (!canSubmit) return

    mutation.mutate(undefined, {
      onSuccess: (payment) => {
        if (capture && payment && (payment as { id?: string }).id) {
          captureMutation.mutate((payment as { id: string }).id, {
            onSuccess: () => {
              onOpenChange(false)
              reset()
            },
          })
        } else {
          onOpenChange(false)
          reset()
        }
      },
    })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Payment</DialogTitle>
          <DialogDescription>{t('admin.orders.detail.payment_form.description')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="pay-method">
                  {t('admin.orders.detail.payment_form.method_label')}
                </FieldLabel>
                <Select
                  value={paymentMethodId}
                  onValueChange={(v) => {
                    setPaymentMethodId(v)
                    setSourceId('')
                  }}
                >
                  <SelectTrigger id="pay-method">
                    <SelectValue
                      placeholder={t('admin.orders.detail.payment_form.method_placeholder')}
                    >
                      {(value) =>
                        paymentMethods.find((m) => m.id === value)?.name ??
                        t('admin.orders.detail.payment_form.method_placeholder')
                      }
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {paymentMethods.map((m) => (
                      <SelectItem key={m.id} value={m.id}>
                        {m.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>

              {sourceRequired && (
                <Field>
                  <FieldLabel htmlFor="pay-source">
                    {t('admin.orders.detail.payment_form.source_label')}
                  </FieldLabel>
                  {!customerId ? (
                    <p className="text-sm text-destructive">
                      This payment method requires a saved source. Assign a customer to the order
                      first.
                    </p>
                  ) : savedCards.length === 0 ? (
                    <p className="text-sm text-muted-foreground">
                      Customer has no saved cards for this payment method.
                    </p>
                  ) : (
                    <Select value={sourceId} onValueChange={setSourceId}>
                      <SelectTrigger id="pay-source">
                        <SelectValue placeholder="Choose a saved card…">
                          {(value) => {
                            const card = savedCards.find((c) => c.id === value)
                            return card
                              ? `${card.brand} •••• ${card.last4} (${card.month}/${card.year})`
                              : 'Choose a saved card…'
                          }}
                        </SelectValue>
                      </SelectTrigger>
                      <SelectContent>
                        {savedCards.map((c) => (
                          <SelectItem key={c.id} value={c.id}>
                            {c.brand} •••• {c.last4} ({c.month}/{c.year})
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                </Field>
              )}

              <Field>
                <FieldLabel htmlFor="pay-amount">Amount</FieldLabel>
                <Input
                  id="pay-amount"
                  type="number"
                  step="0.01"
                  placeholder={order.amount_due ?? '0.00'}
                  value={amount}
                  onChange={(e) => setAmount(e.target.value)}
                />
                <p className="text-xs text-muted-foreground mt-1">
                  {t('admin.orders.detail.payment_form.amount_help')}
                </p>
              </Field>

              <Field>
                <label className="flex items-center gap-2 text-sm" htmlFor="pay-capture">
                  <Switch id="pay-capture" checked={capture} onCheckedChange={setCapture} />
                  {t('admin.orders.detail.payment_form.capture_immediately')}
                </label>
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button
              type="submit"
              disabled={!canSubmit || mutation.isPending || captureMutation.isPending}
            >
              {mutation.isPending || captureMutation.isPending
                ? t('admin.actions.saving')
                : t('admin.actions.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------
// Order Summary
// ---------------------------------------------------------------------------

function SummaryRow({
  label,
  value,
  bold,
  danger,
  highlight,
}: {
  label: string
  value: string
  bold?: boolean
  danger?: boolean
  highlight?: boolean
}) {
  return (
    <div
      className={cn('flex items-center justify-between px-5 py-2.5', highlight && 'bg-muted/50')}
    >
      <span className="text-sm">{label}</span>
      <span className={cn('text-sm', bold && 'font-bold', danger && 'text-destructive')}>
        {value}
      </span>
    </div>
  )
}

function OrderSummaryCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const outstandingBalance = Number.parseFloat(order.amount_due ?? '0')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.orders.detail.section_summary')}</CardTitle>
      </CardHeader>
      <div className="py-1">
        {order.created_by && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.created_by')}
            value={order.created_by.full_name || order.created_by.email}
          />
        )}
        <SummaryRow
          label={t('admin.pages.orders.detail.summary.created_at')}
          value={formatDate(order.created_at)}
        />

        {order.completed_at && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.completed_at')}
            value={formatDate(order.completed_at)}
          />
        )}

        {order.canceled_at && (
          <>
            <SummaryRow
              label={t('admin.orders.detail.summary.canceled_at')}
              value={formatDate(order.canceled_at)}
            />
            {order.canceler && (
              <SummaryRow
                label={t('admin.orders.detail.summary.canceler')}
                value={order.canceler.full_name || order.canceler.email}
              />
            )}
          </>
        )}

        {order.approved_at && order.approver && (
          <SummaryRow
            label={t('admin.orders.detail.summary.approved_by')}
            value={order.approver.full_name || order.approver.email}
          />
        )}

        <Separator />

        {order.market && (
          <SummaryRow
            label={t('admin.pages.orders.detail.summary.market')}
            value={order.market.name ?? order.market_id ?? '—'}
          />
        )}
        <SummaryRow
          label={t('admin.pages.orders.detail.summary.locale')}
          value={order.locale ?? '—'}
        />
        <SummaryRow
          label={t('admin.pages.orders.detail.summary.currency')}
          value={order.currency}
        />

        <Separator />

        <SummaryRow label={t('admin.fields.subtotal.label')} value={order.display_item_total} />

        {Number.parseFloat(order.delivery_total) > 0 && (
          <SummaryRow
            label={t('admin.fields.shipping.label')}
            value={order.display_delivery_total}
          />
        )}

        {Number.parseFloat(order.discount_total) !== 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.promotions')}
            value={order.display_discount_total}
          />
        )}

        {Number.parseFloat(order.adjustment_total) !== 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.adjustments')}
            value={order.display_adjustment_total}
          />
        )}

        {Number.parseFloat(order.included_tax_total) > 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_included')}
            value={order.display_included_tax_total}
          />
        )}

        {Number.parseFloat(order.additional_tax_total) > 0 && (
          <SummaryRow
            label={t('admin.orders.detail.summary.tax_additional')}
            value={order.display_additional_tax_total}
          />
        )}

        <Separator />

        <SummaryRow label={t('admin.fields.total.label')} value={order.display_total} bold />

        <Separator />

        <SummaryRow
          label={t('admin.orders.detail.summary.payment_total')}
          value={order.display_payment_total}
          highlight
        />
        <SummaryRow
          label={t('admin.orders.detail.summary.outstanding_balance')}
          value={order.display_amount_due}
          highlight
          danger={outstandingBalance > 0}
        />
      </div>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Discounts: Gift Card + Store Credit
// ---------------------------------------------------------------------------

function DiscountsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const confirm = useConfirm()
  const [giftCardOpen, setGiftCardOpen] = useState(false)

  const removeGiftCardMutation = useOrderMutation(orderId, () =>
    adminClient.orders.giftCards.remove(orderId, order.gift_card?.id ?? ''),
  )
  const applyStoreCreditMutation = useOrderMutation(orderId, () =>
    adminClient.orders.storeCredits.apply(orderId),
  )
  const removeStoreCreditMutation = useOrderMutation(orderId, () =>
    adminClient.orders.storeCredits.remove(orderId),
  )

  const hasStoreCredit = Number.parseFloat(order.store_credit_total ?? '0') > 0
  const hasCustomer = Boolean(order.customer_id)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.orders.detail.gift_card_section.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          {/* Gift card */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-col">
              <span className="text-sm font-medium">
                {t('admin.orders.detail.gift_card_section.gift_card_label')}
              </span>
              {order.gift_card ? (
                <span className="text-xs text-muted-foreground">
                  {order.gift_card.code} · {order.display_gift_card_total}
                </span>
              ) : (
                <span className="text-xs text-muted-foreground">
                  {t('admin.orders.detail.gift_card_section.none_applied')}
                </span>
              )}
            </div>
            {order.gift_card ? (
              <Button
                size="sm"
                variant="outline"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.remove_gift_card_message'),
                      confirmLabel: t('admin.actions.remove'),
                    })
                  ) {
                    removeGiftCardMutation.mutate(undefined)
                  }
                }}
                disabled={removeGiftCardMutation.isPending}
              >
                {t('admin.actions.remove')}
              </Button>
            ) : (
              <Button size="sm" variant="outline" onClick={() => setGiftCardOpen(true)}>
                <PlusIcon className="size-4" />
                {t('admin.orders.detail.gift_card_section.apply_button')}
              </Button>
            )}
          </div>

          <Separator />

          {/* Store credit */}
          <div className="flex items-center justify-between gap-2">
            <div className="flex flex-col">
              <span className="text-sm font-medium">
                {t('admin.orders.detail.gift_card_section.store_credit_label')}
              </span>
              {hasStoreCredit ? (
                <span className="text-xs text-muted-foreground">
                  {order.display_store_credit_total}{' '}
                  {t('admin.orders.detail.gift_card_section.applied_suffix')}
                </span>
              ) : (
                <span className="text-xs text-muted-foreground">
                  {hasCustomer
                    ? t('admin.orders.detail.gift_card_section.apply_balance')
                    : t('admin.orders.detail.gift_card_section.requires_customer')}
                </span>
              )}
            </div>
            {hasStoreCredit ? (
              <Button
                size="sm"
                variant="outline"
                onClick={async () => {
                  if (
                    await confirm({
                      message: t('admin.orders.detail.confirm.remove_store_credit_message'),
                      confirmLabel: t('admin.actions.remove'),
                    })
                  ) {
                    removeStoreCreditMutation.mutate(undefined)
                  }
                }}
                disabled={removeStoreCreditMutation.isPending}
              >
                {t('admin.actions.remove')}
              </Button>
            ) : (
              <Button
                size="sm"
                variant="outline"
                disabled={!hasCustomer || applyStoreCreditMutation.isPending}
                onClick={() => applyStoreCreditMutation.mutate(undefined)}
              >
                <PlusIcon className="size-4" />
                {t('admin.orders.detail.gift_card_section.apply_button')}
              </Button>
            )}
          </div>
        </CardContent>
      </Card>

      <ApplyGiftCardDialog orderId={orderId} open={giftCardOpen} onOpenChange={setGiftCardOpen} />
    </>
  )
}

function ApplyGiftCardDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const mutation = useOrderMutation(orderId, (params: { code: string }) =>
    adminClient.orders.giftCards.apply(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    const code = (fd.get('code') as string).trim()
    if (!code) return
    mutation.mutate({ code }, { onSuccess: () => onOpenChange(false) })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.orders.detail.gift_card_section.apply_dialog_title')}</DialogTitle>
          <DialogDescription>
            {t('admin.orders.detail.gift_card_section.apply_dialog_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="gift-card-code">Code</FieldLabel>
                <Input
                  id="gift-card-code"
                  name="code"
                  placeholder="GIFT-XXXX-YYYY"
                  required
                  autoFocus
                />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.add')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

// ---------------------------------------------------------------------------
// Customer Sidebar
// ---------------------------------------------------------------------------

function CustomerCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const queryClient = useQueryClient()
  const customer = order.customer
  const [editAddress, setEditAddress] = useState<'shipping_address' | 'billing_address' | null>(
    null,
  )

  const addressMutation = useMutation({
    mutationFn: (params: {
      type: 'shipping_address' | 'billing_address'
      address: AddressParams
    }) => adminClient.orders.update(orderId, { [params.type]: params.address } as any),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['order', orderId] })
      setEditAddress(null)
    },
  })

  const editTitle =
    editAddress === 'shipping_address'
      ? t('admin.orders.detail.address_edit.shipping_title')
      : t('admin.orders.detail.address_edit.billing_title')

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.orders.detail.section_customer')}</CardTitle>
          <CardAction>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-xs">
                  <EllipsisVerticalIcon className="size-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => setEditAddress('shipping_address')}>
                  <PencilIcon className="size-4" />
                  {t('admin.orders.detail.address_edit.shipping_title')}
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => setEditAddress('billing_address')}>
                  <PencilIcon className="size-4" />
                  {t('admin.orders.detail.address_edit.billing_title')}
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          {/* Contact info */}
          {customer ? (
            <div className="flex items-center gap-3 rounded-xl bg-muted p-3">
              <Avatar>
                <AvatarFallback>{getInitials(customer.full_name, customer.email)}</AvatarFallback>
              </Avatar>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">{customer.full_name}</div>
                <div className="truncate text-xs text-muted-foreground">{customer.email}</div>
              </div>
            </div>
          ) : order.email ? (
            <div className="text-sm text-blue-600">{order.email}</div>
          ) : (
            <span className="text-sm text-muted-foreground">
              {t('admin.orders.detail.no_customer')}
            </span>
          )}

          <AddressBlock
            title={t('admin.pages.orders.detail.section_shipping_address')}
            address={order.shipping_address}
          />
          <AddressBlock
            title={t('admin.pages.orders.detail.section_billing_address')}
            address={order.billing_address}
          />
        </CardContent>
      </Card>

      {editAddress && (
        <AddressFormDialog
          title={editTitle}
          address={
            editAddress === 'shipping_address' ? order.shipping_address : order.billing_address
          }
          open={!!editAddress}
          onOpenChange={(open) => !open && setEditAddress(null)}
          onSave={(address) => addressMutation.mutate({ type: editAddress, address })}
          isPending={addressMutation.isPending}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Special Instructions
// ---------------------------------------------------------------------------

function SpecialInstructionsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()

  const [editing, setEditing] = useState(false)
  const mutation = useOrderMutation(orderId, (params: { customer_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { customer_note: fd.get('customer_note') as string },
      { onSuccess: () => setEditing(false) },
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.section_customer_note')}</CardTitle>
        <CardAction>
          <Button variant="ghost" size="icon-xs" onClick={() => setEditing(!editing)}>
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <Textarea name="customer_note" defaultValue={order.customer_note ?? ''} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : order.customer_note ? (
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">{order.customer_note}</p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Tags
// ---------------------------------------------------------------------------

function TagsCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()
  const [editing, setEditing] = useState(false)
  const [tags, setTags] = useState<string[]>(order.tags ?? [])

  const mutation = useOrderMutation(orderId, (params: { tags: string[] }) =>
    adminClient.orders.update(orderId, params),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.customers.detail.section_tags')}</CardTitle>
        <CardAction>
          <Button
            variant="ghost"
            size="icon-xs"
            onClick={() => {
              setTags(order.tags ?? [])
              setEditing(!editing)
            }}
          >
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <div className="flex flex-col gap-3">
            <TagCombobox taggableType="Spree::Order" value={tags} onChange={setTags} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                size="sm"
                disabled={mutation.isPending}
                onClick={() => mutation.mutate({ tags }, { onSuccess: () => setEditing(false) })}
              >
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </div>
        ) : order.tags?.length ? (
          <div className="flex flex-wrap gap-1">
            {order.tags.map((tag) => (
              <Badge key={tag}>{tag}</Badge>
            ))}
          </div>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Internal Note
// ---------------------------------------------------------------------------

function InternalNoteCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  const { orderId } = Route.useParams()

  const [editing, setEditing] = useState(false)
  const mutation = useOrderMutation(orderId, (params: { internal_note: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { internal_note: fd.get('internal_note') as string },
      { onSuccess: () => setEditing(false) },
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.orders.detail.section_internal_note')}</CardTitle>
        <CardAction>
          <Button variant="ghost" size="icon-xs" onClick={() => setEditing(!editing)}>
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <Textarea name="internal_note" defaultValue={order.internal_note ?? ''} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
              </Button>
            </div>
          </form>
        ) : order.internal_note ? (
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">{order.internal_note}</p>
        ) : (
          <p className="text-sm text-muted-foreground">{t('admin.common.none')}</p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function OrderSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Skeleton className="size-8 rounded-lg" />
        <Skeleton className="h-8 w-40" />
        <Skeleton className="h-5 w-16 rounded-md" />
        <Skeleton className="h-5 w-16 rounded-md" />
      </div>
      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <Skeleton className="h-64 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
        </div>
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <Skeleton className="h-64 w-full rounded-xl" />
        </div>
      </div>
    </div>
  )
}
