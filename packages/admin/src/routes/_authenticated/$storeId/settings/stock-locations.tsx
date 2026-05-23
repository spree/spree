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
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { CountryCombobox } from '@/components/spree/country-combobox'
import { StateCombobox, useCountryStates } from '@/components/spree/country-state-fields'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible'
import { Field, FieldError, FieldGroup, FieldLabel } from '@/components/ui/field'
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
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
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
  const { t } = useTranslation()
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
              {t('admin.stock_locations.add_cta')}
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
  const { t } = useTranslation()
  const createMutation = useCreateStockLocation()

  const form = useForm<FormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(formSchema) as any,
    defaultValues: DEFAULT_VALUES,
  })

  async function onSubmit(values: FormValues) {
    try {
      const params = formValuesToParams(values) as StockLocationCreateParams
      await createMutation.mutateAsync(params)
      form.reset(DEFAULT_VALUES)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
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
          <SheetTitle>{t('admin.pages.settings.stock_locations.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.stock_locations.create_description')}</SheetDescription>
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
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting
                ? t('admin.actions.creating')
                : t('admin.actions.create')}
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
  const { t } = useTranslation()
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
    try {
      const params = formValuesToParams(values) as StockLocationUpdateParams
      await updateMutation.mutateAsync(params)
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  async function onDelete() {
    const ok = await confirm({
      title: t('admin.stock_locations.delete_confirm.title'),
      message: t('admin.stock_locations.delete_confirm.message', {
        name: stockLocation?.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {stockLocation?.name ?? t('admin.pages.settings.stock_locations.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.stock_locations.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
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
                  {t('admin.actions.delete')}
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
              >
                {form.formState.isSubmitting ? t('admin.actions.saving') : t('admin.actions.save')}
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
  const { t } = useTranslation()
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
          <h3 className="text-sm font-medium">{t('admin.stock_locations.stock_items.title')}</h3>
          <p className="text-xs text-muted-foreground">
            {t('admin.stock_locations.stock_items.help')}
          </p>
        </div>
        <Input
          placeholder={t('admin.stock_locations.stock_items.search_placeholder')}
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
  const { t } = useTranslation()
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
              <th className="px-4 py-2 text-left font-medium">
                {t('admin.stock_locations.stock_items.table.variant')}
              </th>
              <th className="px-3 py-2 text-right font-medium">
                {t('admin.stock_locations.stock_items.table.on_hand')}
              </th>
              <th className="px-3 py-2 text-left font-medium">
                {t('admin.stock_locations.stock_items.table.backorder')}
              </th>
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

function StockLocationFormFields({ form }: { form: UseFormReturn<FormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const countryIso = form.watch('country_iso')
  const { states } = useCountryStates(countryIso)
  const pickupEnabled = form.watch('pickup_enabled')

  return (
    <FieldGroup>
      {errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {errors.root.message}
        </p>
      )}

      <Field>
        <FieldLabel htmlFor="sl-name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="sl-name"
          autoFocus
          placeholder={t('admin.fields.stock_location.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="sl-admin-name">
          {t('admin.fields.stock_location.admin_name.label')}
        </FieldLabel>
        <Input
          id="sl-admin-name"
          placeholder={t('admin.fields.stock_location.admin_name.placeholder')}
          aria-invalid={!!errors.admin_name || undefined}
          {...form.register('admin_name')}
        />
        <FieldError errors={[errors.admin_name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="sl-kind">{t('admin.fields.stock_location.kind.label')}</FieldLabel>
        <Controller
          name="kind"
          control={form.control}
          render={({ field }) => (
            <Select
              items={KIND_OPTIONS as never}
              value={field.value}
              onValueChange={field.onChange}
            >
              <SelectTrigger id="sl-kind">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {KIND_OPTIONS.map((o) => (
                  <SelectItem key={o.value} value={o.value}>
                    {o.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      <BooleanRow
        id="sl-active"
        label={t('admin.fields.stock_location.active.label')}
        help={t('admin.fields.stock_location.active.help')}
        form={form}
        name="active"
      />
      <BooleanRow
        id="sl-default"
        label={t('admin.fields.stock_location.default.label')}
        help={t('admin.fields.stock_location.default.help')}
        form={form}
        name="default"
      />
      <BooleanRow
        id="sl-backorderable-default"
        label={t('admin.fields.stock_location.backorderable_default.label')}
        help={t('admin.fields.stock_location.backorderable_default.help')}
        form={form}
        name="backorderable_default"
      />
      <BooleanRow
        id="sl-propagate-all-variants"
        label={t('admin.fields.stock_location.propagate_all_variants.label')}
        help={t('admin.fields.stock_location.propagate_all_variants.help')}
        form={form}
        name="propagate_all_variants"
      />

      <div className="border-t border-border pt-4">
        <h3 className="mb-3 text-sm font-medium">
          {t('admin.pages.settings.stock_locations.section_address')}
        </h3>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="sl-address1">{t('admin.fields.address1.label')}</FieldLabel>
            <Input
              id="sl-address1"
              aria-invalid={!!errors.address1 || undefined}
              {...form.register('address1')}
            />
            <FieldError errors={[errors.address1]} />
          </Field>
          <Field>
            <FieldLabel htmlFor="sl-address2">{t('admin.fields.address2.label')}</FieldLabel>
            <Input
              id="sl-address2"
              aria-invalid={!!errors.address2 || undefined}
              {...form.register('address2')}
            />
            <FieldError errors={[errors.address2]} />
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field>
              <FieldLabel htmlFor="sl-city">{t('admin.fields.city.label')}</FieldLabel>
              <Input
                id="sl-city"
                aria-invalid={!!errors.city || undefined}
                {...form.register('city')}
              />
              <FieldError errors={[errors.city]} />
            </Field>
            <Field>
              <FieldLabel htmlFor="sl-zipcode">{t('admin.fields.zipcode.label')}</FieldLabel>
              <Input
                id="sl-zipcode"
                aria-invalid={!!errors.zipcode || undefined}
                {...form.register('zipcode')}
              />
              <FieldError errors={[errors.zipcode]} />
            </Field>
          </div>
          <Field>
            <FieldLabel>{t('admin.fields.country_iso.label')}</FieldLabel>
            <Controller
              name="country_iso"
              control={form.control}
              render={({ field }) => (
                <CountryCombobox
                  value={field.value}
                  onValueChange={(iso) => {
                    field.onChange(iso)
                    form.setValue('state_abbr', '', { shouldDirty: true })
                    form.setValue('state_name', '', { shouldDirty: true })
                  }}
                />
              )}
            />
          </Field>
          {states.length > 0 ? (
            <Field>
              <FieldLabel>{t('admin.fields.state_abbr.label')}</FieldLabel>
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
              <FieldLabel htmlFor="sl-state-name">{t('admin.fields.state_name.label')}</FieldLabel>
              <Input
                id="sl-state-name"
                aria-invalid={!!errors.state_name || undefined}
                {...form.register('state_name')}
              />
              <FieldError errors={[errors.state_name]} />
            </Field>
          )}
          <Field>
            <FieldLabel htmlFor="sl-phone">{t('admin.fields.phone.label')}</FieldLabel>
            <Input
              id="sl-phone"
              aria-invalid={!!errors.phone || undefined}
              {...form.register('phone')}
            />
            <FieldError errors={[errors.phone]} />
          </Field>
          <Field>
            <FieldLabel htmlFor="sl-company">{t('admin.fields.company.label')}</FieldLabel>
            <Input
              id="sl-company"
              aria-invalid={!!errors.company || undefined}
              {...form.register('company')}
            />
            <FieldError errors={[errors.company]} />
          </Field>
        </FieldGroup>
      </div>

      <div className="border-t border-border pt-4">
        <h3 className="mb-3 text-sm font-medium">{t('admin.stock_locations.section_pickup')}</h3>
        <FieldGroup>
          <BooleanRow
            id="sl-pickup-enabled"
            label={t('admin.fields.stock_location.pickup_enabled.label')}
            help={t('admin.fields.stock_location.pickup_enabled.help')}
            form={form}
            name="pickup_enabled"
          />
          {pickupEnabled && (
            <>
              <Field>
                <FieldLabel htmlFor="sl-pickup-stock-policy">
                  {t('admin.fields.stock_location.pickup_stock_policy.label')}
                </FieldLabel>
                <Controller
                  name="pickup_stock_policy"
                  control={form.control}
                  render={({ field }) => (
                    <Select
                      items={PICKUP_POLICY_OPTIONS as never}
                      value={field.value}
                      onValueChange={field.onChange}
                    >
                      <SelectTrigger id="sl-pickup-stock-policy">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {PICKUP_POLICY_OPTIONS.map((o) => (
                          <SelectItem key={o.value} value={o.value}>
                            {o.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </Field>
              <Field>
                <FieldLabel htmlFor="sl-pickup-ready-in-minutes">
                  {t('admin.fields.stock_location.pickup_ready_in_minutes.label')}
                </FieldLabel>
                <Input
                  id="sl-pickup-ready-in-minutes"
                  type="number"
                  min={0}
                  step={5}
                  placeholder={t('admin.fields.stock_location.pickup_ready_in_minutes.placeholder')}
                  aria-invalid={!!errors.pickup_ready_in_minutes || undefined}
                  {...form.register('pickup_ready_in_minutes', { valueAsNumber: true })}
                />
                <FieldError errors={[errors.pickup_ready_in_minutes]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="sl-pickup-instructions">
                  {t('admin.fields.stock_location.pickup_instructions.label')}
                </FieldLabel>
                <Textarea
                  id="sl-pickup-instructions"
                  rows={3}
                  placeholder={t('admin.fields.stock_location.pickup_instructions.placeholder')}
                  aria-invalid={!!errors.pickup_instructions || undefined}
                  {...form.register('pickup_instructions')}
                />
                <FieldError errors={[errors.pickup_instructions]} />
              </Field>
            </>
          )}
        </FieldGroup>
      </div>
    </FieldGroup>
  )
}

function BooleanRow({
  id,
  label,
  help,
  form,
  name,
}: {
  id: string
  label: string
  help?: string
  form: UseFormReturn<FormValues>
  name: keyof FormValues
}) {
  return (
    <Field>
      <div className="flex items-start justify-between gap-4">
        <div className="flex flex-col">
          <FieldLabel htmlFor={id} className="cursor-pointer">
            {label}
          </FieldLabel>
          {help && <span className="text-xs text-muted-foreground">{help}</span>}
        </div>
        <Controller
          name={name as never}
          control={form.control}
          render={({ field }) => (
            <Switch id={id} checked={!!field.value} onCheckedChange={field.onChange} />
          )}
        />
      </div>
    </Field>
  )
}
