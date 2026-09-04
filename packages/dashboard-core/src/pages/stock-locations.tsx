import { zodResolver } from '@hookform/resolvers/zod'
import {
  Button,
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
import { PlusIcon } from '@spree/dashboard-ui/icons'
import { useNavigate } from '@tanstack/react-router'
import { type ComponentType, useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import type { PanelStockLocation } from '../api-client'
import { Can } from '../components/can'
import { CountryCombobox } from '../components/country-combobox'
import { StateCombobox, useCountryStates } from '../components/country-state-fields'
import { ResourceTable, resourceSearchSchema } from '../components/resource-table'
import {
  canDeleteStockLocations,
  listStockLocations,
  useCreateStockLocation,
  useDeleteStockLocation,
  useStockLocation,
  useUpdateStockLocation,
} from '../hooks/use-stock-locations'
import { mapSpreeErrorsToForm } from '../lib/form-errors'
import { Subject } from '../lib/permissions'
import { usePermissions } from '../providers/permission-provider'
import {
  formValuesToParams,
  PICKUP_STOCK_POLICIES,
  STOCK_LOCATION_DEFAULTS,
  STOCK_LOCATION_KINDS,
  type StockLocationFormValues,
  stockLocationFormSchema,
  stockLocationToFormValues,
} from '../schemas/stock-location'
import '../tables/stock-locations'

/**
 * Adds `?edit=<id>` and `?new=1` on top of the standard table search schema,
 * so the create and edit sheets can be deep-linked.
 *
 * Exported because each app owns its own route file — the route path differs
 * per panel (`/$storeId/settings/...` against `/$sellerId/settings/...`) and
 * TanStack's file routes are generated per app — while everything the page
 * *does* lives here.
 */
export const stockLocationsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export type StockLocationsSearch = z.infer<typeof stockLocationsSearchSchema>

/**
 * Manage the stock locations this panel can see.
 *
 * Shared by the operator's dashboard and the marketplace seller panel. Neither
 * owns the records differently — the scoping is server-side, so the operator's
 * API answers with every location in the store and a seller's with only their
 * own, and this page renders whatever it is given.
 *
 * Two things a panel supplies rather than this page assuming them: the API
 * resource, registered through `setApiClient`, and `stockLevelsPanel` — the
 * on-hand editor, which reads the Admin API and links to the operator's
 * product pages, so a seller's panel simply passes nothing and gets a page
 * without it.
 */
export function StockLocationsPage({
  search,
  stockLevelsPanel: StockLevelsPanel,
}: {
  search: StockLocationsSearch
  /** Rendered inside the edit sheet, below the form. Optional — see above. */
  stockLevelsPanel?: ComponentType<{ stockLocationId: string }>
}) {
  const { t } = useTranslation()
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

  async function handleDelete(location: PanelStockLocation) {
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
      <ResourceTable<PanelStockLocation>
        tableKey="stock-locations"
        queryKey="stock-locations"
        queryFn={(params) => listStockLocations(params)}
        searchParams={search}
        rowActions={(location) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(location.id) },
              {
                key: 'delete',
                destructive: true,
                // Both must hold: the role allows it, and this panel's API
                // offers it at all — a seller's does not.
                visible:
                  canDeleteStockLocations() && permissions.can('destroy', Subject.StockLocation),
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
        <EditStockLocationSheet
          id={editId}
          open
          onOpenChange={(o) => !o && closeSheet()}
          stockLevelsPanel={StockLevelsPanel}
        />
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
      const params = formValuesToParams(values)
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
              onClick={() => onOpenChange(false)}
              disabled={form.formState.isSubmitting}
            >
              {t('admin.actions.cancel')}
            </Button>
            <Button type="submit" disabled={form.formState.isSubmitting}>
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
  stockLevelsPanel: StockLevelsPanel,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
  stockLevelsPanel?: ComponentType<{ stockLocationId: string }>
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
      const params = formValuesToParams(values)
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
              {StockLevelsPanel && <StockLevelsPanel stockLocationId={id} />}
            </div>
            <SheetFooter>
              <Button
                type="button"
                variant="outline"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
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
// Shared form fields
// ============================================================================

function StockLocationFormFields({ form }: { form: UseFormReturn<StockLocationFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const countryCode = form.watch('country_code')
  const { states } = useCountryStates(countryCode)
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
            <FieldLabel>{t('admin.fields.country_code.label')}</FieldLabel>
            <Controller
              name="country_code"
              control={form.control}
              render={({ field }) => (
                <CountryCombobox
                  value={field.value}
                  onValueChange={(iso) => {
                    field.onChange(iso)
                    form.setValue('state_code', '', { shouldDirty: true })
                    form.setValue('state_name', '', { shouldDirty: true })
                  }}
                />
              )}
            />
            <FieldError errors={[errors.country_code]} />
          </Field>
          {states.length > 0 ? (
            <Field>
              <FieldLabel>{t('admin.fields.state_code.label')}</FieldLabel>
              <Controller
                name="state_code"
                control={form.control}
                render={({ field }) => (
                  <StateCombobox
                    countryCode={countryCode}
                    states={states}
                    value={field.value}
                    onValueChange={field.onChange}
                  />
                )}
              />
              <FieldError errors={[errors.state_code]} />
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
        <h3 className="mb-3 text-sm font-medium">{t('admin.stock_locations.section_returns')}</h3>
        <FieldGroup>
          <BooleanRow
            id="returns-enabled"
            label={t('admin.fields.stock_location.returns_enabled.label')}
            help={t('admin.fields.stock_location.returns_enabled.help')}
            form={form}
            name="returns_enabled"
          />
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
