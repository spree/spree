import { zodResolver } from '@hookform/resolvers/zod'
import type {
  StockItem,
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { ChevronDownIcon, ChevronRightIcon, PlusIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import {
  CountryCombobox,
  StateCombobox,
  useCountryStates,
} from '@/components/spree/country-state-fields'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { useStockItems, useUpdateStockItem } from '@/hooks/use-stock-items'
import {
  useCreateStockLocation,
  useDeleteStockLocation,
  useStockLocation,
  useUpdateStockLocation,
} from '@/hooks/use-stock-locations'
import { Subject } from '@/lib/permissions'
import '@/tables/stock-locations'

// Adds `?edit=<id>` and `?new=1` on top of the standard table search schema
// so we can deep-link to the create / edit sheet.
const stockSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/stock-locations')({
  validateSearch: stockSearchSchema,
  component: StockLocationsPage,
})

const KIND_OPTIONS = [
  { value: 'warehouse', label: 'Warehouse' },
  { value: 'store', label: 'Store' },
  { value: 'fulfillment_center', label: 'Fulfillment center' },
] as const

const PICKUP_POLICY_OPTIONS = [
  { value: 'local', label: 'Only items at this location' },
  { value: 'any', label: 'Allow transfers from other locations' },
] as const

function StockLocationsPage() {
  // Cast: Route.useSearch's inferred type unions with the parent layout's
  // search shape, which doesn't know about our `edit`/`new` keys. The runtime
  // schema (`stockSearchSchema`) is still the source of truth — this just
  // gets us past the parent-union narrowing.
  const search = Route.useSearch() as z.infer<typeof stockSearchSchema>
  const navigate = useNavigate()

  const editId = search.edit
  const isCreating = !!search.new

  function closeSheet() {
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })
  }

  function openCreate() {
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })
  }

  function openEdit(id: string) {
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })
  }

  useRowClickBridge('data-stock-location-id', openEdit)

  return (
    <>
      <ResourceTable<StockLocation>
        tableKey="stock-locations"
        queryKey="stock-locations"
        queryFn={(params) => adminClient.stockLocations.list(params)}
        searchParams={search}
        actions={
          <Can I="create" a={Subject.StockLocation}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              Add stock location
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateStockLocationSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditStockLocationSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

// ============================================================================
// Form
// ============================================================================

const formSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  admin_name: z.string().optional(),
  kind: z.string().min(1),
  active: z.boolean(),
  default: z.boolean(),
  propagate_all_variants: z.boolean(),
  backorderable_default: z.boolean(),
  address1: z.string().optional(),
  address2: z.string().optional(),
  city: z.string().optional(),
  zipcode: z.string().optional(),
  phone: z.string().optional(),
  company: z.string().optional(),
  country_iso: z.string().optional(),
  state_abbr: z.string().optional(),
  state_name: z.string().optional(),
  pickup_enabled: z.boolean(),
  pickup_stock_policy: z.enum(['local', 'any']),
  pickup_ready_in_minutes: z.coerce.number().int().min(0).optional().nullable(),
  pickup_instructions: z.string().optional(),
})

type FormValues = z.infer<typeof formSchema>

const DEFAULT_VALUES: FormValues = {
  name: '',
  admin_name: '',
  kind: 'warehouse',
  active: true,
  default: false,
  propagate_all_variants: false,
  backorderable_default: false,
  address1: '',
  address2: '',
  city: '',
  zipcode: '',
  phone: '',
  company: '',
  country_iso: '',
  state_abbr: '',
  state_name: '',
  pickup_enabled: false,
  pickup_stock_policy: 'local',
  pickup_ready_in_minutes: null,
  pickup_instructions: '',
}

function stockLocationToFormValues(sl: StockLocation): FormValues {
  return {
    name: sl.name,
    admin_name: sl.admin_name ?? '',
    kind: sl.kind ?? 'warehouse',
    active: sl.active,
    default: sl.default,
    propagate_all_variants: sl.propagate_all_variants,
    backorderable_default: sl.backorderable_default,
    address1: sl.address1 ?? '',
    address2: sl.address2 ?? '',
    city: sl.city ?? '',
    zipcode: sl.zipcode ?? '',
    phone: sl.phone ?? '',
    company: sl.company ?? '',
    country_iso: sl.country_iso ?? '',
    state_abbr: sl.state_abbr ?? '',
    state_name: sl.state_name ?? '',
    pickup_enabled: sl.pickup_enabled,
    pickup_stock_policy: (sl.pickup_stock_policy as 'local' | 'any') ?? 'local',
    pickup_ready_in_minutes: sl.pickup_ready_in_minutes ?? null,
    pickup_instructions: sl.pickup_instructions ?? '',
  }
}

// Drops blank strings → undefined so we don't overwrite null fields with "".
function formValuesToParams(v: FormValues): StockLocationCreateParams & StockLocationUpdateParams {
  const blank = (s: string | null | undefined) => (s && s.length > 0 ? s : undefined)
  return {
    name: v.name,
    admin_name: blank(v.admin_name),
    kind: v.kind,
    active: v.active,
    default: v.default,
    propagate_all_variants: v.propagate_all_variants,
    backorderable_default: v.backorderable_default,
    address1: blank(v.address1),
    address2: blank(v.address2),
    city: blank(v.city),
    zipcode: blank(v.zipcode),
    phone: blank(v.phone),
    company: blank(v.company),
    country_iso: blank(v.country_iso),
    state_abbr: blank(v.state_abbr),
    state_name: blank(v.state_name),
    pickup_enabled: v.pickup_enabled,
    pickup_stock_policy: v.pickup_stock_policy,
    pickup_ready_in_minutes: v.pickup_ready_in_minutes ?? null,
    pickup_instructions: blank(v.pickup_instructions),
  }
}

// ============================================================================
// Create Sheet
// ============================================================================

function CreateStockLocationSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const createMutation = useCreateStockLocation()

  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: FormValues) {
    const params = formValuesToParams(values) as StockLocationCreateParams
    await createMutation.mutateAsync(params)
    form.reset(DEFAULT_VALUES)
    onOpenChange(false)
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DEFAULT_VALUES)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Add stock location</SheetTitle>
          <SheetDescription>
            A place where inventory lives — a warehouse, store, or third-party fulfillment center.
          </SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <StockLocationFormFields form={form} />
          </div>
          <SheetFooter>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Creating…' : 'Create stock location'}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

// ============================================================================
// Edit Sheet
// ============================================================================

function EditStockLocationSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { data: stockLocation, isLoading } = useStockLocation(id)
  const updateMutation = useUpdateStockLocation(id)
  const deleteMutation = useDeleteStockLocation()
  const confirm = useConfirm()

  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  // Reset form when the loaded resource arrives — keeps the inputs in sync
  // with whatever the server last persisted (including external edits).
  useEffect(() => {
    if (stockLocation) {
      form.reset(stockLocationToFormValues(stockLocation))
    }
  }, [stockLocation, form])

  async function onSubmit(values: FormValues) {
    const params = formValuesToParams(values) as StockLocationUpdateParams
    await updateMutation.mutateAsync(params)
    form.reset(values)
    onOpenChange(false)
  }

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete stock location?',
      message: `${stockLocation?.name ?? 'This location'} will be removed. Any orders that referenced it will keep the historical record.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{stockLocation?.name ?? 'Edit stock location'}</SheetTitle>
          <SheetDescription>
            Update inventory location, address, and pickup options.
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <StockLocationFormFields form={form} />
              <StockItemsPanel stockLocationId={id} />
            </div>
            <SheetFooter>
              <Can I="destroy" a={Subject.StockLocation}>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={onDelete}
                  disabled={form.formState.isSubmitting || deleteMutation.isPending}
                  className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
                >
                  Delete
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? 'Saving…' : 'Save'}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}

// ============================================================================
// Stock Items panel — adjust on-hand counts at this location
// ============================================================================

function StockItemsPanel({ stockLocationId }: { stockLocationId: string }) {
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const { data, isFetching } = useStockItems({
    stock_location_id_eq: stockLocationId,
    variant_sku_or_variant_product_name_cont: search.length >= 2 ? search : undefined,
    page,
    limit: 25,
  })
  const items = data?.data ?? []
  const totalPages = data?.meta?.pages ?? 1

  // Group by product so multi-variant products read as one card with sub-rows
  // instead of as N unrelated rows. Sort: low stock first, then product name.
  const groups = useMemo(() => groupItemsByProduct(items), [items])

  return (
    <div className="rounded-md border">
      <div className="flex items-center justify-between gap-2 border-b px-4 py-3">
        <div>
          <h3 className="text-sm font-medium">Stock at this location</h3>
          <p className="text-xs text-muted-foreground">
            Inline edits save immediately. For broader changes, edit the product directly.
          </p>
        </div>
        <Input
          placeholder="Search SKU or product…"
          value={search}
          onChange={(e) => {
            setSearch(e.target.value)
            setPage(1)
          }}
          className="h-8 w-56"
        />
      </div>
      {isFetching && items.length === 0 ? (
        <div className="px-4 py-6 text-sm text-muted-foreground">Loading…</div>
      ) : items.length === 0 ? (
        <div className="px-4 py-6 text-sm text-muted-foreground">
          No stock items {search ? 'match your search' : 'at this location yet'}.
        </div>
      ) : (
        <div className="divide-y">
          {groups.map((group) => (
            <ProductGroup key={group.productId} group={group} defaultOpen={groups.length <= 5} />
          ))}
        </div>
      )}
      {totalPages > 1 && (
        <div className="flex items-center justify-between border-t px-4 py-2">
          <span className="text-xs text-muted-foreground">
            Page {page} of {totalPages}
          </span>
          <div className="flex gap-1">
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1 || isFetching}
            >
              Prev
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages || isFetching}
            >
              Next
            </Button>
          </div>
        </div>
      )}
    </div>
  )
}

interface StockItemGroup {
  productId: string
  productName: string
  items: StockItem[]
  hasLowStock: boolean
}

const LOW_STOCK_THRESHOLD = 5

function groupItemsByProduct(items: StockItem[]): StockItemGroup[] {
  const map = new Map<string, StockItemGroup>()
  for (const item of items) {
    const productId = item.variant?.product_id ?? '__unknown__'
    const productName = item.variant?.product_name ?? 'Unknown product'
    let group = map.get(productId)
    if (!group) {
      group = { productId, productName, items: [], hasLowStock: false }
      map.set(productId, group)
    }
    group.items.push(item)
    if (item.count_on_hand < LOW_STOCK_THRESHOLD && !item.backorderable) {
      group.hasLowStock = true
    }
  }
  const groups = Array.from(map.values())
  groups.sort((a, b) => {
    if (a.hasLowStock !== b.hasLowStock) return a.hasLowStock ? -1 : 1
    return a.productName.localeCompare(b.productName)
  })
  return groups
}

function ProductGroup({ group, defaultOpen }: { group: StockItemGroup; defaultOpen: boolean }) {
  const [open, setOpen] = useState(defaultOpen)

  return (
    <Collapsible open={open} onOpenChange={setOpen}>
      <CollapsibleTrigger className="flex w-full items-center gap-2 px-4 py-2 text-left hover:bg-accent">
        {open ? (
          <ChevronDownIcon className="size-4 text-muted-foreground" />
        ) : (
          <ChevronRightIcon className="size-4 text-muted-foreground" />
        )}
        <div className="min-w-0 flex-1">
          <div className="truncate text-sm font-medium">{group.productName}</div>
          <div className="truncate text-xs text-muted-foreground">
            {group.items.length} {group.items.length === 1 ? 'variant' : 'variants'}
            {group.hasLowStock && ' · low stock'}
          </div>
        </div>
      </CollapsibleTrigger>
      <CollapsibleContent>
        <table className="w-full text-sm">
          <thead className="sticky top-0 bg-card text-xs text-muted-foreground">
            <tr className="border-y">
              <th className="px-4 py-2 text-left font-medium">Variant</th>
              <th className="px-3 py-2 text-right font-medium">On hand</th>
              <th className="px-3 py-2 text-left font-medium">Backorder</th>
              <th className="px-3 py-2" />
            </tr>
          </thead>
          <tbody>
            {group.items.map((item) => (
              <StockItemRow key={item.id} item={item} />
            ))}
          </tbody>
        </table>
      </CollapsibleContent>
    </Collapsible>
  )
}

function StockItemRow({ item }: { item: StockItem }) {
  const { storeId } = Route.useParams()
  const updateMutation = useUpdateStockItem(item.id)
  const [count, setCount] = useState<number>(item.count_on_hand)
  const [backorderable, setBackorderable] = useState<boolean>(item.backorderable)

  useEffect(() => {
    setCount(item.count_on_hand)
    setBackorderable(item.backorderable)
  }, [item.count_on_hand, item.backorderable])

  const dirty = count !== item.count_on_hand || backorderable !== item.backorderable
  const variant = item.variant
  const optionsText = variant?.options_text
  const sku = variant?.sku
  const productId = variant?.product_id
  const variantLabel = optionsText || sku || 'Default'
  const isLowStock = count < LOW_STOCK_THRESHOLD && !backorderable

  function save() {
    if (!dirty) return
    updateMutation.mutate({
      count_on_hand: count,
      backorderable,
    })
  }

  return (
    <tr className="border-b last:border-b-0">
      <td className="px-4 py-2">
        <div className="min-w-0">
          {productId ? (
            <Link
              to="/$storeId/products/$productId"
              params={{ storeId, productId }}
              className="text-sm font-medium hover:underline"
            >
              {variantLabel}
            </Link>
          ) : (
            <span className="text-sm font-medium">{variantLabel}</span>
          )}
          {sku && <div className="text-xs text-muted-foreground">SKU {sku}</div>}
        </div>
      </td>
      <td className="px-3 py-2 text-right">
        <Input
          type="number"
          value={count}
          onChange={(e) => setCount(Number(e.target.value))}
          className={`ml-auto w-20 text-right ${isLowStock ? 'border-amber-500' : ''}`}
          aria-label={`On hand for ${variantLabel}`}
        />
      </td>
      <td className="px-3 py-2">
        <Switch
          checked={backorderable}
          onCheckedChange={setBackorderable}
          aria-label={`Backorderable for ${variantLabel}`}
        />
      </td>
      <td className="px-3 py-2 text-right">
        <Button
          type="button"
          size="sm"
          variant="outline"
          onClick={save}
          disabled={!dirty || updateMutation.isPending}
        >
          {updateMutation.isPending ? '…' : 'Save'}
        </Button>
      </td>
    </tr>
  )
}

// ============================================================================
// Shared form fields
// ============================================================================

function StockLocationFormFields({
  form,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
}) {
  const countryIso = form.watch('country_iso')
  const { states } = useCountryStates(countryIso)

  const pickupEnabled = form.watch('pickup_enabled')

  return (
    <FieldGroup>
      <Field>
        <FieldLabel htmlFor="name">Name</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder="Brooklyn warehouse"
          {...form.register('name')}
          aria-invalid={!!form.formState.errors.name}
        />
        {form.formState.errors.name && (
          <p className="text-sm text-destructive">{form.formState.errors.name.message}</p>
        )}
      </Field>

      <Field>
        <FieldLabel htmlFor="admin_name">Internal name</FieldLabel>
        <Input
          id="admin_name"
          placeholder="Optional — shown only in the admin"
          {...form.register('admin_name')}
        />
      </Field>

      <Field>
        <FieldLabel>Kind</FieldLabel>
        <Controller
          name="kind"
          control={form.control}
          render={({ field }) => (
            <Select items={KIND_OPTIONS} value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {KIND_OPTIONS.map((opt) => (
                  <SelectItem key={opt.value} value={opt.value}>
                    {opt.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      <ToggleField
        form={form}
        name="active"
        label="Active"
        description="Inactive locations don't appear in fulfillment selection."
      />
      <ToggleField
        form={form}
        name="default"
        label="Default location"
        description="New stock items propagate here. Only one location can be default."
      />
      <ToggleField
        form={form}
        name="backorderable_default"
        label="Backorderable by default"
        description="New stock items at this location allow backorders."
      />
      <ToggleField
        form={form}
        name="propagate_all_variants"
        label="Auto-create stock items for all variants"
        description="When a new variant is added anywhere, create a zero-quantity stock item here."
      />

      <div className="border-t border-border pt-4">
        <h3 className="mb-3 text-sm font-medium">Address</h3>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="address1">Address line 1</FieldLabel>
            <Input id="address1" {...form.register('address1')} />
          </Field>
          <Field>
            <FieldLabel htmlFor="address2">Address line 2</FieldLabel>
            <Input id="address2" {...form.register('address2')} />
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field>
              <FieldLabel htmlFor="city">City</FieldLabel>
              <Input id="city" {...form.register('city')} />
            </Field>
            <Field>
              <FieldLabel htmlFor="zipcode">Postal code</FieldLabel>
              <Input id="zipcode" {...form.register('zipcode')} />
            </Field>
          </div>
          <Field>
            <FieldLabel>Country</FieldLabel>
            <Controller
              name="country_iso"
              control={form.control}
              render={({ field }) => (
                <CountryCombobox
                  value={field.value}
                  onValueChange={(iso) => {
                    field.onChange(iso)
                    // Clear both shapes so a previously-typed free-text state
                    // doesn't bleed across countries.
                    form.setValue('state_abbr', '', { shouldDirty: true })
                    form.setValue('state_name', '', { shouldDirty: true })
                  }}
                />
              )}
            />
          </Field>
          {states.length > 0 ? (
            <Field>
              <FieldLabel>State / Province</FieldLabel>
              <Controller
                name="state_abbr"
                control={form.control}
                render={({ field }) => (
                  <StateCombobox
                    countryIso={countryIso}
                    states={states}
                    value={field.value}
                    onValueChange={field.onChange}
                  />
                )}
              />
            </Field>
          ) : (
            <Field>
              <FieldLabel htmlFor="state_name">State / Province</FieldLabel>
              <Input id="state_name" {...form.register('state_name')} />
            </Field>
          )}
          <Field>
            <FieldLabel htmlFor="phone">Phone</FieldLabel>
            <Input id="phone" {...form.register('phone')} />
          </Field>
          <Field>
            <FieldLabel htmlFor="company">Company</FieldLabel>
            <Input id="company" {...form.register('company')} />
          </Field>
        </FieldGroup>
      </div>

      <div className="border-t border-border pt-4">
        <h3 className="mb-3 text-sm font-medium">Pickup</h3>
        <FieldGroup>
          <ToggleField
            form={form}
            name="pickup_enabled"
            label="Allow customer pickup"
            description="Show this location to customers as a pickup option at checkout."
          />
          {pickupEnabled && (
            <>
              <Field>
                <FieldLabel>Stock policy</FieldLabel>
                <Controller
                  name="pickup_stock_policy"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={PICKUP_POLICY_OPTIONS}
                      value={field.value}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {PICKUP_POLICY_OPTIONS.map((opt) => (
                          <SelectItem key={opt.value} value={opt.value}>
                            {opt.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="pickup_ready_in_minutes">Ready in (minutes)</FieldLabel>
                <Input
                  id="pickup_ready_in_minutes"
                  type="number"
                  min={0}
                  step={5}
                  placeholder="60"
                  {...form.register('pickup_ready_in_minutes', {
                    setValueAs: (v: unknown) => (v === '' || v == null ? null : Number(v)),
                  })}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="pickup_instructions">Pickup instructions</FieldLabel>
                <Textarea
                  id="pickup_instructions"
                  placeholder="Where the customer should go to collect their order."
                  rows={3}
                  {...form.register('pickup_instructions')}
                />
              </Field>
            </>
          )}
        </FieldGroup>
      </div>
    </FieldGroup>
  )
}

function ToggleField({
  form,
  name,
  label,
  description,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: any
  name: keyof FormValues
  label: string
  description?: string
}) {
  return (
    <Field>
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col">
          <FieldLabel htmlFor={String(name)} className="cursor-pointer">
            {label}
          </FieldLabel>
          {description && <span className="text-xs text-muted-foreground">{description}</span>}
        </div>
        <Controller
          name={name as string}
          control={form.control}
          render={({ field }) => (
            <Switch id={String(name)} checked={!!field.value} onCheckedChange={field.onChange} />
          )}
        />
      </div>
    </Field>
  )
}
