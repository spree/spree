import { zodResolver } from '@hookform/resolvers/zod'
import type { Address, Customer, Order, StoreCredit } from '@spree/admin-sdk'
import {
  AddressFormDialog,
  type AddressParams,
  CurrencySelect,
  mapSpreeErrorsToForm,
  PageHeader,
  ResourceMultiAutocomplete,
  Subject,
  TagCombobox,
  useCountries,
  useStore,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  Checkbox,
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
  DropdownMenuTrigger,
  ErrorState,
  Field,
  FieldError,
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
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  StatusBadge,
  Textarea,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import {
  EllipsisVerticalIcon,
  MailIcon,
  PencilIcon,
  PhoneIcon,
  PlusIcon,
  StarIcon,
  TrashIcon,
  UsersIcon,
} from 'lucide-react'
import { type ReactNode, useEffect, useMemo, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { currencyParts } from '@/components/spree/bulk-price-editor/currency-parts'
import { normalizeMoneyInput } from '@/components/spree/bulk-price-editor/normalize-money'
import {
  CustomFieldsInlineCard,
  EditableApiCustomFieldsProvider,
} from '@/components/spree/custom-fields/custom-fields-inline'
import { useCurrencyLocale } from '@/hooks/use-currency-locale'
import { customerGroupAutocompleteProps, useCustomerGroups } from '@/hooks/use-customer-groups'
import {
  type StoreCreditUpdateParams,
  useCreateCustomerStoreCredit,
  useDeleteCustomerStoreCredit,
  useUpdateCustomerStoreCredit,
} from '@/hooks/use-customer-store-credits'
import {
  useCreateCustomerAddress,
  useCustomer,
  useCustomerOrders,
  useDeleteCustomer,
  useDeleteCustomerAddress,
  useUpdateCustomer,
  useUpdateCustomerAddress,
  useUpdateCustomerGroups,
} from '@/hooks/use-customers'
import { useStoreCreditCategories } from '@/hooks/use-store-credit-categories'
import { spreeJsonLinkResolver } from '@/lib/json-link-resolver'
import { type CustomerProfileFormValues, customerProfileFormSchema } from '@/schemas/customer'
import {
  type EditStoreCreditFormValues,
  editStoreCreditFormSchema,
  type IssueStoreCreditFormValues,
  issueStoreCreditFormSchema,
} from '@/schemas/store-credit'

export const Route = createFileRoute('/_authenticated/$storeId/customers/$customerId')({
  component: CustomerDetailPage,
})

function CustomerDetailPage() {
  const { t } = useTranslation()
  const { customerId } = Route.useParams()
  const { data: customer, isLoading, error, refetch } = useCustomer(customerId)

  if (isLoading) return <p className="text-muted-foreground">{t('admin.common.loading')}</p>
  if (error || !customer) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_customer')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <CustomerBody customer={customer} />
}

function CustomerBody({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const { data, isLoading } = useCustomerOrders(customer.id, { limit: 10 })
  const orders = data?.data ?? []
  const totalCount = data?.meta?.count ?? orders.length
  const lastCompletedOrder = orders.find((o) => o.status === 'complete')

  const defaultShipping = customer.addresses?.find((a) => a.is_default_shipping)
  const location = [defaultShipping?.city, defaultShipping?.country_iso].filter(Boolean).join(', ')

  // The server hard-deletes only when the customer has no completed orders
  // (Spree::Core::DestroyWithOrdersError → 422 `customer_has_orders`). We
  // surface the API error message inline rather than swallowing the failure.
  const deleteMutation = useDeleteCustomer(customer.id)

  async function handleDelete() {
    await deleteMutation.mutateAsync()
    navigate({ to: '/$storeId/customers', params: { storeId } })
  }

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
            onDelete={handleDelete}
            deleteLabel={t('admin.customers.detail.delete_label')}
            jsonPreview={{
              title: `Customer ${customer.email}`,
              // Reuse what `useCustomer` already loaded — opening the drawer
              // shouldn't trigger a duplicate fetch.
              fetch: () => Promise.resolve(customer),
              endpoint: `/api/v3/admin/customers/${customer.id}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
          />
          {deleteMutation.error && (
            <p className="text-sm text-destructive">{(deleteMutation.error as Error).message}</p>
          )}
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
          <EditableApiCustomFieldsProvider
            ownerType={Subject.Customer}
            ownerId={customer.id}
            resourceType={Subject.Customer}
            resourceLabel={t('admin.nav.customers').toLowerCase()}
          >
            <CustomFieldsInlineCard />
          </EditableApiCustomFieldsProvider>
          <MetadataCard
            metadata={customer.metadata}
            title={t('admin.components.metadata_card.title')}
            emptyTitle={t('admin.components.metadata_card.empty_title')}
            emptyDescription={t('admin.components.metadata_card.empty_description')}
          />
        </>
      }
      sidebar={
        <>
          <ProfileCard customer={customer} />
          <CustomerGroupsCard customer={customer} />
          <AddressesCard customer={customer} />
          {/* Key on `updated_at` so the textarea's local state resets after a
              refetch (e.g. another mutation invalidates the customer). */}
          <InternalNoteCard key={customer.updated_at} customer={customer} />
        </>
      }
    />
  )
}

// ---------------------------------------------------------------------------
// Profile
// ---------------------------------------------------------------------------

function ProfileCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [editOpen, setEditOpen] = useState(false)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.customers.detail.section_profile')}</CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditOpen(true)}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
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
                ? t('admin.customers.detail.subscribed_to_marketing')
                : t('admin.customers.detail.not_subscribed_to_marketing')}
            </span>
          </div>
          {customer.created_at && (
            <div className="text-xs text-muted-foreground">
              <RelativeTime
                iso={customer.created_at}
                prefix={t('admin.customers.detail.customer_since')}
              />
            </div>
          )}
        </CardContent>
      </Card>
      <EditProfileSheet customer={customer} open={editOpen} onOpenChange={setEditOpen} />
    </>
  )
}

function EditProfileSheet({
  customer,
  open,
  onOpenChange,
}: {
  customer: Customer
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const form = useForm<CustomerProfileFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(customerProfileFormSchema) as any,
    defaultValues: {
      email: customer.email,
      first_name: customer.first_name ?? '',
      last_name: customer.last_name ?? '',
      phone: customer.phone ?? '',
      tags: customer.tags ?? [],
      accepts_email_marketing: customer.accepts_email_marketing,
    },
  })
  const { errors } = form.formState
  const mutation = useUpdateCustomer(customer.id)

  // Sheet stays mounted across opens; re-seed form with the latest server
  // values whenever the dialog re-opens or the underlying record refreshes,
  // so stale edits from a previous session are discarded.
  useEffect(() => {
    if (open) {
      form.reset({
        email: customer.email,
        first_name: customer.first_name ?? '',
        last_name: customer.last_name ?? '',
        phone: customer.phone ?? '',
        tags: customer.tags ?? [],
        accepts_email_marketing: customer.accepts_email_marketing,
      })
    }
  }, [open, customer, form])

  async function onSubmit(values: CustomerProfileFormValues) {
    try {
      await mutation.mutateAsync(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.customers.edit_sheet_title')}</SheetTitle>
          <SheetDescription>
            {t('admin.customers.detail.edit_profile_description')}
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="email">{t('admin.fields.email.label')}</FieldLabel>
                <Input
                  id="email"
                  type="email"
                  aria-invalid={!!errors.email || undefined}
                  {...form.register('email')}
                />
                <FieldError errors={[errors.email]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="first_name">{t('admin.fields.first_name.label')}</FieldLabel>
                <Input
                  id="first_name"
                  aria-invalid={!!errors.first_name || undefined}
                  {...form.register('first_name')}
                />
                <FieldError errors={[errors.first_name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="last_name">{t('admin.fields.last_name.label')}</FieldLabel>
                <Input
                  id="last_name"
                  aria-invalid={!!errors.last_name || undefined}
                  {...form.register('last_name')}
                />
                <FieldError errors={[errors.last_name]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="phone">{t('admin.fields.phone.label')}</FieldLabel>
                <Input
                  id="phone"
                  aria-invalid={!!errors.phone || undefined}
                  {...form.register('phone')}
                />
                <FieldError errors={[errors.phone]} />
              </Field>
              <Field>
                <FieldLabel>{t('admin.fields.customer.tags.label')}</FieldLabel>
                <Controller
                  name="tags"
                  control={form.control}
                  render={({ field }) => (
                    <TagCombobox
                      taggableType={Subject.Customer}
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
              </Field>
              <Field>
                <div className="flex items-start justify-between gap-4">
                  <FieldLabel htmlFor="accepts_email_marketing" className="cursor-pointer">
                    {t('admin.fields.customer.accepts_email_marketing.label')}
                  </FieldLabel>
                  <Controller
                    name="accepts_email_marketing"
                    control={form.control}
                    render={({ field }) => (
                      <Checkbox
                        id="accepts_email_marketing"
                        checked={!!field.value}
                        onCheckedChange={field.onChange}
                      />
                    )}
                  />
                </div>
              </Field>
            </FieldGroup>
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={mutation.isPending}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={mutation.isPending}>
              {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Customer Groups
// ---------------------------------------------------------------------------

function CustomerGroupsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [editOpen, setEditOpen] = useState(false)
  const groups = customer.customer_groups ?? []

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.customers.detail.groups.title')}
            {groups.length > 0 && <Badge variant="outline">{groups.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditOpen(true)}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
            </Button>
          </CardAction>
        </CardHeader>
        <CardContent>
          {groups.length === 0 ? (
            <p className="text-sm text-muted-foreground">
              {t('admin.customers.detail.groups.empty')}
            </p>
          ) : (
            <div className="flex flex-wrap gap-1.5">
              {groups.map((group) => (
                <Badge key={group.id} variant="secondary" className="gap-1.5">
                  <UsersIcon className="size-3 text-muted-foreground" />
                  {group.name}
                </Badge>
              ))}
            </div>
          )}
        </CardContent>
      </Card>
      <EditGroupsSheet customer={customer} open={editOpen} onOpenChange={setEditOpen} />
    </>
  )
}

function EditGroupsSheet({
  customer,
  open,
  onOpenChange,
}: {
  customer: Customer
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const currentIds = useMemo(() => customer.customer_group_ids ?? [], [customer.customer_group_ids])
  const [groupIds, setGroupIds] = useState<string[]>(currentIds)
  const [error, setError] = useState<string | null>(null)

  // Surface the store's groups on focus (preloaded, 5-min cache) and re-seed
  // the selection whenever the sheet re-opens so a prior cancelled edit or an
  // external membership change is reflected.
  const { data: groupsData } = useCustomerGroups()
  useEffect(() => {
    if (open) {
      setGroupIds(currentIds)
      setError(null)
    }
  }, [open, currentIds])

  // `customer_group_ids` is a collection setter on the customer: PATCH replaces
  // the whole membership in one request, so no add/remove diffing needed.
  const mutation = useUpdateCustomerGroups(customer.id)
  const isPending = mutation.isPending

  async function handleSave() {
    setError(null)
    try {
      await mutation.mutateAsync(groupIds)
      onOpenChange(false)
    } catch (err) {
      setError(err instanceof Error ? err.message : t('admin.customers.detail.groups.save_failed'))
    }
  }

  const dirty =
    groupIds.length !== currentIds.length || groupIds.some((id) => !currentIds.includes(id))

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.customers.detail.groups.edit_title')}</SheetTitle>
          <SheetDescription>{t('admin.customers.detail.groups.edit_description')}</SheetDescription>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          {error && (
            <p className="text-sm text-destructive" role="alert">
              {error}
            </p>
          )}
          <Field>
            <FieldLabel>{t('admin.fields.customer.customer_groups.label')}</FieldLabel>
            <ResourceMultiAutocomplete
              {...customerGroupAutocompleteProps(`customer-detail-groups-picker-${storeId}`)}
              initialItems={groupsData?.data}
              value={groupIds}
              onChange={setGroupIds}
            />
          </Field>
        </div>
        <SheetFooter>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => onOpenChange(false)}
            disabled={isPending}
          >
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" size="sm" onClick={handleSave} disabled={isPending || !dirty}>
            {isPending ? t('admin.actions.saving') : t('admin.actions.save')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Lifetime Stats
// ---------------------------------------------------------------------------

function LifetimeStatsCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
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
        <Stat
          label={t('admin.pages.customers.detail.stat_total_spent')}
          value={customer.display_total_spent ?? '—'}
        />
        <Stat label={t('admin.pages.customers.detail.stat_orders')} value={String(orders)} />
        <Stat
          label={t('admin.pages.customers.detail.stat_avg_order_value')}
          value={aovDisplay ?? '—'}
        />
        <Stat
          label={t('admin.pages.customers.detail.section_store_credit')}
          value={customer.display_available_store_credit_total ?? '—'}
        />
        <Stat
          label={t('admin.customers.detail.customer_since')}
          value={<RelativeTime iso={customer.created_at} />}
        />
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

function LastOrderCard({ order }: { order: Order }) {
  const { t } = useTranslation()
  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.customers.detail.last_order_placed')}</CardTitle>
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
  const { t } = useTranslation()
  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.pages.customers.detail.section_orders')}</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">{t('admin.common.loading')}</p>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>
          {t('admin.pages.customers.detail.section_orders')}
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
              {t('admin.actions.view_all')} →
            </Link>
          </CardAction>
        )}
      </CardHeader>
      {orders.length === 0 ? (
        <CardContent>
          <p className="text-sm text-muted-foreground">
            {t('admin.pages.customers.detail.orders_empty')}
          </p>
        </CardContent>
      ) : (
        <CardContent className="p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b text-muted-foreground text-left">
                <th className="px-6 py-2 font-normal">
                  {t('admin.customers.detail.orders_table.order')}
                </th>
                <th className="px-6 py-2 font-normal">
                  {t('admin.customers.detail.orders_table.date')}
                </th>
                <th className="px-6 py-2 font-normal">{t('admin.fields.status.label')}</th>
                <th className="px-6 py-2 font-normal text-right">
                  {t('admin.fields.total.label')}
                </th>
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
  const { t } = useTranslation()
  const [editing, setEditing] = useState(false)
  const [note, setNote] = useState(customer.internal_note_html ?? '')

  const mutation = useUpdateCustomer(customer.id)

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.pages.customers.detail.section_internal_note')}</CardTitle>
        {!editing && (
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setEditing(true)}>
              <PencilIcon className="size-4" />
              {t('admin.actions.edit')}
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
              placeholder={t('admin.fields.customer.internal_note.placeholder')}
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
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                size="sm"
                disabled={mutation.isPending}
                onClick={() =>
                  mutation.mutate({ internal_note: note }, { onSuccess: () => setEditing(false) })
                }
              >
                {mutation.isPending ? t('admin.actions.saving') : t('admin.actions.save')}
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
          <p className="text-sm text-muted-foreground">
            {t('admin.customers.detail.no_internal_notes')}
          </p>
        )}
      </CardContent>
    </Card>
  )
}

// ---------------------------------------------------------------------------
// Addresses
// ---------------------------------------------------------------------------

function AddressesCard({ customer }: { customer: Customer }) {
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<Address | null>(null)
  const confirm = useConfirm()
  const addresses = useMemo(() => {
    const isDefault = (a: Address) => a.is_default_billing || a.is_default_shipping
    return [...(customer.addresses ?? [])].sort(
      (a, b) => Number(isDefault(b)) - Number(isDefault(a)),
    )
  }, [customer.addresses])

  const deleteMutation = useDeleteCustomerAddress(customer.id)

  const updateMutation = useUpdateCustomerAddress(customer.id)
  function setDefault(params: { id: string; kind: 'billing' | 'shipping' }) {
    return updateMutation.mutate({
      id: params.id,
      params: {
        [params.kind === 'billing' ? 'is_default_billing' : 'is_default_shipping']: true,
      },
    })
  }

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.pages.customers.detail.section_addresses')}
            {addresses.length > 0 && <Badge variant="outline">{addresses.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.detail.add_address')}
            </Button>
          </CardAction>
        </CardHeader>
        {addresses.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {t('admin.pages.customers.detail.addresses_empty')}
            </p>
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
                    {addr.full_name ?? '—'}
                    <span className="ml-2 inline-flex gap-1">
                      {addr.is_default_billing && (
                        <Badge variant="outline">
                          {t('admin.customers.detail.address.default_billing')}
                        </Badge>
                      )}
                      {addr.is_default_shipping && (
                        <Badge variant="outline">
                          {t('admin.customers.detail.address.default_shipping')}
                        </Badge>
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
                      {t('admin.actions.edit')}
                    </DropdownMenuItem>
                    {!addr.is_default_billing && (
                      <DropdownMenuItem
                        onClick={() => setDefault({ id: addr.id, kind: 'billing' })}
                      >
                        {t('admin.customers.detail.address.set_default_billing')}
                      </DropdownMenuItem>
                    )}
                    {!addr.is_default_shipping && (
                      <DropdownMenuItem
                        onClick={() => setDefault({ id: addr.id, kind: 'shipping' })}
                      >
                        {t('admin.customers.detail.address.set_default_shipping')}
                      </DropdownMenuItem>
                    )}
                    <DropdownMenuItem
                      className="text-destructive focus:text-destructive"
                      onClick={async () => {
                        if (
                          await confirm({
                            message: t('admin.customers.detail.address.delete_confirm_message'),
                            variant: 'destructive',
                            confirmLabel: t('admin.actions.delete'),
                          })
                        ) {
                          deleteMutation.mutate(addr.id)
                        }
                      }}
                    >
                      <TrashIcon className="size-4" />
                      {t('admin.actions.delete')}
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
          title={t('admin.pages.customers.detail.add_address')}
        />
      )}
      {editing && (
        <CustomerAddressDialog
          customer={customer}
          address={editing}
          onOpenChange={(o) => {
            if (!o) setEditing(null)
          }}
          title={t('admin.pages.customers.detail.edit_address')}
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
  const createMutation = useCreateCustomerAddress(customer.id)
  const updateMutation = useUpdateCustomerAddress(customer.id)
  const mutation = isEdit ? updateMutation : createMutation

  // Returns the promise so `AddressFormDialog` can map 422 errors onto fields.
  // Closes the sheet only on success.
  async function handleSave(params: AddressParams) {
    if (isEdit) {
      await updateMutation.mutateAsync({ id: address.id, params })
    } else {
      await createMutation.mutateAsync(params)
    }
    onOpenChange(false)
  }

  // Wait for countries before mounting so the country/state lazy initializer
  // can resolve the address's country_iso/state_abbr to a real option.
  if (countriesLoading) return null

  return (
    <AddressFormDialog
      address={address}
      open
      onOpenChange={onOpenChange}
      onSave={handleSave}
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
  const { t } = useTranslation()
  const [addOpen, setAddOpen] = useState(false)
  const [editing, setEditing] = useState<StoreCredit | null>(null)
  const confirm = useConfirm()
  const credits = customer.store_credits ?? []

  const deleteMutation = useDeleteCustomerStoreCredit(customer.id)

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>
            {t('admin.customers.detail.store_credit.title')}
            {credits.length > 0 && <Badge>{credits.length}</Badge>}
          </CardTitle>
          <CardAction>
            <Button size="sm" variant="outline" onClick={() => setAddOpen(true)}>
              <PlusIcon className="size-4" />
              {t('admin.pages.customers.detail.issue_credit')}
            </Button>
          </CardAction>
        </CardHeader>
        {credits.length === 0 ? (
          <CardContent>
            <p className="text-sm text-muted-foreground">
              {t('admin.customers.detail.store_credit.empty')}
            </p>
          </CardContent>
        ) : (
          <CardContent className="p-0">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b text-muted-foreground text-left">
                  <th className="px-6 py-2 font-normal">{t('admin.fields.amount.label')}</th>
                  <th className="px-6 py-2 font-normal">
                    {t('admin.customers.detail.store_credit.table.used')}
                  </th>
                  <th className="px-6 py-2 font-normal">
                    {t('admin.customers.detail.store_credit.table.remaining')}
                  </th>
                  <th className="px-6 py-2 font-normal">
                    {t('admin.customers.detail.store_credit.table.category')}
                  </th>
                  <th className="px-6 py-2 font-normal">
                    {t('admin.customers.detail.store_credit.table.memo')}
                  </th>
                  <th className="px-6 py-2 w-10" />
                </tr>
              </thead>
              <tbody>
                {credits.map((sc: StoreCredit) => (
                  <tr key={sc.id} className="border-b last:border-b-0">
                    <td className="px-6 py-3 font-medium tabular-nums">
                      {sc.display_amount ?? sc.amount}
                    </td>
                    <td className="px-6 py-3 tabular-nums">
                      {sc.display_amount_used ?? sc.amount_used}
                    </td>
                    <td className="px-6 py-3 tabular-nums">
                      {sc.display_amount_remaining ?? sc.amount_remaining}
                    </td>
                    <td className="px-6 py-3 text-muted-foreground">{sc.category_name ?? '—'}</td>
                    <td className="px-6 py-3 text-muted-foreground">{sc.memo ?? '—'}</td>
                    <td className="px-6 py-3 text-right">
                      <DropdownMenu>
                        <DropdownMenuTrigger asChild>
                          <Button variant="ghost" size="icon-xs">
                            <EllipsisVerticalIcon className="size-4" />
                          </Button>
                        </DropdownMenuTrigger>
                        <DropdownMenuContent align="end">
                          <DropdownMenuItem onClick={() => setEditing(sc)}>
                            <PencilIcon className="size-4" />
                            {t('admin.actions.edit')}
                          </DropdownMenuItem>
                          <DropdownMenuItem
                            className="text-destructive focus:text-destructive"
                            onClick={async () => {
                              if (
                                await confirm({
                                  message: t(
                                    'admin.customers.detail.store_credit.delete_confirm_message',
                                  ),
                                  variant: 'destructive',
                                  confirmLabel: t('admin.actions.delete'),
                                })
                              ) {
                                deleteMutation.mutate(sc.id)
                              }
                            }}
                          >
                            <TrashIcon className="size-4" />
                            {t('admin.actions.delete')}
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
      {editing && (
        <EditStoreCreditDialog
          customerId={customer.id}
          credit={editing}
          onOpenChange={(o) => {
            if (!o) setEditing(null)
          }}
        />
      )}
    </>
  )
}

// Base UI's `<SelectValue>` defaults to rendering the raw `value` (the
// prefixed category ID). Use the children render-prop to look up the
// matching category's name from the dynamic options list.
function StoreCreditCategorySelect({
  id,
  value,
  onChange,
  required,
}: {
  id: string
  value: string
  onChange: (next: string) => void
  required?: boolean
}) {
  const { t } = useTranslation()
  const { data, isLoading } = useStoreCreditCategories()
  const categories = data?.data ?? []

  return (
    <Select value={value} onValueChange={onChange}>
      <SelectTrigger id={id} aria-required={required}>
        <SelectValue
          placeholder={isLoading ? t('admin.common.loading') : t('admin.common.select_placeholder')}
        >
          {(v) => {
            const category = categories.find((c) => c.id === v)
            return category ? category.name : (v as string)
          }}
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        {categories.map((c) => (
          <SelectItem key={c.id} value={c.id}>
            {c.name}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function EditStoreCreditDialog({
  customerId,
  credit,
  onOpenChange,
}: {
  customerId: string
  credit: StoreCredit
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Server rejects amount changes once any of it has been used. Lock the
  // field so the merchant doesn't submit a value that will only come back
  // as a 422 store_credit_in_use.
  const amountLocked = Number(credit.amount_used ?? 0) > 0

  const localeForCurrency = useCurrencyLocale()
  // Currency is locked on edit, so resolve its market locale once. The amount
  // hydrates from the canonical API value (`"50.00"`) but is displayed/edited
  // in that locale's format (`"50,00"` for EUR); on submit we normalize back to
  // canonical. Displaying in the same locale we normalize from keeps an
  // untouched amount from being mangled on save.
  const creditLocale = localeForCurrency(credit.currency) || 'en'
  const { decimal } = currencyParts(credit.currency, creditLocale)

  const form = useForm<EditStoreCreditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(editStoreCreditFormSchema) as any,
    defaultValues: {
      amount: credit.amount ? credit.amount.replace('.', decimal) : '',
      category_id: credit.category_id ?? '',
      memo: credit.memo ?? '',
    },
  })
  const { errors } = form.formState

  const mutation = useUpdateCustomerStoreCredit(customerId, credit.id)

  async function onSubmit(values: EditStoreCreditFormValues) {
    const params: StoreCreditUpdateParams = {}

    if (!amountLocked) {
      const amountValue = values.amount.toString().trim()
      // Normalize from the credit's display locale to the canonical
      // `"1234.56"` the API expects.
      if (amountValue) {
        params.amount = normalizeMoneyInput(amountValue, creditLocale)
      }
    }

    if (values.category_id.trim()) params.category_id = values.category_id

    params.memo = values.memo

    try {
      await mutation.mutateAsync(params)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.customers.detail.edit_credit')}</DialogTitle>
          <DialogDescription>
            {t('admin.customers.detail.store_credit.edit_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="edit-sc-amount">
                    {t('admin.fields.store_credit.amount.label')}
                  </FieldLabel>
                  <Input
                    id="edit-sc-amount"
                    type="text"
                    inputMode="decimal"
                    disabled={amountLocked}
                    aria-invalid={!!errors.amount || undefined}
                    {...form.register('amount')}
                  />
                  <FieldError errors={[errors.amount]} />
                </Field>
                <Field>
                  {/* Currency is locked: the API doesn't accept `currency`
                      on update (changing it on a partially-used credit
                      would invalidate amount_used / amount_remaining). We
                      surface it disabled so the merchant always sees which
                      currency the credit is in. */}
                  <FieldLabel htmlFor="edit-sc-currency">
                    {t('admin.fields.store_credit.currency.label')}
                  </FieldLabel>
                  <CurrencySelect id="edit-sc-currency" value={credit.currency} disabled />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="edit-sc-category">
                  {t('admin.fields.store_credit.category_id.label')}
                </FieldLabel>
                <Controller
                  name="category_id"
                  control={form.control}
                  render={({ field }) => (
                    <StoreCreditCategorySelect
                      id="edit-sc-category"
                      value={field.value}
                      onChange={field.onChange}
                    />
                  )}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="edit-sc-memo">
                  {t('admin.fields.store_credit.memo.label')}
                </FieldLabel>
                <Textarea
                  id="edit-sc-memo"
                  rows={3}
                  placeholder={t('admin.fields.store_credit.memo.placeholder')}
                  aria-invalid={!!errors.memo || undefined}
                  {...form.register('memo')}
                />
                <FieldError errors={[errors.memo]} />
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

function IssueStoreCreditDialog({
  customerId,
  open,
  onOpenChange,
}: {
  customerId: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  // Seed `currency` with the store default so the merchant doesn't have to
  // pick one explicitly — `CurrencySelect` displays it but no longer commits
  // it via onChange, so the form value needs to start populated.
  const { defaultCurrency } = useStore()
  const form = useForm<IssueStoreCreditFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(issueStoreCreditFormSchema) as any,
    defaultValues: { amount: '', currency: defaultCurrency, category_id: '', memo: '' },
  })
  const { errors } = form.formState

  const mutation = useCreateCustomerStoreCredit(customerId)
  const localeForCurrency = useCurrencyLocale()

  // Clear any prior submission state when the dialog re-opens so a fresh form
  // is presented (otherwise stale "Issue $20" values linger across opens).
  useEffect(() => {
    if (open) {
      form.reset({ amount: '', currency: defaultCurrency, category_id: '', memo: '' })
    }
  }, [open, form, defaultCurrency])

  // Switching currency re-displays the amount in the new currency's locale
  // format, so the value the merchant sees always matches the locale it will be
  // normalized under on submit. Without this, `25.00` typed under USD would be
  // re-read under EUR's `de` locale (where `.` groups thousands) and persist as
  // 2500. Canonicalize from the old locale, then swap to the new locale's
  // decimal separator.
  function handleCurrencyChange(
    next: string,
    field: { value: string; onChange: (v: string) => void },
  ) {
    const prev = field.value
    field.onChange(next)
    const raw = form.getValues('amount')?.trim()
    if (!raw) return
    const canonical = normalizeMoneyInput(raw, localeForCurrency(prev) || 'en')
    const { decimal } = currencyParts(next, localeForCurrency(next) || 'en')
    form.setValue('amount', decimal === '.' ? canonical : canonical.replace('.', decimal))
  }

  async function onSubmit(values: IssueStoreCreditFormValues) {
    try {
      await mutation.mutateAsync({
        // Normalize the merchant's localized input (entered under the selected
        // currency's market locale) to the canonical `"1234.56"` the API
        // expects. The server never parses comma-vs-period.
        amount: normalizeMoneyInput(values.amount, localeForCurrency(values.currency) || 'en'),
        currency: values.currency,
        category_id: values.category_id,
        memo: values.memo || undefined,
      })
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('admin.pages.customers.detail.issue_credit')}</DialogTitle>
          <DialogDescription>
            {t('admin.customers.detail.store_credit.add_description')}
          </DialogDescription>
        </DialogHeader>
        <form onSubmit={form.handleSubmit(onSubmit)}>
          <DialogBody>
            {errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {errors.root.message}
              </p>
            )}
            <FieldGroup>
              <div className="grid grid-cols-2 gap-3">
                <Field>
                  <FieldLabel htmlFor="sc-amount">
                    {t('admin.fields.store_credit.amount.label')}
                  </FieldLabel>
                  <Input
                    id="sc-amount"
                    type="text"
                    inputMode="decimal"
                    required
                    aria-invalid={!!errors.amount || undefined}
                    {...form.register('amount')}
                  />
                  <FieldError errors={[errors.amount]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="sc-currency">
                    {t('admin.fields.store_credit.currency.label')}
                  </FieldLabel>
                  <Controller
                    name="currency"
                    control={form.control}
                    render={({ field }) => (
                      <CurrencySelect
                        id="sc-currency"
                        value={field.value || ''}
                        onChange={(next) => handleCurrencyChange(next, field)}
                        required
                      />
                    )}
                  />
                </Field>
              </div>
              <Field>
                <FieldLabel htmlFor="sc-category">
                  {t('admin.fields.store_credit.category_id.label')}
                </FieldLabel>
                <Controller
                  name="category_id"
                  control={form.control}
                  render={({ field }) => (
                    <StoreCreditCategorySelect
                      id="sc-category"
                      value={field.value}
                      onChange={field.onChange}
                      required
                    />
                  )}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="sc-memo">
                  {t('admin.fields.store_credit.memo.label')}
                </FieldLabel>
                <Textarea
                  id="sc-memo"
                  rows={3}
                  placeholder={t('admin.fields.store_credit.memo.placeholder')}
                  aria-invalid={!!errors.memo || undefined}
                  {...form.register('memo')}
                />
                <FieldError errors={[errors.memo]} />
              </Field>
            </FieldGroup>
          </DialogBody>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={mutation.isPending}>
              {mutation.isPending
                ? t('admin.actions.saving')
                : t('admin.pages.customers.detail.issue_credit')}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
