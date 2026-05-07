import type { Address, Customer, Order, StoreCredit } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { createFileRoute, Link } from '@tanstack/react-router'
import {
  EllipsisVerticalIcon,
  MailIcon,
  PencilIcon,
  PhoneIcon,
  PlusIcon,
  StarIcon,
  TrashIcon,
} from 'lucide-react'
import { type FormEvent, type ReactNode, useState } from 'react'
import { adminClient } from '@/client'
import { AddressFormDialog, type AddressParams } from '@/components/spree/address-form-dialog'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CustomFieldsCard } from '@/components/spree/custom-fields/custom-fields-card'
import { MetadataCard } from '@/components/spree/metadata/metadata-card'
import { PageHeader } from '@/components/spree/page-header'
import { RelativeTime } from '@/components/spree/relative-time'
import { ResourceLayout } from '@/components/spree/resource-layout'
import { ErrorState } from '@/components/spree/route-error-boundary'
import { TagCombobox } from '@/components/spree/tag-combobox'
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
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import { Textarea } from '@/components/ui/textarea'
import { useAuth } from '@/hooks/use-auth'
import { useCountries } from '@/hooks/use-countries'

export const Route = createFileRoute('/_authenticated/$storeId/customers/$customerId')({
  component: CustomerDetailPage,
})

function useCustomer(customerId: string) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: ['customer', customerId],
    queryFn: () =>
      adminClient.customers.get(customerId, { expand: ['addresses', 'store_credits'] }),
    enabled: isAuthenticated,
  })
}

function useCustomerMutation<TParams>(
  customerId: string,
  mutationFn: (params: TParams) => Promise<unknown>,
) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn,
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['customer', customerId] }),
  })
}

function CustomerDetailPage() {
  const { customerId } = Route.useParams()
  const { data: customer, isLoading, error, refetch } = useCustomer(customerId)

  if (isLoading) return <p className="text-muted-foreground">Loading customer…</p>
  if (error || !customer) {
    return (
      <ErrorState
        title="Failed to load customer"
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CustomerBody customer={customer} />
}

function CustomerBody({ customer }: { customer: Customer }) {
  const { data, isLoading } = useCustomerOrders(customer.id, { limit: 10 })
  const orders = data?.data ?? []
  const totalCount = data?.meta?.count ?? orders.length
  const lastCompletedOrder = orders.find((o) => o.status === 'complete')

  const defaultShipping = customer.addresses?.find((a) => a.is_default_shipping)
  const location = [defaultShipping?.city, defaultShipping?.country_iso].filter(Boolean).join(', ')

  return (
    <ResourceLayout
      header={
        <>
          <PageHeader
            title={customer.full_name ?? customer.email}
            subtitle={location || undefined}
            backTo="customers"
            badges={customer.tags?.map((tag) => <Badge key={tag}>{tag}</Badge>)}
            resource={{ id: customer.id }}
            jsonPreview={{
              title: `Customer ${customer.email}`,
              queryKey: ['json', 'customer', customer.id],
              queryFn: () => adminClient.customers.get(customer.id),
              endpoint: `/api/v3/admin/customers/${customer.id}`,
            }}
          />
          <LifetimeStatsCard customer={customer} />
        </>
      }
      main={
        <>
          {lastCompletedOrder && <LastOrderCard order={lastCompletedOrder} />}
          <OrdersCard
            customer={customer}
            orders={orders}
            totalCount={totalCount}
            isLoading={isLoading}
          />
          <StoreCreditsCard customer={customer} />
          <CustomFieldsCard
            ownerType="Spree::User"
            ownerId={customer.id}
            resourceLabel="customers"
          />
          <MetadataCard metadata={customer.metadata} />
        </>
      }
      sidebar={
        <>
          <ProfileCard customer={customer} />
          <AddressesCard customer={customer} />
          <InternalNoteCard customer={customer} />
        </>
      }
    />
  )
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

function ProfileCard({ customer }: { customer: Customer }) {
  const [editOpen, setEditOpen] = useState(false)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>Profile</CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditOpen(true)}>
              <PencilIcon className="size-4" />
              Edit
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent className="flex flex-col gap-3">
          <div className="flex items-center gap-2 text-sm">
            <MailIcon className="size-4 text-muted-foreground" />
            <span>{customer.email}</span>
          </div>
          {customer.phone && (
            <div className="flex items-center gap-2 text-sm">
              <PhoneIcon className="size-4 text-muted-foreground" />
              <span>{customer.phone}</span>
            </div>
          )}
          <div className="flex items-center gap-2 text-sm">
            <StarIcon className="size-4 text-muted-foreground" />
            <span>
              {customer.accepts_email_marketing
                ? 'Subscribed to marketing'
                : 'Not subscribed to marketing'}
            </span>
          </div>
          {customer.created_at && (
            <div className="text-xs text-muted-foreground">
              <RelativeTime iso={customer.created_at} prefix="Customer since" />
            </div>
          )}
        </CardContent>
      </Card>
      <EditProfileDialog customer={customer} open={editOpen} onOpenChange={setEditOpen} />
    </>
  )
}

function EditProfileDialog({
  customer,
  open,
  onOpenChange,
}: {
  customer: Customer
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const [tags, setTags] = useState<string[]>(customer.tags ?? [])
  const mutation = useCustomerMutation(customer.id, (params: Record<string, unknown>) =>
    adminClient.customers.update(
      customer.id,
      params as Parameters<typeof adminClient.customers.update>[1],
    ),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    const payload: Record<string, unknown> = {
      email: fd.get('email'),
      first_name: fd.get('first_name'),
      last_name: fd.get('last_name'),
      phone: fd.get('phone'),
      accepts_email_marketing: fd.get('accepts_email_marketing') === 'on',
      tags,
    }
    mutation.mutate(payload, { onSuccess: () => onOpenChange(false) })
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Edit Customer</DialogTitle>
          <DialogDescription>Update the customer's profile information.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">Email</FieldLabel>
                <Input
                  id="email"
                  name="email"
                  type="email"
                  defaultValue={customer.email}
                  required
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="first_name">First name</FieldLabel>
                <Input id="first_name" name="first_name" defaultValue={customer.first_name ?? ''} />
              </Field>
              <Field>
                <FieldLabel htmlFor="last_name">Last name</FieldLabel>
                <Input id="last_name" name="last_name" defaultValue={customer.last_name ?? ''} />
              </Field>
              <Field>
                <FieldLabel htmlFor="phone">Phone</FieldLabel>
                <Input id="phone" name="phone" defaultValue={customer.phone ?? ''} />
              </Field>
              <Field>
                <FieldLabel>Tags</FieldLabel>
                <TagCombobox taggableType="Spree::User" value={tags} onChange={setTags} />
              </Field>
              <Field>
                <label className="flex items-center gap-2 text-sm">
                  <input
                    type="checkbox"
                    name="accepts_email_marketing"
                    defaultChecked={customer.accepts_email_marketing}
                  />
                  Subscribed to marketing
                </label>
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

// ---------------------------------------------------------------------------
// Lifetime Stats
// ---------------------------------------------------------------------------

function LifetimeStatsCard({ customer }: { customer: Customer }) {
  const orders = customer.orders_count ?? 0
  const totalSpent = Number(customer.total_spent ?? '0')
  const aov = orders > 0 ? totalSpent / orders : 0
  const aovDisplay =
    orders > 0 && totalSpent > 0
      ? customer.display_total_spent?.replace(/[\d.,]+/, aov.toFixed(2))
      : '—'

  return (
    <Card>
      <CardContent className="grid grid-cols-2 lg:grid-cols-5 gap-6 py-6">
        <Stat label="Total spent" value={customer.display_total_spent ?? '—'} />
        <Stat label="Orders" value={String(orders)} />
        <Stat label="Avg order value" value={aovDisplay ?? '—'} />
        <Stat label="Store credit" value={customer.display_available_store_credit_total ?? '—'} />
        <Stat label="Customer since" value={<RelativeTime iso={customer.created_at} />} />
      </CardContent>
    </Card>
  )
}

function Stat({ label, value }: { label: string; value: ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <span className="text-sm text-muted-foreground">{label}</span>
      <span className="text-lg font-semibold">{value}</span>
    </div>
  )
}

// ---------------------------------------------------------------------------
// Last Order
// ---------------------------------------------------------------------------

function useCustomerOrders(customerId: string, params: { limit: number; status?: string }) {
  const { isAuthenticated } = useAuth()
  return useQuery({
    queryKey: ['customer-orders', customerId, params],
    queryFn: () =>
      adminClient.orders.list({
        q: { user_id_eq: customerId, ...(params.status ? { status_eq: params.status } : {}) },
        limit: params.limit,
        sort: '-completed_at',
        expand: ['items'],
      }),
    enabled: isAuthenticated,
  })
}

function LastOrderCard({ order }: { order: Order }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Last order placed</CardTitle>
      </CardHeader>
      <CardContent className="p-0">
        <div className="border-t flex items-center justify-between px-6 py-3">
          <div>
            <Link
              to={'/$storeId/orders/$orderId' as string}
              params={{ orderId: order.id }}
              className="font-medium text-foreground no-underline"
            >
              #{order.number}
            </Link>
            <span className="ml-2 inline-flex gap-2">
              {order.payment_status && <StatusBadge status={order.payment_status} />}
              {order.fulfillment_status && <StatusBadge status={order.fulfillment_status} />}
            </span>
            {order.completed_at && (
              <div className="text-xs text-muted-foreground mt-1">
                <RelativeTime iso={order.completed_at} />
              </div>
            )}
          </div>
          <div className="font-semibold">{order.display_total}</div>
        </div>
        {order.items?.slice(0, 5).map((item) => (
          <div key={item.id} className="border-t flex items-center gap-3 px-6 py-3 text-sm">
            {item.thumbnail_url && (
              <img src={item.thumbnail_url} alt="" className="size-10 rounded object-cover" />
            )}
            <div className="flex-1 min-w-0">
              <div className="truncate">{item.name}</div>
              {item.options_text && (
                <div className="text-xs text-muted-foreground truncate">{item.options_text}</div>
              )}
            </div>
            <div className="text-muted-foreground">×{item.quantity}</div>
            <div className="font-medium tabular-nums">{item.display_total}</div>
          </div>
        ))}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

function OrdersCard({
  customer,
  orders,
  totalCount,
  isLoading,
}: {
  customer: Customer
  orders: Order[]
  totalCount: number
  isLoading: boolean
}) {
  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Orders</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">Loading orders…</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          Orders
          {totalCount > 0 && <Badge variant="outline">{totalCount}</Badge>}
        </CardTitle>
        {totalCount > orders.length && (
          <CardAction>
            <Link
              to={'/$storeId/orders' as string}
              search={{
                filters: [{ id: '1', field: 'user_id_eq', operator: 'eq', value: customer.id }],
              }}
              className="text-sm text-primary hover:underline"
            >
              View all →
            </Link>
          </CardAction>
        )}
      </CardHeader>
      {orders.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">No orders yet</p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-muted-foreground text-left">
                <th className="px-6 py-2 font-normal">Order</th>
                <th className="px-6 py-2 font-normal">Date</th>
                <th className="px-6 py-2 font-normal">Status</th>
                <th className="px-6 py-2 font-normal text-right">Total</th>
              </tr>
            </thead>
            <tbody>
              {orders.map((order: Order) => (
                <tr key={order.id} className="border-b last:border-b-0">
                  <td className="px-6 py-3">
                    <Link
                      to={'/$storeId/orders/$orderId' as string}
                      params={{ orderId: order.id }}
                      className="font-medium text-foreground no-underline"
                    >
                      #{order.number}
                    </Link>
                  </td>
                  <td className="px-6 py-3 text-muted-foreground">
                    <RelativeTime iso={order.completed_at ?? order.created_at} />
                  </td>
                  <td className="px-6 py-3">
                    <span className="inline-flex gap-1">
                      <StatusBadge status={order.status} />
                      {order.payment_status && <StatusBadge status={order.payment_status} />}
                      {order.fulfillment_status && (
                        <StatusBadge status={order.fulfillment_status} />
                      )}
                    </span>
                  </td>
                  <td className="px-6 py-3 text-right font-medium tabular-nums">
                    {order.display_total}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </CardContent>
      )}
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Internal Note
// ---------------------------------------------------------------------------

function InternalNoteCard({ customer }: { customer: Customer }) {
  const [editing, setEditing] = useState(false)
  const [note, setNote] = useState(customer.internal_note_html ?? '')

  const mutation = useCustomerMutation(customer.id, (params: { internal_note: string }) =>
    adminClient.customers.update(customer.id, params),
  )

  return (
    <Card>
      <CardHeader>
        <CardTitle>Internal Note</CardTitle>
        {!editing && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
              <PencilIcon className="size-4" />
              Edit
            </Button>
          </CardAction>
        )}
      </CardHeader>
      <CardContent>
        {editing ? (
          <div className="flex flex-col gap-3">
            <Textarea
              rows={4}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              placeholder="Staff-only notes about this customer…"
            />
            <div className="flex gap-2 justify-end">
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => {
                  setEditing(false)
                  setNote(customer.internal_note_html ?? '')
                }}
              >
                Cancel
              </Button>
              <Button
                type="button"
                size="sm"
                disabled={mutation.isPending}
                onClick={() =>
                  mutation.mutate({ internal_note: note }, { onSuccess: () => setEditing(false) })
                }
              >
                {mutation.isPending ? 'Saving…' : 'Save'}
              </Button>
            </div>
          </div>
        ) : customer.internal_note_html ? (
          <div
            className="text-sm prose-sm"
            // biome-ignore lint/security/noDangerouslySetInnerHtml: HTML is sanitized server-side via the rich-text pipeline
            dangerouslySetInnerHTML={{ __html: customer.internal_note_html }}
          />
        ) : (
          <p className="text-sm text-muted-foreground">No internal notes</p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Addresses
// ---------------------------------------------------------------------------

function AddressesCard({ customer }: { customer: Customer }) {
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<Address | null>(null)
  const confirm = useConfirm()
  const isDefault = (a: Address) => a.is_default_billing || a.is_default_shipping
  const addresses = [...(customer.addresses ?? [])].sort(
    (a, b) => Number(isDefault(b)) - Number(isDefault(a)),
  )

  const deleteMutation = useCustomerMutation(customer.id, (id: string) =>
    adminClient.customers.addresses.delete(customer.id, id),
  )

  const setDefaultMutation = useCustomerMutation(
    customer.id,
    (params: { id: string; kind: 'billing' | 'shipping' }) =>
      adminClient.customers.addresses.update(customer.id, params.id, {
        [params.kind === 'billing' ? 'is_default_billing' : 'is_default_shipping']: true,
      }),
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            Addresses
            {addresses.length > 0 && <Badge variant="outline">{addresses.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              Add Address
            </Button>
          </CardAction>
        </CardHeader>
        {addresses.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">No saved addresses</p>
          </CardContent>
        ) : (
          <CardContent className="flex flex-col gap-3">
            {addresses.map((addr) => (
              <div
                key={addr.id}
                className="flex items-start justify-between gap-2 rounded-md border p-3"
              >
                <div className="text-sm">
                  <div className="font-medium">
                    {[addr.first_name, addr.last_name].filter(Boolean).join(' ').trim() ||
                      addr.label ||
                      '—'}
                    <span className="ml-2 inline-flex gap-1">
                      {addr.is_default_billing && <Badge variant="outline">Default billing</Badge>}
                      {addr.is_default_shipping && (
                        <Badge variant="outline">Default shipping</Badge>
                      )}
                    </span>
                  </div>
                  <div className="text-muted-foreground">{addr.address1}</div>
                  {addr.address2 && <div className="text-muted-foreground">{addr.address2}</div>}
                  <div className="text-muted-foreground">
                    {[addr.city, addr.state_abbr, addr.postal_code].filter(Boolean).join(', ')} ·{' '}
                    {addr.country_iso}
                  </div>
                  {addr.phone && <div className="text-muted-foreground">{addr.phone}</div>}
                </div>
                <DropdownMenu>
                  <DropdownMenuTrigger asChild>
                    <Button variant="ghost" size="icon-xs">
                      <EllipsisVerticalIcon className="size-4" />
                    </Button>
                  </DropdownMenuTrigger>
                  <DropdownMenuContent align="end">
                    <DropdownMenuItem onClick={() => setEditing(addr)}>
                      <PencilIcon className="size-4" />
                      Edit
                    </DropdownMenuItem>
                    {!addr.is_default_billing && (
                      <DropdownMenuItem
                        onClick={() => setDefaultMutation.mutate({ id: addr.id, kind: 'billing' })}
                      >
                        Set as default billing
                      </DropdownMenuItem>
                    )}
                    {!addr.is_default_shipping && (
                      <DropdownMenuItem
                        onClick={() => setDefaultMutation.mutate({ id: addr.id, kind: 'shipping' })}
                      >
                        Set as default shipping
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem
                      className="text-destructive focus:text-destructive"
                      onClick={async () => {
                        if (
                          await confirm({
                            message: 'Delete this address?',
                            variant: 'destructive',
                            confirmLabel: 'Delete',
                          })
                        ) {
                          deleteMutation.mutate(addr.id)
                        }
                      }}
                    >
                      <TrashIcon className="size-4" />
                      Delete
                    </DropdownMenuItem>
                  </DropdownMenuContent>
                </DropdownMenu>
              </div>
            ))}
          </CardContent>
        )}
      </Card>

      {addOpen && (
        <CustomerAddressDialog
          customer={customer}
          address={newAddressTemplate(customer)}
          onOpenChange={setAddOpen}
          title="Add Address"
        />
      )}
      {editing && (
        <CustomerAddressDialog
          customer={customer}
          address={editing}
          onOpenChange={(o) => {
            if (!o) setEditing(null)
          }}
          title="Edit Address"
        />
      )}
    </>
  )
}

function newAddressTemplate(customer: Customer): Address {
  return {
    first_name: customer.first_name ?? '',
    last_name: customer.last_name ?? '',
    phone: customer.phone ?? '',
  } as Address
}

function CustomerAddressDialog({
  customer,
  address,
  onOpenChange,
  title,
}: {
  customer: Customer
  address: Address
  onOpenChange: (open: boolean) => void
  title: string
}) {
  const { isLoading: countriesLoading } = useCountries()
  const isEdit = Boolean(address.id)
  const mutation = useCustomerMutation(customer.id, (params: AddressParams) =>
    isEdit
      ? adminClient.customers.addresses.update(customer.id, address.id, params)
      : adminClient.customers.addresses.create(customer.id, params),
  )

  // Wait for countries before mounting so the country/state lazy initializer
  // can resolve the address's country_iso/state_abbr to a real option.
  if (countriesLoading) return null

  return (
    <AddressFormDialog
      address={address}
      open
      onOpenChange={onOpenChange}
      onSave={(params) => mutation.mutate(params, { onSuccess: () => onOpenChange(false) })}
      title={title}
      isPending={mutation.isPending}
      showLabel
      showDefaultFlags
    />
  )
}

// ---------------------------------------------------------------------------
// Store Credits
// ---------------------------------------------------------------------------

function StoreCreditsCard({ customer }: { customer: Customer }) {
  const [addOpen, setAddOpen] = useState(false)
  const confirm = useConfirm()
  const credits = customer.store_credits ?? []

  const deleteMutation = useCustomerMutation(customer.id, (id: string) =>
    adminClient.customers.storeCredits.delete(customer.id, id),
  )

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            Store Credits
            {credits.length > 0 && <Badge>{credits.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              Issue Credit
            </Button>
          </CardAction>
        </CardHeader>
        {credits.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">No store credits issued</p>
          </CardContent>
        ) : (
          <CardContent>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-muted-foreground text-left">
                  <th className="py-2 font-normal">Amount</th>
                  <th className="py-2 font-normal">Used</th>
                  <th className="py-2 font-normal">Remaining</th>
                  <th className="py-2 font-normal">Memo</th>
                  <th className="py-2 w-10" />
                </tr>
              </thead>
              <tbody>
                {credits.map((sc: StoreCredit & { memo?: string | null }) => (
                  <tr key={sc.id} className="border-b last:border-b-0">
                    <td className="py-2">{sc.display_amount ?? sc.amount}</td>
                    <td className="py-2">{sc.display_amount_used ?? sc.amount_used}</td>
                    <td className="py-2">{sc.display_amount_remaining ?? sc.amount_remaining}</td>
                    <td className="py-2 text-muted-foreground">{sc.memo ?? '—'}</td>
                    <td className="py-2 text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: 'Delete this store credit?',
                                  variant: 'destructive',
                                  confirmLabel: 'Delete',
                                })
                              ) {
                                deleteMutation.mutate(sc.id)
                              }
                            }}
                          >
                            <TrashIcon className="size-4" />
                            Delete
                          </DropdownMenuItem>
                        </DropdownMenuContent>
                      </DropdownMenu>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </CardContent>
        )}
      </Card>

      <IssueStoreCreditDialog customerId={customer.id} open={addOpen} onOpenChange={setAddOpen} />
    </>
  )
}

function IssueStoreCreditDialog({
  customerId,
  open,
  onOpenChange,
}: {
  customerId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const mutation = useCustomerMutation(
    customerId,
    (params: Parameters<typeof adminClient.customers.storeCredits.create>[1]) =>
      adminClient.customers.storeCredits.create(customerId, params),
  )

  function handleSubmit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault()
    const fd = new FormData(e.currentTarget)
    mutation.mutate(
      {
        amount: Number(fd.get('amount')),
        currency: String(fd.get('currency') ?? ''),
        category_id: String(fd.get('category_id') ?? ''),
        memo: (fd.get('memo') as string) || undefined,
      },
      { onSuccess: () => onOpenChange(false) },
    )
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Issue Store Credit</DialogTitle>
          <DialogDescription>Add store credit to this customer's account.</DialogDescription>
        </DialogHeader>
        <form onSubmit={handleSubmit}>
          <DialogBody>
            <FieldGroup>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="sc-amount">Amount</FieldLabel>
                  <Input id="sc-amount" name="amount" type="number" step="0.01" required />
                </Field>
                <Field>
                  <FieldLabel htmlFor="sc-currency">Currency</FieldLabel>
                  <Input id="sc-currency" name="currency" defaultValue="USD" required />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="sc-category">Category ID</FieldLabel>
                <Input id="sc-category" name="category_id" placeholder="e.g. 1" required />
              </Field>
              <Field>
                <FieldLabel htmlFor="sc-memo">Memo</FieldLabel>
                <Textarea
                  id="sc-memo"
                  name="memo"
                  rows={3}
                  placeholder="Reason for issuing this credit"
                />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending ? 'Issuing…' : 'Issue Credit'}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
