import { zodResolver } from '@hookform/resolvers/zod'
import type {
  StockItem,
  StockLocation,
  StockLocationCreateParams,
  StockLocationUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  CountryCombobox,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  StateCombobox,
  Subject,
  useCountryStates,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
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
  Switch,
  Textarea,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import { ChevronDownIcon, ChevronRightIcon, PlusIcon } from 'lucide-react'
import { useEffect, useMemo, useState } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { useStockItems, useUpdateStockItem } from '../../../../hooks/use-stock-items'
import {
  useCreateStockLocation,
  useDeleteStockLocation,
  useStockLocation,
  useUpdateStockLocation,
} from '../../../../hooks/use-stock-locations'
import {
  formValuesToParams,
  PICKUP_STOCK_POLICIES,
  STOCK_LOCATION_DEFAULTS,
  STOCK_LOCATION_KINDS,
  type StockLocationFormValues,
  stockLocationFormSchema,
  stockLocationToFormValues,
} from '../../../../schemas/stock-location'
import '../../../../tables/stock-locations'

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

function StockLocationsPage() {
  const { t } = useTranslation()
  // Cast: Route.useSearch's inferred type unions with the parent layout's
  // search shape, which doesn't know about our `edit`/`new` keys. The runtime
  // schema (`stockSearchSchema`) is still the source of truth — this just
  // gets us past the parent-union narrowing.
  const search = Route.useSearch() as z.infer<typeof stockSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteStockLocation()
  const { permissions } = usePermissions()

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

  async function handleDelete(location: StockLocation) {
    const ok = await confirm({
      title: t('admin.stock_locations.delete_confirm.title'),
      message: t('admin.stock_locations.delete_confirm.message', { name: location.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(location.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<StockLocation>
        tableKey="stock-locations"
        queryKey="stock-locations"
        queryFn={(params) => adminClient.stockLocations.list(params)}
        searchParams={search}
        rowActions={(location) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(location.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.StockLocation),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(location),
              },
            ]}
          />
        )}
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

  const form = useForm<StockLocationFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(stockLocationFormSchema) as any,
    defaultValues: STOCK_LOCATION_DEFAULTS,
  })

  async function onSubmit(values: StockLocationFormValues) {
    try {
      const params = formValuesToParams(values) as StockLocationCreateParams
      await createMutation.mutateAsync(params)
      form.reset(STOCK_LOCATION_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(STOCK_LOCATION_DEFAULTS)
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
                : t('admin.stock_locations.create_label')}
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

  const form = useForm<StockLocationFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(stockLocationFormSchema) as any,
    defaultValues: STOCK_LOCATION_DEFAULTS,
  })

  // Reset form when the loaded resource arrives — keeps the inputs in sync
  // with whatever the server last persisted (including external edits).
  useEffect(() => {
    if (stockLocation) {
      form.reset(stockLocationToFormValues(stockLocation))
    }
  }, [stockLocation, form])

  async function onSubmit(values: StockLocationFormValues) {
    try {
      const params = formValuesToParams(values) as StockLocationUpdateParams
      await updateMutation.mutateAsync(params)
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
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
  const groups = useMemo(
    () => groupItemsByProduct(items, t('admin.stock_locations.stock_items.unknown_product')),
    [items, t],
  )

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
        <div className="px-4 py-6 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
      ) : items.length === 0 ? (
        <div className="px-4 py-6 text-sm text-muted-foreground">
          {search
            ? t('admin.stock_locations.stock_items.empty_search')
            : t('admin.stock_locations.stock_items.empty')}
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
            {t('admin.common.page_of', { page, total: totalPages })}
          </span>
          <div className="flex gap-1">
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.max(1, p - 1))}
              disabled={page === 1 || isFetching}
            >
              {t('admin.common.prev')}
            </Button>
            <Button
              type="button"
              size="sm"
              variant="outline"
              onClick={() => setPage((p) => Math.min(totalPages, p + 1))}
              disabled={page === totalPages || isFetching}
            >
              {t('admin.common.next')}
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

function groupItemsByProduct(items: StockItem[], unknownProductLabel: string): StockItemGroup[] {
  const map = new Map<string, StockItemGroup>()
  for (const item of items) {
    const productId = item.variant?.product_id ?? '__unknown__'
    const productName = item.variant?.product_name ?? unknownProductLabel
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
            {t('admin.stock_locations.stock_items.variant_count', { count: group.items.length })}
            {group.hasLowStock && ` · ${t('admin.stock_locations.stock_items.low_stock_marker')}`}
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
  const { t } = useTranslation()
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
  const variantLabel = optionsText || sku || t('admin.common.default')
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
          {updateMutation.isPending ? '…' : t('admin.actions.save')}
        </Button>
      </td>
    </tr>
  )
}

// ============================================================================
// Shared form fields
// ============================================================================

function StockLocationFormFields({ form }: { form: UseFormReturn<StockLocationFormValues> }) {
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
        <FieldLabel htmlFor="name">{t('admin.fields.name.label')}</FieldLabel>
        <Input
          id="name"
          autoFocus
          placeholder={t('admin.fields.stock_location.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="admin-name">
          {t('admin.fields.stock_location.admin_name.label')}
        </FieldLabel>
        <Input
          id="admin-name"
          placeholder={t('admin.fields.stock_location.admin_name.placeholder')}
          aria-invalid={!!errors.admin_name || undefined}
          {...form.register('admin_name')}
        />
        <FieldError errors={[errors.admin_name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="kind">{t('admin.fields.stock_location.kind.label')}</FieldLabel>
        <Controller
          name="kind"
          control={form.control}
          render={({ field }) => {
            const items = STOCK_LOCATION_KINDS.map((value) => ({
              value,
              label: t(`admin.stock_locations.kinds.${value}`),
            }))
            return (
              <Select items={items as never} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id="kind">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {items.map((o) => (
                    <SelectItem key={o.value} value={o.value}>
                      {o.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )
          }}
        />
        <FieldError errors={[errors.kind]} />
      </Field>

      <BooleanRow
        id="active"
        label={t('admin.fields.stock_location.active.label')}
        help={t('admin.fields.stock_location.active.help')}
        form={form}
        name="active"
      />
      <BooleanRow
        id="default"
        label={t('admin.fields.stock_location.default.label')}
        help={t('admin.fields.stock_location.default.help')}
        form={form}
        name="default"
      />
      <BooleanRow
        id="backorderable-default"
        label={t('admin.fields.stock_location.backorderable_default.label')}
        help={t('admin.fields.stock_location.backorderable_default.help')}
        form={form}
        name="backorderable_default"
      />
      <BooleanRow
        id="propagate-all-variants"
        label={t('admin.fields.stock_location.propagate_all_variants.label')}
        help={t('admin.fields.stock_location.propagate_all_variants.help')}
        form={form}
        name="propagate_all_variants"
      />

      <div className="border-t border-border pt-4">
        <h3 className="mb-3 text-sm font-medium">{t('admin.fields.address.address1.label')}</h3>
        <FieldGroup>
          <Field>
            <FieldLabel htmlFor="address1">{t('admin.fields.address1.label')}</FieldLabel>
            <Input
              id="address1"
              aria-invalid={!!errors.address1 || undefined}
              {...form.register('address1')}
            />
            <FieldError errors={[errors.address1]} />
          </Field>
          <Field>
            <FieldLabel htmlFor="address2">{t('admin.fields.address2.label')}</FieldLabel>
            <Input
              id="address2"
              aria-invalid={!!errors.address2 || undefined}
              {...form.register('address2')}
            />
            <FieldError errors={[errors.address2]} />
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field>
              <FieldLabel htmlFor="city">{t('admin.fields.city.label')}</FieldLabel>
              <Input
                id="city"
                aria-invalid={!!errors.city || undefined}
                {...form.register('city')}
              />
              <FieldError errors={[errors.city]} />
            </Field>
            <Field>
              <FieldLabel htmlFor="zipcode">{t('admin.fields.zipcode.label')}</FieldLabel>
              <Input
                id="zipcode"
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
            <FieldError errors={[errors.country_iso]} />
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
              <FieldError errors={[errors.state_abbr]} />
            </Field>
          ) : (
            <Field>
              <FieldLabel htmlFor="state-name">{t('admin.fields.state_name.label')}</FieldLabel>
              <Input
                id="state-name"
                aria-invalid={!!errors.state_name || undefined}
                {...form.register('state_name')}
              />
              <FieldError errors={[errors.state_name]} />
            </Field>
          )}
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
            <FieldLabel htmlFor="company">{t('admin.fields.company.label')}</FieldLabel>
            <Input
              id="company"
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
            id="pickup-enabled"
            label={t('admin.fields.stock_location.pickup_enabled.label')}
            help={t('admin.fields.stock_location.pickup_enabled.help')}
            form={form}
            name="pickup_enabled"
          />
          {pickupEnabled && (
            <>
              <Field>
                <FieldLabel htmlFor="pickup-stock-policy">
                  {t('admin.fields.stock_location.pickup_stock_policy.label')}
                </FieldLabel>
                <Controller
                  name="pickup_stock_policy"
                  control={form.control}
                  render={({ field }) => {
                    const items = PICKUP_STOCK_POLICIES.map((value) => ({
                      value,
                      label: t(`admin.stock_locations.pickup_stock_policies.${value}`),
                    }))
                    return (
                      <Select
                        items={items as never}
                        value={field.value}
                        onValueChange={field.onChange}
                      >
                        <SelectTrigger id="pickup-stock-policy">
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {items.map((o) => (
                            <SelectItem key={o.value} value={o.value}>
                              {o.label}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )
                  }}
                />
                <FieldError errors={[errors.pickup_stock_policy]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="pickup-ready-in-minutes">
                  {t('admin.fields.stock_location.pickup_ready_in_minutes.label')}
                </FieldLabel>
                <Input
                  id="pickup-ready-in-minutes"
                  type="number"
                  min={0}
                  step={5}
                  placeholder={t('admin.fields.stock_location.pickup_ready_in_minutes.placeholder')}
                  aria-invalid={!!errors.pickup_ready_in_minutes || undefined}
                  {...form.register('pickup_ready_in_minutes')}
                />
                <FieldError errors={[errors.pickup_ready_in_minutes]} />
              </Field>
              <Field>
                <FieldLabel htmlFor="pickup-instructions">
                  {t('admin.fields.stock_location.pickup_instructions.label')}
                </FieldLabel>
                <Textarea
                  id="pickup-instructions"
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
  form: UseFormReturn<StockLocationFormValues>
  name: keyof StockLocationFormValues
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
