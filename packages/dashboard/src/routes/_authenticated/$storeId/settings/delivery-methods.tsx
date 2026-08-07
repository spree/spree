import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryMethod, PreferenceField, Product } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  PreferencesForm,
  ResourceMultiAutocomplete,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
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
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, Trash2Icon } from 'lucide-react'
import { useEffect, useMemo } from 'react'
import { Controller, type UseFormReturn, useFieldArray, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateDeliveryMethod,
  useDeleteDeliveryMethod,
  useDeliveryCalculators,
  useDeliveryMethod,
  useDeliveryMethodRules,
  useDeliveryMethodRuleTypes,
  useDeliveryRateProviders,
  useFulfillmentProviders,
  useUpdateDeliveryMethod,
} from '../../../../hooks/use-delivery-methods'
import { useDeliveryZones } from '../../../../hooks/use-delivery-zones'
import { productAutocompleteProps } from '../../../../hooks/use-products'
import { useStockLocations } from '../../../../hooks/use-stock-locations'
import { useTaxCategories } from '../../../../hooks/use-tax-categories'
import {
  DELIVERY_METHOD_DEFAULTS,
  type DeliveryMethodFormValues,
  deliveryMethodFormSchema,
  deliveryMethodValuesToParams,
  FULFILLMENT_TYPES,
} from '../../../../schemas/delivery-method'
import '../../../../tables/delivery-methods'

/** One entry from the delivery-method-rule discovery endpoint. */
type DeliveryMethodRuleType = Awaited<
  ReturnType<typeof adminClient.deliveryMethods.ruleTypes>
>['data'][number]

/** Whether a rule kind is configured with a product list rather than preferences. */
function takesProducts(ruleTypes: DeliveryMethodRuleType[] | undefined, type: string) {
  return (
    ruleTypes?.find((candidate) => candidate.type === type)?.association_fields ?? []
  ).includes('product_ids')
}

const deliveryMethodsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/delivery-methods')({
  validateSearch: deliveryMethodsSearchSchema,
  component: DeliveryMethodsPage,
})

function DeliveryMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof deliveryMethodsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryMethod()
  const { permissions } = usePermissions()

  const editId = search.edit
  const isCreating = !!search.new

  const closeSheet = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { edit: _e, new: _n, ...rest } = prev
        return rest as never
      },
    })

  const openCreate = () =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, new: true }) as never })

  const openEdit = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, edit: id }) as never })

  useRowClickBridge('data-delivery-method-id', openEdit)

  async function handleDelete(deliveryMethod: DeliveryMethod) {
    const ok = await confirm({
      title: t('admin.delivery_methods.delete_confirm.title'),
      message: t('admin.delivery_methods.delete_confirm.message', {
        name: deliveryMethod.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(deliveryMethod.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<DeliveryMethod>
        tableKey="delivery-methods"
        queryKey="delivery-methods"
        queryFn={(params) => adminClient.deliveryMethods.list(params)}
        searchParams={search}
        rowActions={(deliveryMethod) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(deliveryMethod.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.DeliveryMethod),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(deliveryMethod),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.DeliveryMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.delivery_methods.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateDeliveryMethodSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditDeliveryMethodSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateDeliveryMethodSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateDeliveryMethod()
  const form = useForm<DeliveryMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryMethodFormSchema) as any,
    defaultValues: DELIVERY_METHOD_DEFAULTS,
  })

  async function onSubmit(values: DeliveryMethodFormValues) {
    try {
      await createMutation.mutateAsync(deliveryMethodValuesToParams(values))
      form.reset(DELIVERY_METHOD_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DELIVERY_METHOD_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.delivery_methods.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.delivery_methods.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
            <div className="flex flex-col gap-4 p-4">
              <DeliveryMethodFormFields form={form} />
            </div>
            <ConditionsSection form={form} />
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
                : t('admin.delivery_methods.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditDeliveryMethodSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: deliveryMethod, isLoading: methodLoading } = useDeliveryMethod(id)
  const { data: rules, isLoading: rulesLoading } = useDeliveryMethodRules(id)
  const { data: ruleTypes, isLoading: ruleTypesLoading } = useDeliveryMethodRuleTypes()
  const updateMutation = useUpdateDeliveryMethod(id)
  // Saving sends the full rule set for reconciliation, so the form must not be
  // reachable until the existing rules have loaded — otherwise a quick save
  // would submit an empty set and delete them all. Rule types are needed too,
  // since they decide which rules carry a product list.
  const isLoading = methodLoading || rulesLoading || ruleTypesLoading

  const form = useForm<DeliveryMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryMethodFormSchema) as any,
    defaultValues: DELIVERY_METHOD_DEFAULTS,
  })

  useEffect(() => {
    // Wait for rules too — seeding the form before they arrive would reset
    // again once they land, discarding anything already edited.
    if (deliveryMethod && rules && ruleTypes) {
      form.reset({
        name: deliveryMethod.name,
        admin_name: deliveryMethod.admin_name ?? '',
        code: deliveryMethod.code ?? '',
        fulfillment_type:
          (deliveryMethod.fulfillment_type as DeliveryMethodFormValues['fulfillment_type']) ??
          'shipping',
        fulfillment_provider:
          deliveryMethod.fulfillment_provider ?? DELIVERY_METHOD_DEFAULTS.fulfillment_provider,
        rate_provider: deliveryMethod.rate_provider ?? DELIVERY_METHOD_DEFAULTS.rate_provider,
        storefront_visible: deliveryMethod.storefront_visible,
        tracking_url: deliveryMethod.tracking_url ?? '',
        estimated_transit_business_days_min:
          deliveryMethod.estimated_transit_business_days_min?.toString() ?? '',
        estimated_transit_business_days_max:
          deliveryMethod.estimated_transit_business_days_max?.toString() ?? '',
        tax_category_id: deliveryMethod.tax_category_id ?? '',
        calculator_type: deliveryMethod.calculator_type ?? '',
        calculator_preferences:
          (deliveryMethod.calculator_preferences as Record<string, unknown>) ?? {},
        delivery_zone_ids: deliveryMethod.delivery_zone_ids ?? [],
        stock_location_ids: deliveryMethod.stock_location_ids ?? [],
        rules: (rules?.data ?? []).map((rule) => ({
          id: rule.id,
          type: rule.type,
          preferences: rule.preferences as Record<string, unknown>,
          product_ids: rule.product_ids,
          takes_products: takesProducts(ruleTypes?.data, rule.type),
        })),
      })
    }
  }, [deliveryMethod, rules, ruleTypes, form])

  async function onSubmit(values: DeliveryMethodFormValues) {
    try {
      await updateMutation.mutateAsync(deliveryMethodValuesToParams(values))
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
            {deliveryMethod?.name ?? t('admin.delivery_methods.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.delivery_methods.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex min-h-0 flex-1 flex-col overflow-y-auto">
              <div className="flex flex-col gap-4 p-4">
                <DeliveryMethodFormFields form={form} />
              </div>
              <ConditionsSection form={form} />
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

// ---------------------------------------------------------------------------
// Conditions (eligibility rules) — held in form state, saved with the sheet
// ---------------------------------------------------------------------------

function ConditionsSection({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { data: ruleTypes } = useDeliveryMethodRuleTypes()
  const rulesArray = useFieldArray({ control: form.control, name: 'rules', keyName: '_key' })

  const existingTypes = new Set(rulesArray.fields.map((rule) => rule.type))
  const availableTypes = (ruleTypes?.data ?? []).filter((type) => !existingTypes.has(type.type))

  return (
    <div className="flex flex-col gap-3 border-t p-4">
      <div className="flex items-center justify-between">
        <span className="font-medium text-sm">{t('admin.delivery_methods.conditions.title')}</span>
        {availableTypes.length > 0 && (
          <DropdownMenu>
            <DropdownMenuTrigger
              render={
                <Button type="button" variant="outline" size="sm">
                  <PlusIcon className="size-4" />
                  {t('admin.delivery_methods.conditions.add')}
                </Button>
              }
            />
            <DropdownMenuContent align="end">
              {availableTypes.map((type) => (
                <DropdownMenuItem
                  key={type.type}
                  onClick={() =>
                    rulesArray.append({
                      type: type.type,
                      preferences: {},
                      product_ids: [],
                      takes_products: type.association_fields.includes('product_ids'),
                    })
                  }
                >
                  {type.name}
                </DropdownMenuItem>
              ))}
            </DropdownMenuContent>
          </DropdownMenu>
        )}
      </div>

      {rulesArray.fields.length === 0 && (
        <p className="text-muted-foreground text-sm">
          {t('admin.delivery_methods.conditions.empty')}
        </p>
      )}

      {rulesArray.fields.map((field, index) => (
        <ConditionRuleRow
          key={field._key}
          form={form}
          index={index}
          ruleType={(ruleTypes?.data ?? []).find((candidate) => candidate.type === field.type)}
          fallbackLabel={field.type}
          onRemove={() => rulesArray.remove(index)}
        />
      ))}
    </div>
  )
}

function ConditionRuleRow({
  form,
  index,
  ruleType,
  fallbackLabel,
  onRemove,
}: {
  form: UseFormReturn<DeliveryMethodFormValues>
  index: number
  ruleType?: DeliveryMethodRuleType
  fallbackLabel: string
  onRemove: () => void
}) {
  const { t } = useTranslation()
  // Rules that take a product list get a picker; every other kind renders its
  // preference schema. Driven by the discovery endpoint, so a plugin rule with
  // the same shape works without a change here.
  const productBacked = ruleType?.association_fields?.includes('product_ids') ?? false
  const label = ruleType?.name ?? fallbackLabel
  const schema = ruleType?.preference_schema ?? []

  return (
    <div className="flex flex-col gap-2 rounded-md border p-3">
      <div className="flex items-center justify-between">
        <span className="text-sm">{label}</span>
        <Button
          type="button"
          variant="ghost"
          size="icon-sm"
          onClick={onRemove}
          aria-label={t('admin.actions.delete')}
        >
          <Trash2Icon className="size-4" />
        </Button>
      </div>
      {productBacked ? (
        <Controller
          control={form.control}
          name={`rules.${index}.product_ids`}
          render={({ field }) => (
            <ResourceMultiAutocomplete<Product>
              {...productAutocompleteProps('delivery-method-rule-products')}
              value={field.value}
              onChange={field.onChange}
            />
          )}
        />
      ) : (
        <Controller
          control={form.control}
          name={`rules.${index}.preferences`}
          render={({ field }) => (
            <PreferencesForm schema={schema} values={field.value} onChange={field.onChange} />
          )}
        />
      )}
    </div>
  )
}

function ProviderSelectField({
  form,
  name,
  label,
  help,
  options,
}: {
  form: UseFormReturn<DeliveryMethodFormValues>
  name: 'fulfillment_provider' | 'rate_provider'
  label: string
  help: string
  options: { value: string; label: string }[]
}) {
  return (
    <Field>
      <FieldLabel>{label}</FieldLabel>
      <Controller
        name={name}
        control={form.control}
        render={({ field }) => (
          <Select items={options} value={field.value || ''} onValueChange={field.onChange}>
            <SelectTrigger>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {options.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      />
      <span className="text-muted-foreground text-xs">{help}</span>
    </Field>
  )
}

function DeliveryMethodFormFields({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data: calculators } = useDeliveryCalculators()
  const { data: fulfillmentProviders } = useFulfillmentProviders()
  const { data: rateProviders } = useDeliveryRateProviders()
  const { data: zones } = useDeliveryZones()
  const { data: stockLocations } = useStockLocations()
  const { data: taxCategories } = useTaxCategories()

  const fulfillmentType = form.watch('fulfillment_type')
  const calculatorType = form.watch('calculator_type')

  // Registry-driven: extension-registered types appear without a dashboard
  // change; the shipped const only covers the pre-fetch render.
  const registeredFulfillmentTypes = fulfillmentProviders?.fulfillment_types ?? FULFILLMENT_TYPES
  const fulfillmentTypeOptions = registeredFulfillmentTypes.map((value) => ({
    value,
    label: t(`admin.delivery_methods.fulfillment_types.${value}`, { defaultValue: value }),
  }))

  const calculatorOptions = (calculators?.data ?? []).map((calculator) => ({
    value: calculator.type,
    label: calculator.name,
  }))

  // Providers with no declared types (Manual) handle anything.
  const providersForType = useMemo(
    () =>
      (fulfillmentProviders?.data ?? []).filter(
        (provider) =>
          provider.fulfillment_types.length === 0 ||
          provider.fulfillment_types.includes(fulfillmentType),
      ),
    [fulfillmentProviders, fulfillmentType],
  )
  const providerOptions = providersForType.map((provider) => ({
    value: provider.type,
    label: provider.name,
  }))

  const defaultRateProvider = rateProviders?.default ?? ''

  // The select displayed the server default while submitting a blank value —
  // harmless (blank resolves to Internal) but the shown and saved values
  // disagreed. Seed it once the default is known, leaving a touched field or
  // a loaded record alone.
  const rateProvider = form.watch('rate_provider')
  const rateProviderDirty = !!form.formState.dirtyFields.rate_provider
  useEffect(() => {
    if (!defaultRateProvider || rateProvider || rateProviderDirty) return

    form.setValue('rate_provider', defaultRateProvider)
  }, [defaultRateProvider, rateProvider, rateProviderDirty, form])
  const rateProviderOptions = (rateProviders?.data ?? []).map((provider) => ({
    value: provider.type,
    label: provider.name,
  }))

  // Suggest a provider whenever the admin picks a fulfillment type: prefer one
  // that declares that type (Pickup for pickup), since the generic Manual
  // fallback would otherwise keep dispatch and address rules wrong. Only the
  // untouched field is steered — an explicit choice is never overwritten.
  const fulfillmentProvider = form.watch('fulfillment_provider')
  const providerDirty = !!form.formState.dirtyFields.fulfillment_provider
  useEffect(() => {
    if (providersForType.length === 0) return

    const stillValid = providersForType.some((provider) => provider.type === fulfillmentProvider)
    if (stillValid && providerDirty) return

    const specific = providersForType.find((provider) => provider.fulfillment_types.length > 0)
    const suggested = specific ?? providersForType[0]
    if (suggested.type === fulfillmentProvider) return

    form.setValue('fulfillment_provider', suggested.type)
  }, [providersForType, fulfillmentProvider, providerDirty, form])

  const selectedCalculator = (calculators?.data ?? []).find((c) => c.type === calculatorType)
  const preferenceSchema = (selectedCalculator?.preference_schema ?? []) as PreferenceField[]

  const taxCategoryOptions = [
    { value: '', label: t('admin.common.none') },
    ...(taxCategories?.data ?? []).map((tc) => ({ value: tc.id, label: tc.name })),
  ]

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
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <div className="grid grid-cols-2 gap-3">
        <Field>
          <FieldLabel htmlFor="admin_name">
            {t('admin.fields.delivery_method.admin_name.label')}
          </FieldLabel>
          <Input id="admin_name" {...form.register('admin_name')} />
        </Field>
        <Field>
          <FieldLabel htmlFor="code">{t('admin.fields.delivery_method.code.label')}</FieldLabel>
          <Input id="code" {...form.register('code')} />
        </Field>
      </div>

      <Field>
        <FieldLabel>{t('admin.fields.delivery_method.fulfillment_type.label')}</FieldLabel>
        <Controller
          name="fulfillment_type"
          control={form.control}
          render={({ field }) => (
            <Select
              items={fulfillmentTypeOptions}
              value={field.value}
              onValueChange={field.onChange}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {fulfillmentTypeOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      {/* Both provider fields render only when there is a real choice: with a
          single registered provider the default applies and the field stays
          hidden (for rate providers, until a carrier integration is
          installed pricing is simply the calculator below). */}
      {providerOptions.length > 1 && (
        <ProviderSelectField
          form={form}
          name="fulfillment_provider"
          label={t('admin.fields.delivery_method.fulfillment_provider.label')}
          help={t('admin.fields.delivery_method.fulfillment_provider.help')}
          options={providerOptions}
        />
      )}

      {rateProviderOptions.length > 1 && (
        <ProviderSelectField
          form={form}
          name="rate_provider"
          label={t('admin.fields.delivery_method.rate_provider.label')}
          help={t('admin.fields.delivery_method.rate_provider.help')}
          options={rateProviderOptions}
        />
      )}

      {fulfillmentType === 'pickup' && (
        <Field>
          <FieldLabel>{t('admin.fields.delivery_method.pickup_locations.label')}</FieldLabel>
          <Controller
            name="stock_location_ids"
            control={form.control}
            render={({ field }) => (
              <div className="flex flex-col gap-2">
                <span className="text-muted-foreground text-xs">
                  {t('admin.delivery_methods.pickup_locations_hint')}
                </span>
                {(stockLocations?.data ?? []).map((location) => {
                  const checked = field.value.includes(location.id)
                  return (
                    <label
                      key={location.id}
                      htmlFor={`pickup-location-${location.id}`}
                      className="flex items-center gap-2 text-sm"
                    >
                      <Checkbox
                        id={`pickup-location-${location.id}`}
                        checked={checked}
                        onCheckedChange={(next) => {
                          field.onChange(
                            next
                              ? [...field.value, location.id]
                              : field.value.filter(
                                  (locationId: string) => locationId !== location.id,
                                ),
                          )
                        }}
                      />
                      {location.name}
                    </label>
                  )
                })}
              </div>
            )}
          />
        </Field>
      )}

      {fulfillmentType === 'shipping' && (
        <>
          <Field>
            <FieldLabel>{t('admin.fields.delivery_method.calculator.label')}</FieldLabel>
            <Controller
              name="calculator_type"
              control={form.control}
              render={({ field }) => (
                <Select
                  items={calculatorOptions}
                  value={field.value ?? ''}
                  onValueChange={field.onChange}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {calculatorOptions.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </Field>

          <Controller
            name="calculator_preferences"
            control={form.control}
            render={({ field }) => (
              <PreferencesForm
                schema={preferenceSchema}
                values={(field.value ?? {}) as Record<string, unknown>}
                onChange={field.onChange}
              />
            )}
          />

          <Field>
            <FieldLabel>{t('admin.fields.delivery_method.delivery_zones.label')}</FieldLabel>
            <Controller
              name="delivery_zone_ids"
              control={form.control}
              render={({ field }) => (
                <div className="flex flex-col gap-2">
                  {(zones?.data ?? []).length === 0 && (
                    <span className="text-xs text-muted-foreground">
                      {t('admin.delivery_methods.no_zones_hint')}
                    </span>
                  )}
                  {(zones?.data ?? []).map((zone) => {
                    const checked = field.value.includes(zone.id)
                    return (
                      <label
                        key={zone.id}
                        htmlFor={`delivery-zone-${zone.id}`}
                        className="flex items-center gap-2 text-sm"
                      >
                        <Checkbox
                          id={`delivery-zone-${zone.id}`}
                          checked={checked}
                          onCheckedChange={(next) => {
                            field.onChange(
                              next
                                ? [...field.value, zone.id]
                                : field.value.filter((zoneId: string) => zoneId !== zone.id),
                            )
                          }}
                        />
                        {zone.name}
                      </label>
                    )
                  })}
                </div>
              )}
            />
          </Field>
        </>
      )}

      <div className="grid grid-cols-2 gap-3">
        <Field>
          <FieldLabel htmlFor="estimated_transit_business_days_min">
            {t('admin.fields.delivery_method.transit_days_min.label')}
          </FieldLabel>
          <Input
            id="estimated_transit_business_days_min"
            type="number"
            min="1"
            {...form.register('estimated_transit_business_days_min')}
          />
        </Field>
        <Field>
          <FieldLabel htmlFor="estimated_transit_business_days_max">
            {t('admin.fields.delivery_method.transit_days_max.label')}
          </FieldLabel>
          <Input
            id="estimated_transit_business_days_max"
            type="number"
            min="1"
            {...form.register('estimated_transit_business_days_max')}
          />
        </Field>
      </div>

      <Field>
        <FieldLabel>{t('admin.fields.delivery_method.tax_category.label')}</FieldLabel>
        <Controller
          name="tax_category_id"
          control={form.control}
          render={({ field }) => (
            <Select
              items={taxCategoryOptions}
              value={field.value ?? ''}
              onValueChange={field.onChange}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {taxCategoryOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      <Field>
        <FieldLabel htmlFor="tracking_url">
          {t('admin.fields.delivery_method.tracking_url.label')}
        </FieldLabel>
        <Input
          id="tracking_url"
          placeholder="https://carrier.example/track?num=:tracking"
          {...form.register('tracking_url')}
        />
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="storefront_visible" className="cursor-pointer">
              {t('admin.fields.storefront_visible.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.delivery_method.storefront_visible.help')}
            </span>
          </div>
          <Controller
            name="storefront_visible"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="storefront_visible"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
      </Field>
    </FieldGroup>
  )
}
