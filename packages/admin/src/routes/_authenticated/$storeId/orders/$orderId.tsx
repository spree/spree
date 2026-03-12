import type { Address, Order } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import {
  ArrowLeftIcon,
  CreditCardIcon,
  EllipsisVerticalIcon,
  ExternalLinkIcon,
  MailIcon,
  MapPinIcon,
  PackageIcon,
  PencilIcon,
  PlusIcon,
  ShoppingCartIcon,
  SlidersHorizontalIcon,
  TrashIcon,
  TruckIcon,
  XCircleIcon,
} from 'lucide-react'
import { type FormEvent, useState } from 'react'
import { adminClient } from '@/client'
import { Badge, StatusBadge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardAction, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import {
  Dialog,
  DialogBody,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Separator } from '@/components/ui/separator'
import { Skeleton } from '@/components/ui/skeleton'
import { Textarea } from '@/components/ui/textarea'
import { useAuth } from '@/hooks/use-auth'
import { cn } from '@/lib/utils'

export const Route = createFileRoute('/_authenticated/$storeId/orders/$orderId')({
  component: OrderDetailPage,
})

// ---------------------------------------------------------------------------
// Data hooks
// ---------------------------------------------------------------------------

function useOrder(orderId: string) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: ['order', orderId],
    queryFn: () =>
      adminClient.orders.get(orderId, {
        expand: [
          'line_items',
          'shipments',
          'shipments.shipping_method',
          'shipments.stock_location',
          'payments',
          'payments.payment_method',
          'bill_address',
          'ship_address',
          'user',
          'adjustments',
        ],
      }),
    enabled: isAuthenticated,
  })
}

/** Wrapper for mutations that invalidate the order query on success */
function useOrderMutation<TParams>(
  orderId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['order', orderId] }),
  })
}

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

function timeAgo(iso: string | null) {
  if (!iso) return ''
  const diff = Date.now() - new Date(iso).getTime()
  const minutes = Math.floor(diff / 60000)
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  const days = Math.floor(hours / 24)
  return `${days}d ago`
}

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function OrderDetailPage() {
  const { orderId } = Route.useParams()
  const { data: order, isLoading, error } = useOrder(orderId)

  if (isLoading) return <OrderSkeleton />
  if (error || !order) return <p className="text-destructive">Failed to load order {orderId}.</p>

  return (
    <div className="flex flex-col gap-6">
      <OrderHeader order={order} />

      <div className="grid grid-cols-12 gap-6">
        {/* Main content */}
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <LineItemsCard order={order} />
          <ShipmentsCard order={order} />
          <PaymentsCard order={order} />
          <AdjustmentsCard order={order} />
          <OrderSummaryCard order={order} />
        </div>

        {/* Sidebar */}
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <CustomerCard order={order} />
          <SpecialInstructionsCard order={order} />
          <InternalNoteCard order={order} />
        </div>
      </div>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

function OrderHeader({ order }: { order: Order }) {
  const { orderId, storeId } = Route.useParams()

  const backPath = order.completed_at ? '/$storeId/orders' : '/$storeId/orders/drafts'

  const cancelMutation = useOrderMutation(orderId, () =>
    adminClient.orders.cancel(orderId, {}),
  )
  const resendMutation = useOrderMutation(orderId, () =>
    adminClient.orders.resendConfirmation(orderId, {}),
  )

  return (
    <div className="flex items-center gap-3">
      <Link
        to={backPath}
        params={{ storeId }}
        search={{ filters: [], columns: [] }}
        className="inline-flex items-center justify-center rounded-lg p-1.5 text-muted-foreground hover:bg-gray-200/50 hover:text-foreground transition-colors"
      >
        <ArrowLeftIcon className="size-5" />
      </Link>

      <h1 className="text-2xl font-medium">{order.number}</h1>

      {order.payment_state && <StatusBadge status={order.payment_state} />}
      {order.shipment_state && <StatusBadge status={order.shipment_state} />}

      {order.completed_at && (
        <span className="text-sm text-muted-foreground">
          Completed {timeAgo(order.completed_at)}
        </span>
      )}

      <div className="ml-auto">
        <DropdownMenu>
          <DropdownMenuTrigger asChild>
            <Button variant="outline" size="icon-sm">
              <EllipsisVerticalIcon className="size-4" />
            </Button>
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            {order.completed_at && (
              <>
                <DropdownMenuItem>
                  <ExternalLinkIcon className="size-4" />
                  Preview Order
                </DropdownMenuItem>
                <DropdownMenuItem
                  onClick={() => resendMutation.mutate(undefined)}
                  disabled={resendMutation.isPending}
                >
                  <MailIcon className="size-4" />
                  Resend Confirmation
                </DropdownMenuItem>
                <DropdownMenuSeparator />
              </>
            )}
            {order.state !== 'canceled' && (
              <DropdownMenuItem
                className="text-destructive focus:text-destructive"
                onClick={() => {
                  if (window.confirm('Are you sure you want to cancel this order?')) {
                    cancelMutation.mutate(undefined)
                  }
                }}
                disabled={cancelMutation.isPending}
              >
                <XCircleIcon className="size-4" />
                Cancel Order
              </DropdownMenuItem>
            )}
          </DropdownMenuContent>
        </DropdownMenu>
      </div>
    </div>
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

  const mutation = useOrderMutation(orderId, (params: { variant_id: string; quantity: number }) =>
    adminClient.orders.lineItems.create(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { variant_id: fd.get('variant_id') as string, quantity: Number(fd.get('quantity')) || 1 },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Line Item</DialogTitle>
          <DialogDescription>Add a product variant to this order.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="variant_id">Variant ID</FieldLabel>
                <Input id="variant_id" name="variant_id" placeholder="variant_xxx" required />
              </Field>
              <Field>
                <FieldLabel htmlFor="quantity">Quantity</FieldLabel>
                <Input id="quantity" name="quantity" type="number" min={1} defaultValue={1} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Adding…' : 'Add Item'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
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

  const mutation = useOrderMutation(orderId, (params: { quantity: number }) =>
    adminClient.orders.lineItems.update(orderId, lineItemId, params),
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
          <DialogTitle>Edit Quantity</DialogTitle>
          <DialogDescription>Update the quantity for this line item.</DialogDescription>
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
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function LineItemsCard({ order }: { order: Order }) {
  const { orderId } = Route.useParams()

  const items = order.line_items ?? []
  const [addOpen, setAddOpen] = useState(false)
  const [editItem, setEditItem] = useState<{ id: string; quantity: number } | null>(null)

  const deleteMutation = useOrderMutation(orderId, (lineItemId: string) =>
    adminClient.orders.lineItems.delete(orderId, lineItemId),
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <ShoppingCartIcon className="size-4" />
            Line Items
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            {items.length > 0 && <Badge variant="info">{items.length}</Badge>}
            <Button size="sm" variant="secondary" onClick={() => setAddOpen(true)}>
              <PlusIcon data-icon="inline-start" />
              Add Item
            </Button>
          </CardAction>
        </CardHeader>
        {items.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-muted-foreground">
                  <th className="p-3 pl-5 text-left font-normal">Item</th>
                  <th className="p-3 text-right font-normal">Price</th>
                  <th className="p-3 text-right font-normal">Qty</th>
                  <th className="p-3 text-right font-normal">Tax</th>
                  <th className="p-3 text-right font-normal">Discount</th>
                  <th className="p-3 text-right font-normal">Total</th>
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
                      {Number.parseFloat(item.promo_total) !== 0 ? item.display_promo_total : '—'}
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
                            Edit Quantity
                          </DropdownMenuItem>
                          <DropdownMenuSeparator />
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={() => {
                              if (window.confirm('Remove this item from the order?')) {
                                deleteMutation.mutate(item.id)
                              }
                            }}
                          >
                            <TrashIcon className="size-4" />
                            Remove
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
  shipmentId,
  currentTracking,
  open,
  onOpenChange,
}: {
  orderId: string
  shipmentId: string
  currentTracking: string | null
  open: boolean
  onOpenChange: (open: boolean) => void
}) {

  const mutation = useOrderMutation(orderId, (params: { tracking: string }) =>
    adminClient.orders.shipments.update(orderId, shipmentId, params),
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
          <DialogDescription>Update the tracking number for this shipment.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="tracking">Tracking Number</FieldLabel>
                <Input id="tracking" name="tracking" defaultValue={currentTracking ?? ''} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function ShipmentsCard({ order }: { order: Order }) {
  const { orderId } = Route.useParams()

  const shipments = order.shipments ?? []
  const [editTracking, setEditTracking] = useState<{
    id: string
    tracking: string | null
  } | null>(null)

  const shipMutation = useOrderMutation(orderId, (shipmentId: string) =>
    adminClient.orders.shipments.ship(orderId, shipmentId, {}),
  )
  const cancelShipmentMutation = useOrderMutation(orderId, (shipmentId: string) =>
    adminClient.orders.shipments.cancel(orderId, shipmentId, {}),
  )

  if (shipments.length === 0) return null

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <TruckIcon className="size-4" />
            Shipments
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            <Badge variant="info">{shipments.length}</Badge>
            {order.shipment_state && <StatusBadge status={order.shipment_state} />}
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-4">
          {shipments.map((shipment) => (
            <div key={shipment.id} className="rounded-lg border p-4 flex flex-col gap-3">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <StatusBadge status={shipment.state} />
                  <span className="text-sm font-medium">{shipment.number}</span>
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
                        setEditTracking({ id: shipment.id, tracking: shipment.tracking })
                      }
                    >
                      <PencilIcon className="size-4" />
                      {shipment.tracking ? 'Edit Tracking' : 'Add Tracking'}
                    </DropdownMenuItem>
                    {shipment.state === 'ready' && (
                      <DropdownMenuItem
                        onClick={() => {
                          if (window.confirm('Ship this shipment?')) {
                            shipMutation.mutate(shipment.id)
                          }
                        }}
                      >
                        <TruckIcon className="size-4" />
                        Ship
                      </DropdownMenuItem>
                    )}
                    {['pending', 'ready'].includes(shipment.state) && (
                      <>
                        <DropdownMenuSeparator />
                        <DropdownMenuItem
                          className="text-destructive focus:text-destructive"
                          onClick={() => {
                            if (window.confirm('Cancel this shipment?')) {
                              cancelShipmentMutation.mutate(shipment.id)
                            }
                          }}
                        >
                          <XCircleIcon className="size-4" />
                          Cancel Shipment
                        </DropdownMenuItem>
                      </>
                    )}
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>

              {shipment.shipping_method && (
                <div className="flex items-center justify-between text-sm">
                  <span className="text-muted-foreground">{shipment.shipping_method.name}</span>
                  <span>{shipment.display_cost}</span>
                </div>
              )}

              {shipment.stock_location && (
                <div className="flex items-center gap-1.5 text-xs text-muted-foreground">
                  <MapPinIcon className="size-3" />
                  {shipment.stock_location.name}
                </div>
              )}

              {shipment.tracking && (
                <div className="text-sm">
                  <span className="text-muted-foreground">Tracking: </span>
                  {shipment.tracking_url ? (
                    <a
                      href={shipment.tracking_url}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-blue-600 hover:underline"
                    >
                      {shipment.tracking}
                    </a>
                  ) : (
                    <span>{shipment.tracking}</span>
                  )}
                </div>
              )}

              {shipment.shipped_at && (
                <span className="text-xs text-muted-foreground">
                  Shipped {timeAgo(shipment.shipped_at)}
                </span>
              )}
            </div>
          ))}
        </CardContent>
      </Card>

      {editTracking && (
        <EditTrackingDialog
          orderId={orderId}
          shipmentId={editTracking.id}
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
  const { orderId } = Route.useParams()

  const payments = order.payments ?? []

  const captureMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.capture(orderId, paymentId, {}),
  )
  const voidMutation = useOrderMutation(orderId, (paymentId: string) =>
    adminClient.orders.payments.void(orderId, paymentId, {}),
  )

  if (payments.length === 0) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          <CreditCardIcon className="size-4" />
          Payments
        </CardTitle>
        <CardAction className="flex items-center gap-2">
          <Badge variant="info">{payments.length}</Badge>
          {order.payment_state && <StatusBadge status={order.payment_state} />}
        </CardAction>
      </CardHeader>
      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b bg-muted/50 text-muted-foreground">
              <th className="p-3 pl-5 text-left font-normal">Number</th>
              <th className="p-3 text-left font-normal">Method</th>
              <th className="p-3 text-left font-normal">State</th>
              <th className="p-3 text-right font-normal">Amount</th>
              <th className="p-3 pr-5 w-10" />
            </tr>
          </thead>
          <tbody>
            {payments.map((payment) => (
              <tr key={payment.id} className="border-b last:border-b-0">
                <td className="p-3 pl-5 font-medium">{payment.number}</td>
                <td className="p-3 text-muted-foreground">{payment.payment_method?.name ?? '—'}</td>
                <td className="p-3">
                  <StatusBadge status={payment.state} />
                </td>
                <td className="p-3 text-right font-medium whitespace-nowrap">
                  {payment.display_amount}
                </td>
                <td className="p-3 pr-5">
                  {(payment.state === 'checkout' ||
                    payment.state === 'pending' ||
                    payment.state === 'completed') && (
                    <DropdownMenu>
                      <DropdownMenuTrigger asChild>
                        <Button variant="ghost" size="icon-xs">
                          <EllipsisVerticalIcon className="size-4" />
                        </Button>
                      </DropdownMenuTrigger>
                      <DropdownMenuContent align="end">
                        {(payment.state === 'checkout' || payment.state === 'pending') && (
                          <DropdownMenuItem
                            onClick={() => {
                              if (window.confirm('Capture this payment?')) {
                                captureMutation.mutate(payment.id)
                              }
                            }}
                          >
                            <CreditCardIcon className="size-4" />
                            Capture
                          </DropdownMenuItem>
                        )}
                        {(payment.state === 'checkout' ||
                          payment.state === 'pending' ||
                          payment.state === 'completed') && (
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={() => {
                              if (window.confirm('Void this payment?')) {
                                voidMutation.mutate(payment.id)
                              }
                            }}
                          >
                            <XCircleIcon className="size-4" />
                            Void
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
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Adjustments
// ---------------------------------------------------------------------------

function AddAdjustmentDialog({
  orderId,
  open,
  onOpenChange,
}: {
  orderId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {

  const mutation = useOrderMutation(orderId, (params: { label: string; amount: number }) =>
    adminClient.orders.adjustments.create(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { label: fd.get('label') as string, amount: Number(fd.get('amount')) },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Add Adjustment</DialogTitle>
          <DialogDescription>
            Add a manual adjustment to this order. Use a negative amount for discounts.
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="adj-label">Label</FieldLabel>
                <Input id="adj-label" name="label" placeholder="e.g. Manual discount" required />
              </Field>
              <Field>
                <FieldLabel htmlFor="adj-amount">Amount</FieldLabel>
                <Input
                  id="adj-amount"
                  name="amount"
                  type="number"
                  step="0.01"
                  placeholder="-10.00"
                  required
                />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Adding…' : 'Add Adjustment'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function AdjustmentsCard({ order }: { order: Order }) {
  const { orderId } = Route.useParams()

  const adjustments = (order.adjustments ?? []).filter(
    (a) => a.source_type !== 'Spree::TaxRate' && a.source_type !== 'Spree::PromotionAction',
  )
  const [addOpen, setAddOpen] = useState(false)

  const deleteMutation = useOrderMutation(orderId, (adjustmentId: string) =>
    adminClient.orders.adjustments.delete(orderId, adjustmentId),
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            <SlidersHorizontalIcon className="size-4" />
            Adjustments
          </CardTitle>
          <CardAction className="flex items-center gap-2">
            {adjustments.length > 0 && <Badge variant="info">{adjustments.length}</Badge>}
            <Button size="sm" variant="secondary" onClick={() => setAddOpen(true)}>
              <PlusIcon data-icon="inline-start" />
              Add
            </Button>
          </CardAction>
        </CardHeader>
        {adjustments.length > 0 ? (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b bg-muted/50 text-muted-foreground">
                  <th className="p-3 pl-5 text-left font-normal">Label</th>
                  <th className="p-3 text-left font-normal">State</th>
                  <th className="p-3 text-right font-normal">Amount</th>
                  <th className="p-3 pr-5 w-10" />
                </tr>
              </thead>
              <tbody>
                {adjustments.map((adj) => (
                  <tr key={adj.id} className="border-b last:border-b-0">
                    <td className="p-3 pl-5">{adj.label ?? '—'}</td>
                    <td className="p-3">
                      <StatusBadge status={adj.state} />
                    </td>
                    <td className="p-3 text-right font-medium whitespace-nowrap">
                      {order.currency} {Number.parseFloat(adj.amount).toFixed(2)}
                    </td>
                    <td className="p-3 pr-5">
                      {!adj.source_type && (
                        <DropdownMenu>
                          <DropdownMenuTrigger asChild>
                            <Button variant="ghost" size="icon-xs">
                              <EllipsisVerticalIcon className="size-4" />
                            </Button>
                          </DropdownMenuTrigger>
                          <DropdownMenuContent align="end">
                            <DropdownMenuItem
                              className="text-destructive focus:text-destructive"
                              onClick={() => {
                                if (window.confirm('Remove this adjustment?')) {
                                  deleteMutation.mutate(adj.id)
                                }
                              }}
                            >
                              <TrashIcon className="size-4" />
                              Remove
                            </DropdownMenuItem>
                          </DropdownMenuContent>
                        </DropdownMenu>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        ) : (
          <CardContent>
            <p className="text-center text-muted-foreground py-8">No adjustments</p>
          </CardContent>
        )}
      </Card>

      <AddAdjustmentDialog orderId={orderId} open={addOpen} onOpenChange={setAddOpen} />
    </>
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
  const outstandingBalance = Number.parseFloat(order.total) - Number.parseFloat(order.payment_total)

  return (
    <Card>
      <CardHeader>
        <CardTitle>Summary</CardTitle>
      </CardHeader>
      <div className="py-1">
        {order.completed_at && (
          <>
            <SummaryRow label="Completed" value={formatDate(order.completed_at)} />
            {order.canceled_at && (
              <SummaryRow label="Canceled" value={formatDate(order.canceled_at)} />
            )}
            <Separator />
          </>
        )}

        <SummaryRow label="Locale" value={order.locale ?? '—'} />
        <SummaryRow label="Currency" value={order.currency} />

        <Separator />

        <SummaryRow label="Subtotal" value={order.display_item_total} />

        {Number.parseFloat(order.ship_total) > 0 && (
          <SummaryRow label="Shipping" value={order.display_ship_total} />
        )}

        {Number.parseFloat(order.promo_total) !== 0 && (
          <SummaryRow label="Promotions" value={order.display_promo_total} />
        )}

        {Number.parseFloat(order.adjustment_total) !== 0 && (
          <SummaryRow label="Adjustments" value={order.display_adjustment_total} />
        )}

        {Number.parseFloat(order.included_tax_total) > 0 && (
          <SummaryRow label="Tax (included)" value={order.display_included_tax_total} />
        )}

        {Number.parseFloat(order.additional_tax_total) > 0 && (
          <SummaryRow label="Tax (additional)" value={order.display_additional_tax_total} />
        )}

        <Separator />

        <SummaryRow label="Total" value={order.display_total} bold />

        <Separator />

        <SummaryRow label="Payment total" value={order.display_payment_total} highlight />
        <SummaryRow
          label="Outstanding balance"
          value={`${order.currency} ${Math.abs(outstandingBalance).toFixed(2)}`}
          highlight
          danger={outstandingBalance > 0}
        />
      </div>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Customer Sidebar
// ---------------------------------------------------------------------------

function AddressBlock({
  title,
  address,
}: {
  title: string
  address: Address | null | undefined
}) {
  return (
    <div>
      <h6 className="font-semibold text-sm mb-1.5">{title}</h6>
      {address ? (
        <div className="text-sm text-muted-foreground flex flex-col gap-0.5">
          <div>{address.full_name}</div>
          {address.company && <div>{address.company}</div>}
          <div>{address.address1}</div>
          {address.address2 && <div>{address.address2}</div>}
          <div>
            {[address.city, address.state_text, address.zipcode].filter(Boolean).join(', ')}
          </div>
          <div>{address.country_name}</div>
          {address.phone && <div>{address.phone}</div>}
        </div>
      ) : (
        <span className="text-sm text-muted-foreground">Not provided</span>
      )}
    </div>
  )
}

function EditAddressDialog({
  orderId,
  type,
  address,
  open,
  onOpenChange,
}: {
  orderId: string
  type: 'ship_address' | 'bill_address'
  address: Address | null | undefined
  open: boolean
  onOpenChange: (open: boolean) => void
}) {

  const mutation = useOrderMutation(orderId, (params: Record<string, unknown>) =>
    adminClient.orders.update(orderId, { [type]: params } as any),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      {
        firstname: fd.get('firstname') as string,
        lastname: fd.get('lastname') as string,
        address1: fd.get('address1') as string,
        city: fd.get('city') as string,
        zipcode: fd.get('zipcode') as string,
        country_iso: fd.get('country_iso') as string,
        state_abbr: fd.get('state_abbr') as string,
        phone: fd.get('phone') as string,
      },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  const title = type === 'ship_address' ? 'Edit Shipping Address' : 'Edit Billing Address'

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>Update the address details.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor={`${type}-fn`}>First Name</FieldLabel>
                  <Input
                    id={`${type}-fn`}
                    name="firstname"
                    defaultValue={address?.firstname ?? ''}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor={`${type}-ln`}>Last Name</FieldLabel>
                  <Input id={`${type}-ln`} name="lastname" defaultValue={address?.lastname ?? ''} />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor={`${type}-a1`}>Address</FieldLabel>
                <Input id={`${type}-a1`} name="address1" defaultValue={address?.address1 ?? ''} />
              </Field>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor={`${type}-city`}>City</FieldLabel>
                  <Input id={`${type}-city`} name="city" defaultValue={address?.city ?? ''} />
                </Field>
                <Field>
                  <FieldLabel htmlFor={`${type}-zip`}>Zip Code</FieldLabel>
                  <Input id={`${type}-zip`} name="zipcode" defaultValue={address?.zipcode ?? ''} />
                </Field>
              </div>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor={`${type}-country`}>Country ISO</FieldLabel>
                  <Input
                    id={`${type}-country`}
                    name="country_iso"
                    defaultValue={address?.country_iso ?? ''}
                    placeholder="US"
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor={`${type}-state`}>State</FieldLabel>
                  <Input
                    id={`${type}-state`}
                    name="state_abbr"
                    defaultValue={address?.state_abbr ?? ''}
                    placeholder="CA"
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor={`${type}-phone`}>Phone</FieldLabel>
                <Input id={`${type}-phone`} name="phone" defaultValue={address?.phone ?? ''} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Saving…' : 'Save'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}

function CustomerCard({ order }: { order: Order }) {
  const { orderId } = Route.useParams()
  const user = order.user
  const [editAddress, setEditAddress] = useState<'ship_address' | 'bill_address' | null>(null)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>Customer</CardTitle>
          <CardAction>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button variant="ghost" size="icon-xs">
                  <EllipsisVerticalIcon className="size-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end">
                <DropdownMenuItem onClick={() => setEditAddress('ship_address')}>
                  <PencilIcon className="size-4" />
                  Edit Shipping Address
                </DropdownMenuItem>
                <DropdownMenuItem onClick={() => setEditAddress('bill_address')}>
                  <PencilIcon className="size-4" />
                  Edit Billing Address
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-5">
          {/* Contact info */}
          {user ? (
            <div className="flex items-center gap-3 rounded-xl bg-muted p-3">
              <div className="flex size-9 items-center justify-center rounded-lg bg-zinc-950 text-white text-xs font-medium">
                {[user.first_name, user.last_name]
                  .filter(Boolean)
                  .map((n) => n![0])
                  .join('')
                  .toUpperCase() || user.email[0]!.toUpperCase()}
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-sm font-medium">
                  {[user.first_name, user.last_name].filter(Boolean).join(' ') || user.email}
                </div>
                <div className="truncate text-xs text-muted-foreground">{user.email}</div>
              </div>
            </div>
          ) : order.email ? (
            <div className="text-sm text-blue-600">{order.email}</div>
          ) : (
            <span className="text-sm text-muted-foreground">No customer information</span>
          )}

          <AddressBlock title="Shipping Address" address={order.ship_address} />
          <AddressBlock title="Billing Address" address={order.bill_address} />
        </CardContent>
      </Card>

      {editAddress && (
        <EditAddressDialog
          orderId={orderId}
          type={editAddress}
          address={editAddress === 'ship_address' ? order.ship_address : order.bill_address}
          open={!!editAddress}
          onOpenChange={(open) => !open && setEditAddress(null)}
        />
      )}
    </>
  )
}

// ---------------------------------------------------------------------------
// Special Instructions
// ---------------------------------------------------------------------------

function SpecialInstructionsCard({ order }: { order: Order }) {
  const { orderId } = Route.useParams()

  const [editing, setEditing] = useState(false)
  const mutation = useOrderMutation(orderId, (params: { special_instructions: string }) =>
    adminClient.orders.update(orderId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      { special_instructions: fd.get('special_instructions') as string },
      { onSuccess: () => setEditing(false) },
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Special Instructions</CardTitle>
        <CardAction>
          <Button variant="ghost" size="icon-xs" onClick={() => setEditing(!editing)}>
            <PencilIcon className="size-4" />
          </Button>
        </CardAction>
      </CardHeader>
      <CardContent>
        {editing ? (
          <form onSubmit={handleSubmit} className="flex flex-col gap-3">
            <Textarea name="special_instructions" defaultValue={order.special_instructions ?? ''} />
            <div className="flex justify-end gap-2">
              <Button type="button" variant="outline" size="sm" onClick={() => setEditing(false)}>
                Cancel
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? 'Saving…' : 'Save'}
              </Button>
            </div>
          </form>
        ) : order.special_instructions ? (
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">
            {order.special_instructions}
          </p>
        ) : (
          <p className="text-sm text-muted-foreground">None</p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Internal Note
// ---------------------------------------------------------------------------

function InternalNoteCard({ order }: { order: Order }) {
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
        <CardTitle>Internal Note</CardTitle>
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
                Cancel
              </Button>
              <Button type="submit" size="sm" disabled={mutation.isPending}>
                {mutation.isPending ? 'Saving…' : 'Save'}
              </Button>
            </div>
          </form>
        ) : order.internal_note ? (
          <p className="text-sm text-muted-foreground whitespace-pre-wrap">{order.internal_note}</p>
        ) : (
          <p className="text-sm text-muted-foreground">None</p>
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
