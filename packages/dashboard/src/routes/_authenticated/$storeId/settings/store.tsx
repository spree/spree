import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store, type StoreDataSourceProvider } from '@spree/admin-sdk'
import {
  extensionFormValues,
  extensionSubmitValues,
  mapSpreeErrorsToForm,
  PageHeader,
  reconcileStoreDefaultLocale,
  Slot,
  useAuth,
  useStore,
  useSwitchAdminLocale,
} from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
  FieldDescription,
  FieldError,
  FieldGroup,
  FieldLabel,
  FormActions,
  Input,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Switch,
  toastManager,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { ExternalLinkIcon } from 'lucide-react'
import { type ReactNode, useCallback, useEffect, useMemo } from 'react'
import {
  type Control,
  Controller,
  type FieldPath,
  type FieldValues,
  FormProvider,
  useForm,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { ChoiceCardPicker } from '../../../../components/spree/choice-card-picker'
import {
  useStoreDataSources,
  useStoreSettings,
  useUpdateStoreSettings,
} from '../../../../hooks/use-store-settings'
import { getAvailableUiLocales } from '../../../../i18n-setup'
import {
  CAPTURE_METHODS,
  DOCUMENT_NUMBER_FORMATS,
  INTERNAL_PROVIDER_KEY,
  PROVIDER_FAILURE_POLICIES,
  STOREFRONT_ACCESS_LEVELS,
  type StoreSettingsFormValues,
  storeSettingsFormSchema,
  UNIT_SYSTEMS,
  WEIGHT_UNITS,
} from '../../../../schemas/store'

export const Route = createFileRoute('/_authenticated/$storeId/settings/store')({
  component: StoreSettingsPage,
})

const PRICING_PROVIDER_DOCS_URL =
  'https://spreecommerce.org/docs/v6/developer/how-to/custom-pricing-provider'
const INVENTORY_PROVIDER_DOCS_URL =
  'https://spreecommerce.org/docs/v6/developer/how-to/custom-inventory-provider'

function DocsLink({ href, children }: { href: string; children: ReactNode }) {
  return (
    <a
      href={href}
      target="_blank"
      rel="noopener noreferrer"
      className="inline-flex items-center gap-1 text-primary text-sm hover:underline"
    >
      {children}
      <ExternalLinkIcon className="size-3.5" />
    </a>
  )
}

const TIMEZONES: string[] = (() => {
  try {
    return Intl.supportedValuesOf('timeZone')
  } catch {
    // Fallback for older browsers — a small representative set.
    return [
      'UTC',
      'America/New_York',
      'America/Chicago',
      'America/Denver',
      'America/Los_Angeles',
      'Europe/London',
      'Europe/Paris',
      'Europe/Berlin',
      'Asia/Tokyo',
      'Australia/Sydney',
    ]
  }
})()

function storeToFormValues(store: Store): StoreSettingsFormValues {
  return {
    name: store.name,
    preferred_admin_locale: store.preferred_admin_locale ?? '',
    preferred_timezone: store.preferred_timezone,
    preferred_unit_system: (store.preferred_unit_system as 'metric' | 'imperial') ?? 'metric',
    preferred_weight_unit: store.preferred_weight_unit,
    preferred_default_package_weight: Number(store.preferred_default_package_weight ?? 0),
    preferred_default_package_length: Number(store.preferred_default_package_length ?? 0),
    preferred_default_package_width: Number(store.preferred_default_package_width ?? 0),
    preferred_default_package_height: Number(store.preferred_default_package_height ?? 0),
    preferred_storefront_access:
      (store.preferred_storefront_access as (typeof STOREFRONT_ACCESS_LEVELS)[number]) ?? 'public',
    preferred_guest_checkout: store.preferred_guest_checkout ?? true,
    preferred_company_field_enabled: store.preferred_company_field_enabled ?? false,
    preferred_address_requires_phone: store.preferred_address_requires_phone ?? false,
    preferred_capture_method:
      (store.preferred_capture_method as (typeof CAPTURE_METHODS)[number]) ?? 'checkout',
    preferred_pricing_provider: store.preferred_pricing_provider || INTERNAL_PROVIDER_KEY,
    preferred_inventory_provider: store.preferred_inventory_provider || INTERNAL_PROVIDER_KEY,
    preferred_pricing_provider_failure_policy:
      (store.preferred_pricing_provider_failure_policy as (typeof PROVIDER_FAILURE_POLICIES)[number]) ??
      'strict',
    preferred_inventory_provider_failure_policy:
      (store.preferred_inventory_provider_failure_policy as (typeof PROVIDER_FAILURE_POLICIES)[number]) ??
      'fallback',
    preferred_tax_using_ship_address: store.preferred_tax_using_ship_address ?? true,
    preferred_track_inventory_levels: store.preferred_track_inventory_levels ?? true,
    preferred_stock_reservations_enabled: store.preferred_stock_reservations_enabled ?? true,
    preferred_track_price_history: store.preferred_track_price_history ?? true,
    preferred_show_products_without_price: store.preferred_show_products_without_price ?? false,
    preferred_disable_sku_validation: store.preferred_disable_sku_validation ?? false,
    preferred_document_number_format:
      (store.preferred_document_number_format as (typeof DOCUMENT_NUMBER_FORMATS)[number]) ??
      'sequential',
    preferred_order_number_prefix: store.preferred_order_number_prefix ?? 'R',
    preferred_order_number_suffix: store.preferred_order_number_suffix ?? '',
    preferred_order_number_sequence_start: Number(
      store.preferred_order_number_sequence_start ?? 1001,
    ),
  }
}

function StoreSettingsPage() {
  const { t } = useTranslation()
  const { data: store, isLoading, error, refetch } = useStoreSettings()

  if (isLoading || !store) {
    return (
      <div className="flex flex-col gap-6">
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-64 w-full" />
        <Skeleton className="h-64 w-full" />
      </div>
    )
  }

  if (error) {
    return (
      <ErrorState
        title={t('admin.store.load_failed_title')}
        description={error instanceof Error ? error.message : undefined}
        onRetry={() => refetch()}
      />
    )
  }

  // Mounted only once `store` is loaded so `useForm` initializes with concrete
  // defaults — never `undefined`. Keeps the underlying Selects controlled from
  // the first render.
  return <StoreSettingsForm store={store} />
}

function StoreSettingsForm({ store }: { store: Store }) {
  const { t } = useTranslation()
  const { user } = useAuth()
  const { storeId } = useStore()
  const updateMutation = useUpdateStoreSettings()
  const switchAdminLocale = useSwitchAdminLocale()
  const { data: dataSources } = useStoreDataSources()

  const form = useForm<StoreSettingsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(storeSettingsFormSchema) as any,
    defaultValues: { ...storeToFormValues(store), ...extensionFormValues('store', store) },
  })

  // Shows the merchant the shape their next order number will take. The
  // sequential preview uses the configured starting value, which is only
  // accurate for a store that has not taken an order yet — the copy under it
  // says so rather than the preview pretending to know the live counter.
  // Once the counter has issued its first number the starting value is inert,
  // so the field says so rather than accepting a value that does nothing.
  const sequenceStarted = store.order_number_sequence_started ?? false
  const numberFormat = form.watch('preferred_document_number_format')
  const numberPrefix = form.watch('preferred_order_number_prefix')
  const numberSuffix = form.watch('preferred_order_number_suffix')
  const numberStart = form.watch('preferred_order_number_sequence_start')
  const orderNumberPreview = `${numberPrefix ?? ''}${
    numberFormat === 'random' ? '482910375' : (numberStart ?? 1001)
  }${numberSuffix ?? ''}`

  // Live unit suffixes for the default-package inputs.
  const weightUnit = form.watch('preferred_weight_unit')
  const dimensionUnit = form.watch('preferred_unit_system') === 'metric' ? 'cm' : 'in'

  // When unit_system flips, reset weight_unit to the first valid option for
  // that system so the form never holds an inconsistent pair.
  const unitSystem = form.watch('preferred_unit_system')
  useEffect(() => {
    const validUnits = WEIGHT_UNITS[unitSystem] ?? []
    const current = form.getValues('preferred_weight_unit')
    if (current && !validUnits.includes(current)) {
      form.setValue('preferred_weight_unit', validUnits[0] ?? '', { shouldDirty: true })
    }
  }, [unitSystem, form])

  const onSubmit = async (values: StoreSettingsFormValues) => {
    // Whether the admin language was changed in THIS save — compared against the
    // store's currently-persisted value, not RHF's `dirtyFields` (which a Base UI
    // Select via Controller doesn't reliably populate). Saving unrelated fields
    // (name, timezone, units) must not touch the admin's UI language.
    const code = values.preferred_admin_locale
    const localeChanged = (code ?? '') !== (store.preferred_admin_locale ?? '')
    // Extension fields come from live form state — the Zod parse behind
    // `values` strips keys the first-party schema doesn't know.
    const extensionValues = extensionSubmitValues('store', form)
    try {
      await updateMutation.mutateAsync({
        name: values.name,
        preferred_admin_locale: values.preferred_admin_locale || undefined,
        preferred_timezone: values.preferred_timezone,
        preferred_unit_system: values.preferred_unit_system,
        preferred_weight_unit: values.preferred_weight_unit,
        preferred_default_package_weight: values.preferred_default_package_weight,
        preferred_default_package_length: values.preferred_default_package_length,
        preferred_default_package_width: values.preferred_default_package_width,
        preferred_default_package_height: values.preferred_default_package_height,
        preferred_storefront_access: values.preferred_storefront_access,
        preferred_guest_checkout: values.preferred_guest_checkout,
        preferred_company_field_enabled: values.preferred_company_field_enabled,
        preferred_address_requires_phone: values.preferred_address_requires_phone,
        preferred_capture_method: values.preferred_capture_method,
        preferred_pricing_provider: values.preferred_pricing_provider,
        preferred_inventory_provider: values.preferred_inventory_provider,
        preferred_pricing_provider_failure_policy: values.preferred_pricing_provider_failure_policy,
        preferred_inventory_provider_failure_policy:
          values.preferred_inventory_provider_failure_policy,
        preferred_tax_using_ship_address: values.preferred_tax_using_ship_address,
        preferred_track_inventory_levels: values.preferred_track_inventory_levels,
        preferred_stock_reservations_enabled: values.preferred_stock_reservations_enabled,
        preferred_track_price_history: values.preferred_track_price_history,
        preferred_show_products_without_price: values.preferred_show_products_without_price,
        preferred_disable_sku_validation: values.preferred_disable_sku_validation,
        preferred_document_number_format: values.preferred_document_number_format,
        preferred_order_number_prefix: values.preferred_order_number_prefix,
        preferred_order_number_suffix: values.preferred_order_number_suffix,
        preferred_order_number_sequence_start: values.preferred_order_number_sequence_start,
        ...extensionValues,
      })
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
      // Reset FIRST so the form is no longer dirty — otherwise the language
      // switch below reloads the page while the `beforeunload` dirty-guard is
      // still armed, triggering the browser's "unsaved changes" prompt.
      form.reset({ ...values, ...extensionValues })
      // When the admin language was actually changed:
      //  - a concrete value → adopt it as this admin's own UI language and switch
      //    the dashboard into it immediately (same as the profile / top-bar);
      //  - a blank value ("use the default") → reconcile, so an admin with no
      //    personal choice who was on this store's auto-applied default reverts
      //    to the app default instead of being stuck on the old language.
      if (localeChanged) {
        if (code) {
          await switchAdminLocale(code)
        } else {
          reconcileStoreDefaultLocale(
            null,
            storeId,
            user?.selected_locale ?? null,
            getAvailableUiLocales().map((l) => l.code),
          )
        }
      }
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.failed_to_update_store'),
      })
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  // Compute the dynamic timezone option list once. `Intl.supportedValuesOf`
  // can be expensive on some browsers; memo keeps re-renders cheap.
  const timezoneOptions = useMemo(() => TIMEZONES.map((tz) => ({ value: tz, label: tz })), [])
  const unitSystemOptions = useMemo(
    () => UNIT_SYSTEMS.map((value) => ({ value, label: t(`admin.store.unit_systems.${value}`) })),
    [t],
  )
  const weightOptions = useMemo(
    () =>
      (WEIGHT_UNITS[unitSystem] ?? WEIGHT_UNITS.metric).map((value) => ({
        value,
        label: t(`admin.store.weight_units.${value}`),
      })),
    [t, unitSystem],
  )
  const storefrontAccessOptions = useMemo(
    () =>
      STOREFRONT_ACCESS_LEVELS.map((value) => ({
        value,
        label: t(`admin.fields.store.storefront_access.options.${value}`),
      })),
    [t],
  )
  const documentNumberFormatOptions = useMemo(
    () =>
      DOCUMENT_NUMBER_FORMATS.map((value) => ({
        value,
        label: t(`admin.fields.store.document_number_format.options.${value}`),
      })),
    [t],
  )
  // A provider whose integration is not connected stays in the list but is
  // not selectable — hiding it would leave a merchant wondering where the ERP
  // they just installed went.
  const providerOptions = useCallback(
    (providers: StoreDataSourceProvider[] | undefined) =>
      (providers ?? []).map((provider) => ({
        value: provider.key,
        label:
          provider.key === INTERNAL_PROVIDER_KEY
            ? t('admin.fields.store.data_sources.internal')
            : provider.name,
        disabled: !provider.available,
        description: provider.available
          ? undefined
          : t('admin.fields.store.data_sources.not_connected'),
      })),
    [t],
  )
  const failurePolicyOptions = useMemo(
    () =>
      PROVIDER_FAILURE_POLICIES.map((value) => ({
        value,
        label: t(`admin.fields.store.data_sources.policies.${value}.label`),
      })),
    [t],
  )
  const captureMethodOptions = useMemo(
    () =>
      CAPTURE_METHODS.map((value) => ({
        value,
        label: t(`admin.fields.store.capture_method.options.${value}.label`),
        description: t(`admin.fields.store.capture_method.options.${value}.description`),
      })),
    [t],
  )
  // Admin-UI language options come from the dashboard's own shipped locale
  // bundles (getAvailableUiLocales) — the SAME canonical source the profile
  // picker and top-bar switcher use, so the lists never desync. The leading
  // empty option clears the store-wide override (preferred_admin_locale is
  // nullable → "no override, fall back to the app default").
  const adminLocaleOptions = useMemo(
    () => [
      { value: '', label: t('admin.fields.store.preferred_admin_locale.placeholder') },
      ...getAvailableUiLocales().map((l) => ({ value: l.code, label: l.name })),
    ],
    [t],
  )

  const { errors } = form.formState

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <ResourceLayout
          header={
            <PageHeader
              title={t('admin.pages.settings.store.title')}
              subtitle={t('admin.pages.settings.store.subtitle')}
              actions={<FormActions form={form} />}
            />
          }
          main={
            <>
              {errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {errors.root.message}
                </p>
              )}
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_general')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <Field>
                      <FieldLabel htmlFor="store-name">
                        {t('admin.fields.store.name.label')}
                      </FieldLabel>
                      <Input
                        id="store-name"
                        aria-invalid={!!errors.name || undefined}
                        {...form.register('name')}
                      />
                      <FieldError errors={[errors.name]} />
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_standards')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SelectField
                      id="store-admin-locale"
                      label={t('admin.fields.store.preferred_admin_locale.label')}
                      placeholder={t('admin.fields.store.preferred_admin_locale.placeholder')}
                      name="preferred_admin_locale"
                      control={form.control}
                      options={adminLocaleOptions}
                    />
                    <SelectField
                      id="store-timezone"
                      label={t('admin.fields.store.preferred_timezone.label')}
                      placeholder={t('admin.fields.store.preferred_timezone.placeholder')}
                      name="preferred_timezone"
                      control={form.control}
                      options={timezoneOptions}
                    />
                    <SelectField
                      id="store-unit-system"
                      label={t('admin.fields.store.preferred_unit_system.label')}
                      name="preferred_unit_system"
                      control={form.control}
                      options={unitSystemOptions}
                    />
                    <SelectField
                      id="store-weight-unit"
                      label={t('admin.fields.store.preferred_weight_unit.label')}
                      name="preferred_weight_unit"
                      control={form.control}
                      options={weightOptions}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_default_package')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <FieldDescription>
                      {t('admin.pages.settings.store.default_package_description')}
                    </FieldDescription>
                    <div className="grid grid-cols-[1fr_120px] gap-3">
                      <Field>
                        <FieldLabel htmlFor="store-default-package-weight">
                          {t('admin.fields.store.preferred_default_package_weight.label')}
                        </FieldLabel>
                        <Input
                          id="store-default-package-weight"
                          type="number"
                          min="0"
                          step="0.01"
                          {...form.register('preferred_default_package_weight')}
                        />
                        <FieldError
                          errors={[form.formState.errors.preferred_default_package_weight]}
                        />
                      </Field>
                      <Field>
                        <FieldLabel htmlFor="store-default-package-weight-unit">
                          {t('admin.fields.variant.weight_unit.label')}
                        </FieldLabel>
                        <Input id="store-default-package-weight-unit" value={weightUnit} disabled />
                      </Field>
                    </div>
                    <div className="grid grid-cols-[1fr_1fr_1fr_120px] gap-3">
                      {(
                        [
                          ['length', 'store-default-package-length'],
                          ['width', 'store-default-package-width'],
                          ['height', 'store-default-package-height'],
                        ] as const
                      ).map(([side, id]) => (
                        <Field key={side}>
                          <FieldLabel htmlFor={id}>
                            {t(`admin.fields.store.preferred_default_package_dimensions.${side}`)}
                          </FieldLabel>
                          <Input
                            id={id}
                            type="number"
                            min="0"
                            step="0.01"
                            {...form.register(`preferred_default_package_${side}`)}
                          />
                        </Field>
                      ))}
                      <Field>
                        <FieldLabel htmlFor="store-default-package-dim-unit">
                          {t('admin.fields.variant.dimensions_unit.label')}
                        </FieldLabel>
                        <Input id="store-default-package-dim-unit" value={dimensionUnit} disabled />
                      </Field>
                    </div>
                    <FieldDescription>
                      {t('admin.fields.store.preferred_default_package_dimensions.help')}
                    </FieldDescription>
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_storefront_access')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SelectField
                      id="store-storefront-access"
                      label={t('admin.fields.store.storefront_access.label')}
                      name="preferred_storefront_access"
                      control={form.control}
                      options={storefrontAccessOptions}
                      help={t('admin.fields.store.storefront_access.help')}
                    />
                    <Field>
                      <div className="flex items-start justify-between gap-4">
                        <div className="flex flex-col">
                          <FieldLabel htmlFor="store-guest-checkout" className="cursor-pointer">
                            {t('admin.fields.store.guest_checkout.label')}
                          </FieldLabel>
                          <span className="text-xs text-muted-foreground">
                            {t('admin.fields.store.guest_checkout.help')}
                          </span>
                        </div>
                        <Controller
                          name="preferred_guest_checkout"
                          control={form.control}
                          render={({ field }) => (
                            <Switch
                              id="store-guest-checkout"
                              checked={!!field.value}
                              onCheckedChange={field.onChange}
                            />
                          )}
                        />
                      </div>
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_addresses')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SwitchField
                      id="store-company-field-enabled"
                      label={t('admin.fields.store.company_field_enabled.label')}
                      help={t('admin.fields.store.company_field_enabled.help')}
                      name="preferred_company_field_enabled"
                      control={form.control}
                    />
                    <SwitchField
                      id="store-address-requires-phone"
                      label={t('admin.fields.store.address_requires_phone.label')}
                      help={t('admin.fields.store.address_requires_phone.help')}
                      name="preferred_address_requires_phone"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_order_numbers')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SelectField
                      id="store-document-number-format"
                      label={t('admin.fields.store.document_number_format.label')}
                      name="preferred_document_number_format"
                      control={form.control}
                      options={documentNumberFormatOptions}
                      help={t('admin.fields.store.document_number_format.help')}
                    />
                    <div className="grid gap-4 sm:grid-cols-2">
                      <Field>
                        <FieldLabel htmlFor="store-order-number-prefix">
                          {t('admin.fields.store.order_number_prefix.label')}
                        </FieldLabel>
                        <Input
                          id="store-order-number-prefix"
                          aria-invalid={!!errors.preferred_order_number_prefix || undefined}
                          {...form.register('preferred_order_number_prefix')}
                        />
                        <FieldError errors={[errors.preferred_order_number_prefix]} />
                      </Field>
                      <Field>
                        <FieldLabel htmlFor="store-order-number-suffix">
                          {t('admin.fields.store.order_number_suffix.label')}
                        </FieldLabel>
                        <Input
                          id="store-order-number-suffix"
                          aria-invalid={!!errors.preferred_order_number_suffix || undefined}
                          {...form.register('preferred_order_number_suffix')}
                        />
                        <FieldError errors={[errors.preferred_order_number_suffix]} />
                      </Field>
                    </div>
                    {numberFormat === 'sequential' && (
                      <Field>
                        <FieldLabel htmlFor="store-order-number-sequence-start">
                          {t('admin.fields.store.order_number_sequence_start.label')}
                        </FieldLabel>
                        <Input
                          id="store-order-number-sequence-start"
                          type="number"
                          min={1}
                          disabled={sequenceStarted}
                          aria-invalid={!!errors.preferred_order_number_sequence_start || undefined}
                          {...form.register('preferred_order_number_sequence_start')}
                        />
                        <FieldDescription>
                          {sequenceStarted
                            ? t('admin.fields.store.order_number_sequence_start.locked')
                            : t('admin.fields.store.order_number_sequence_start.help')}
                        </FieldDescription>
                        <FieldError errors={[errors.preferred_order_number_sequence_start]} />
                      </Field>
                    )}
                    <Field>
                      <FieldLabel>{t('admin.fields.store.order_number_preview.label')}</FieldLabel>
                      <p className="font-mono text-sm">{orderNumberPreview}</p>
                      <FieldDescription>
                        {t('admin.fields.store.order_number_preview.help')}
                      </FieldDescription>
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_payments')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <Controller
                      control={form.control}
                      name="preferred_capture_method"
                      render={({ field }) => (
                        <ChoiceCardPicker
                          label={t('admin.fields.store.capture_method.label')}
                          help={t('admin.fields.store.capture_method.help')}
                          options={captureMethodOptions}
                          value={field.value}
                          onChange={field.onChange}
                        />
                      )}
                    />
                    <SwitchField
                      id="store-tax-using-ship-address"
                      label={t('admin.fields.store.tax_using_ship_address.label')}
                      help={t('admin.fields.store.tax_using_ship_address.help')}
                      name="preferred_tax_using_ship_address"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_inventory')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SwitchField
                      id="store-track-inventory-levels"
                      label={t('admin.fields.store.track_inventory_levels.label')}
                      help={t('admin.fields.store.track_inventory_levels.help')}
                      name="preferred_track_inventory_levels"
                      control={form.control}
                    />
                    <SwitchField
                      id="store-stock-reservations-enabled"
                      label={t('admin.fields.store.stock_reservations_enabled.label')}
                      help={t('admin.fields.store.stock_reservations_enabled.help')}
                      name="preferred_stock_reservations_enabled"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_data_sources')}</CardTitle>
                  <CardDescription>
                    {t('admin.fields.store.data_sources.description')}
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SelectField
                      id="store-pricing-provider"
                      label={t('admin.fields.store.data_sources.pricing_provider.label')}
                      help={t('admin.fields.store.data_sources.pricing_provider.help')}
                      name="preferred_pricing_provider"
                      control={form.control}
                      options={providerOptions(dataSources?.pricing_providers)}
                    />
                    <SelectField
                      id="store-pricing-failure-policy"
                      label={t('admin.fields.store.data_sources.pricing_failure_policy.label')}
                      help={t('admin.fields.store.data_sources.pricing_failure_policy.help')}
                      name="preferred_pricing_provider_failure_policy"
                      control={form.control}
                      options={failurePolicyOptions}
                    />
                    <SelectField
                      id="store-inventory-provider"
                      label={t('admin.fields.store.data_sources.inventory_provider.label')}
                      help={t('admin.fields.store.data_sources.inventory_provider.help')}
                      name="preferred_inventory_provider"
                      control={form.control}
                      options={providerOptions(dataSources?.inventory_providers)}
                    />
                    <SelectField
                      id="store-inventory-failure-policy"
                      label={t('admin.fields.store.data_sources.inventory_failure_policy.label')}
                      help={t('admin.fields.store.data_sources.inventory_failure_policy.help')}
                      name="preferred_inventory_provider_failure_policy"
                      control={form.control}
                      options={failurePolicyOptions}
                    />
                  </FieldGroup>
                  <div className="mt-6 flex flex-col gap-2 border-t pt-4 sm:flex-row sm:gap-6">
                    <DocsLink href={PRICING_PROVIDER_DOCS_URL}>
                      {t('admin.fields.store.data_sources.pricing_provider.docs_link')}
                    </DocsLink>
                    <DocsLink href={INVENTORY_PROVIDER_DOCS_URL}>
                      {t('admin.fields.store.data_sources.inventory_provider.docs_link')}
                    </DocsLink>
                  </div>
                </CardContent>
              </Card>
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.store.tab_catalog')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SwitchField
                      id="store-show-products-without-price"
                      label={t('admin.fields.store.show_products_without_price.label')}
                      help={t('admin.fields.store.show_products_without_price.help')}
                      name="preferred_show_products_without_price"
                      control={form.control}
                    />
                    <SwitchField
                      id="store-track-price-history"
                      label={t('admin.fields.store.track_price_history.label')}
                      help={t('admin.fields.store.track_price_history.help')}
                      name="preferred_track_price_history"
                      control={form.control}
                    />
                    <SwitchField
                      id="store-disable-sku-validation"
                      label={t('admin.fields.store.disable_sku_validation.label')}
                      help={t('admin.fields.store.disable_sku_validation.help')}
                      name="preferred_disable_sku_validation"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>
              <Slot name="store.form_main" context={{ store }} />
            </>
          }
        />
      </form>
    </FormProvider>
  )
}

interface SelectFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  placeholder?: string
  help?: string
  name: FieldPath<TValues>
  control: Control<TValues>
  options: ReadonlyArray<{ value: string; label: string }>
}

function SelectField<TValues extends FieldValues>({
  id,
  label,
  placeholder,
  help,
  name,
  control,
  options,
}: SelectFieldProps<TValues>) {
  return (
    <Controller
      name={name}
      control={control}
      render={({ field, fieldState }) => (
        <Field>
          <FieldLabel htmlFor={id}>{label}</FieldLabel>
          <Select items={options as never} value={field.value} onValueChange={field.onChange}>
            <SelectTrigger id={id} aria-invalid={!!fieldState.error || undefined}>
              <SelectValue placeholder={placeholder} />
            </SelectTrigger>
            <SelectContent>
              {options.map((o) => (
                <SelectItem key={o.value} value={o.value}>
                  {o.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
          {help && <span className="text-xs text-muted-foreground">{help}</span>}
          <FieldError errors={[fieldState.error]} />
        </Field>
      )}
    />
  )
}

interface SwitchFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  help?: string
  name: FieldPath<TValues>
  control: Control<TValues>
}

function SwitchField<TValues extends FieldValues>({
  id,
  label,
  help,
  name,
  control,
}: SwitchFieldProps<TValues>) {
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
          name={name}
          control={control}
          render={({ field }) => (
            <Switch id={id} checked={!!field.value} onCheckedChange={field.onChange} />
          )}
        />
      </div>
    </Field>
  )
}
