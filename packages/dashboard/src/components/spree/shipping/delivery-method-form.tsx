import type {
  Channel,
  DeliveryProfile,
  DeliveryRateProviderCatalogEntry,
  DeliveryRateProviderOption,
  DeliveryZone,
  IntegrationTypeDefinition,
  PreferenceField,
  Product,
} from '@spree/admin-sdk'
import {
  type adminClient,
  Can,
  currencyParts,
  PreferencesForm,
  ResourceMultiAutocomplete,
  Subject,
  useResourceKey,
  useStockLocations,
  useStore,
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
  FieldLabel,
  Input,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
  RadioGroup,
  RadioGroupItem,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
} from '@spree/dashboard-ui'
import { PencilIcon, PlusIcon, Trash2Icon } from '@spree/dashboard-ui/icons'
import { useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'
import { useEffect, useMemo, useState } from 'react'
import { Controller, type UseFormReturn, useFieldArray } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { channelAutocompleteProps } from '../../../hooks/use-channels'
import {
  useDeliveryCalculators,
  useDeliveryMethodRuleTypes,
  useDeliveryRateProviders,
  useFulfillmentProviders,
} from '../../../hooks/use-delivery-methods'
import { useIntegrations, useIntegrationTypes } from '../../../hooks/use-integrations'
import { productAutocompleteProps } from '../../../hooks/use-products'
import { useTaxCategories } from '../../../hooks/use-tax-categories'
import { amountForCurrency, applyCurrencyAmount } from '../../../lib/delivery-method-summary'
import type { DeliveryMethodFormValues } from '../../../schemas/delivery-method'
import { ConfigureIntegrationSheet } from '../integrations/configure-integration-sheet'
import { StockLocationScopeField } from './stock-location-scope-field'

/**
 * Calculators whose price is a plain amount, which a multi-currency store
 * quotes per currency through the `amounts` preference. Every other
 * calculator (percent, tiered) is currency-neutral and keeps the generic
 * preference rendering.
 */
const AMOUNT_BASED_CALCULATORS = [
  'Spree::Calculator::Shipping::FlatRate',
  'Spree::Calculator::Shipping::PerItem',
  'Spree::Calculator::Shipping::DigitalDelivery',
]

/**
 * Preference keys the per-currency editor owns on those calculators. `amount`
 * and `currency` are the pre-6.0 single-currency pair: they belong to the
 * currency the method names, not automatically to the store default.
 */
const CURRENCY_AMOUNT_KEYS = ['amount', 'currency', 'amounts']

/** One entry from the delivery-method-rule discovery endpoint. */
type DeliveryMethodRuleType = Awaited<
  ReturnType<typeof adminClient.deliveryMethods.ruleTypes>
>['data'][number]

interface MethodFormProps {
  form: UseFormReturn<DeliveryMethodFormValues>
  profile: DeliveryProfile
  zones: DeliveryZone[]
  /**
   * True when the merchant opened this form from inside a zone, so the zone
   * is already decided. Re-asking would be redundant, and answering
   * differently would silently file the method under another zone.
   */
  zonePreselected?: boolean
}

/** The fulfillment provider currently chosen, resolved to its catalog entry. */
function useSelectedFulfillmentProvider(form: UseFormReturn<DeliveryMethodFormValues>) {
  const { data: fulfillmentProviders } = useFulfillmentProviders()
  const fulfillmentProvider = form.watch('fulfillment_provider')

  return useMemo(
    () => (fulfillmentProviders?.data ?? []).find((p) => p.type === fulfillmentProvider),
    [fulfillmentProviders, fulfillmentProvider],
  )
}

/**
 * One block of the method form. The form lives in a sheet, which is already a
 * bordered surface — nesting cards inside it stacks three borders around every
 * field, so a rule separates each block instead.
 *
 * Most blocks carry no heading: their fields are labelled already, and
 * "Providers" above two selects both named "…provider" is a label for a label.
 * A title is for a block whose fields do not announce themselves.
 */
function FormSection({
  title,
  description,
  action,
  children,
}: {
  title?: string
  description?: string
  action?: React.ReactNode
  children: React.ReactNode
}) {
  const heading = title || description || action

  return (
    <section className="flex flex-col gap-4 border-t pt-6 first:border-t-0 first:pt-0">
      {heading && (
        <div className="flex items-start justify-between gap-2">
          <div className="flex flex-col gap-0.5">
            {title && <h3 className="font-medium text-sm">{title}</h3>}
            {description && <p className="text-muted-foreground text-xs">{description}</p>}
          </div>
          {action}
        </div>
      )}
      {children}
    </section>
  )
}

/**
 * Every section of the delivery method form, in the order a merchant answers
 * them: who fulfills and prices it (which decides what the rest even asks),
 * what it is called, which services it offers, what it costs, where it
 * applies, how long it takes, and when it is eligible.
 *
 * Zones and carrier services are destination concerns, so a method collected
 * at a counter or delivered digitally shows neither — pickup gets the counters
 * it can be collected from instead. The zone section also disappears when the
 * merchant started from a zone: it is answered already.
 */
export function DeliveryMethodFormCards({
  form,
  profile,
  zones,
  zonePreselected,
}: MethodFormProps) {
  const selectedProvider = useSelectedFulfillmentProvider(form)
  const isPickup = !!(selectedProvider?.pickup || selectedProvider?.pickup_point)
  const isDigital = !!selectedProvider?.digital
  const shipsToAddress = !isPickup && !isDigital

  // The provider decides what kind of method this is — which sections even
  // apply — so it is asked first and names the method on the way past.
  return (
    <>
      <ProvidersCard form={form} profile={profile} />
      <GeneralCard form={form} />
      {shipsToAddress && <CarrierServicesCard form={form} />}
      <PricingCard form={form} />
      {isPickup && <CollectionLocationsCard form={form} />}
      {shipsToAddress && !zonePreselected && <ZoneCard form={form} zones={zones} />}
      <DeliveryEstimateSection form={form} />
      <ConditionsCard form={form} />
    </>
  )
}

/**
 * What the customer is told about timing, and where a hand-entered tracking
 * number points — both the merchant's own answers on a method they price
 * themselves. A carrier supplies an estimate with every rate and resolves
 * its own tracking links, so the whole section is hidden there.
 */
function DeliveryEstimateSection({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const selectedRateProvider = useSelectedRateProvider(form)

  if (selectedRateProvider?.uses_calculator === false) return null

  return (
    <FormSection title={t('admin.delivery_methods.cards.estimate')}>
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
        <FieldLabel htmlFor="tracking_url">
          {t('admin.fields.delivery_method.tracking_url.label')}
        </FieldLabel>
        <Input
          id="tracking_url"
          placeholder="https://carrier.example/track?num=:tracking"
          {...form.register('tracking_url')}
        />
      </Field>
    </FormSection>
  )
}

// ---------------------------------------------------------------------------
// Collection locations — which counters a pickup method can be collected from
// ---------------------------------------------------------------------------

function CollectionLocationsCard({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { data: stockLocations } = useStockLocations()
  const selectedIds = form.watch('stock_location_ids') ?? []

  // Only counters that accept collection can serve a pickup method; the rest
  // would be an option the storefront never offers.
  const locations = (stockLocations?.data ?? []).filter((location) => location.pickup_enabled)

  // "Every pickup-enabled location" is the absence of a narrowing, exactly as
  // the API reads an empty array — so the radio reads the field rather than
  // holding state of its own.
  const [scope, setScope] = useState<'all' | 'selected'>(
    selectedIds.length > 0 ? 'selected' : 'all',
  )
  useEffect(() => {
    if (selectedIds.length > 0) setScope('selected')
  }, [selectedIds.length])

  return (
    <FormSection title={t('admin.delivery_methods.collection_locations.title')}>
      <Controller
        name="stock_location_ids"
        control={form.control}
        render={({ field }) => (
          <StockLocationScopeField
            idPrefix="collection"
            scope={scope}
            onScopeChange={(next) => {
              setScope(next)
              if (next === 'all') field.onChange([])
            }}
            locations={locations}
            selectedIds={field.value ?? []}
            onSelectedIdsChange={field.onChange}
            allLabel={t('admin.delivery_methods.collection_locations.all')}
            selectedLabel={t('admin.delivery_methods.collection_locations.specific')}
            emptyLabel={t('admin.delivery_methods.collection_locations.none_enabled')}
          />
        )}
      />
    </FormSection>
  )
}

function GeneralCard({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <FormSection>
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
    </FormSection>
  )
}

// ---------------------------------------------------------------------------
// Providers — who fulfills the method and where its price comes from
// ---------------------------------------------------------------------------

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
  options: { value: string; label: string; disabled?: boolean }[]
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
                <SelectItem key={option.value} value={option.value} disabled={option.disabled}>
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

function ProvidersCard({
  form,
  profile,
}: {
  form: UseFormReturn<DeliveryMethodFormValues>
  profile: DeliveryProfile
}) {
  const { t } = useTranslation()
  const { data: fulfillmentProviders } = useFulfillmentProviders()
  const { data: rateProviders } = useDeliveryRateProviders()

  const fulfillmentProvider = form.watch('fulfillment_provider')
  const rateProvider = form.watch('rate_provider')

  // A digital profile only fulfills digitally, and a physical one never does —
  // offering a provider the server would reject just produces a 422 the
  // merchant has to decode.
  const eligibleFulfillmentProviders = useMemo(
    () =>
      (fulfillmentProviders?.data ?? []).filter((provider) =>
        profile.digital ? provider.digital : !provider.digital,
      ),
    [fulfillmentProviders, profile.digital],
  )

  // An unconnected carrier provider stays listed but unselectable, with a
  // connect prompt below — hiding it would leave the merchant wondering
  // where their carrier went.
  const providerOptions = eligibleFulfillmentProviders.map((provider) => ({
    value: provider.type,
    label: provider.available
      ? provider.name
      : t('admin.delivery_methods.provider_needs_connection', { name: provider.name }),
    disabled: !provider.available,
  }))

  const selectedFulfillmentProvider = useMemo(
    () => (fulfillmentProviders?.data ?? []).find((p) => p.type === fulfillmentProvider),
    [fulfillmentProviders, fulfillmentProvider],
  )

  // A carrier quotes real shipments, so it can only price a method that ships
  // to an address — on a pickup or digital method those options are dead ends.
  const shipsToAddress = selectedFulfillmentProvider?.requires_address ?? true
  const rateProviderOptions = (rateProviders?.data ?? [])
    .filter((provider) => shipsToAddress || !provider.requires_address)
    .map((provider) => ({
      value: provider.type,
      label: provider.available
        ? provider.name
        : t('admin.delivery_methods.provider_needs_connection', { name: provider.name }),
      disabled: !provider.available,
    }))

  // A provider the registry no longer offers — an uninstalled gem, or a list
  // fetched before its integration was connected — would otherwise render as
  // its bare class name, since the trigger label comes from these options.
  if (rateProvider && !rateProviderOptions.some((option) => option.value === rateProvider)) {
    rateProviderOptions.push({
      value: rateProvider,
      label: t('admin.delivery_methods.provider_unavailable', {
        name: rateProvider.split('::').pop() ?? rateProvider,
      }),
      disabled: true,
    })
  }

  // Every installed shipping integration that isn't connected yet, straight
  // from the integrations registry — a carrier gem is offered here even
  // before it registers a provider, so the merchant never has to discover
  // Settings → Integrations on their own.
  const { data: integrationTypes } = useIntegrationTypes()
  const { data: connectedIntegrations } = useIntegrations()
  const connectableIntegrations = useMemo(() => {
    const connected = new Set(
      (connectedIntegrations?.data ?? []).filter((row) => row.active).map((row) => row.type),
    )
    return (integrationTypes?.data ?? []).filter(
      (type) => type.group === 'shipping' && !connected.has(type.type),
    )
  }, [integrationTypes, connectedIntegrations])

  const [connectingType, setConnectingType] = useState<IntegrationTypeDefinition | null>(null)
  // Set when a connect finishes, so the effect below can select the
  // providers that integration unlocks once the refreshed lists arrive.
  const [justConnected, setJustConnected] = useState<string | null>(null)
  const queryClient = useQueryClient()
  const rateProvidersKey = useResourceKey('delivery-methods', 'rate-providers')
  const fulfillmentProvidersKey = useResourceKey('delivery-methods', 'fulfillment-providers')
  const integrationsKey = useResourceKey('integrations')

  // Connecting an integration from this form is an act of intent: select
  // the providers it unlocks once the refreshed lists arrive, so the
  // merchant does not have to find and set them by hand afterwards.
  useEffect(() => {
    if (!justConnected) return

    const unlockedRateProvider = (rateProviders?.data ?? []).find(
      (provider) => provider.integration_type === justConnected && provider.available,
    )
    const unlockedFulfillmentProvider = eligibleFulfillmentProviders.find(
      (provider) => provider.integration_type === justConnected && provider.available,
    )
    if (!unlockedRateProvider && !unlockedFulfillmentProvider) return

    if (unlockedRateProvider) {
      form.setValue('rate_provider', unlockedRateProvider.type, { shouldDirty: true })
    }
    if (unlockedFulfillmentProvider) {
      form.setValue('fulfillment_provider', unlockedFulfillmentProvider.type, { shouldDirty: true })
    }
    setJustConnected(null)
  }, [justConnected, rateProviders, eligibleFulfillmentProviders, form])

  // Keep the fulfillment provider valid for this profile's kind: a physical
  // profile must not keep a digital provider that a kind switch left behind.
  useEffect(() => {
    if (eligibleFulfillmentProviders.length === 0) return
    if (eligibleFulfillmentProviders.some((provider) => provider.type === fulfillmentProvider)) {
      return
    }

    const fallback =
      eligibleFulfillmentProviders.find((provider) => provider.available) ??
      eligibleFulfillmentProviders[0]
    form.setValue('fulfillment_provider', fallback.type)
  }, [eligibleFulfillmentProviders, fulfillmentProvider, form])

  // A carrier rate provider left over from a shipping method would make a
  // pickup method unsavable — drop back to calculator pricing instead.
  useEffect(() => {
    if (shipsToAddress || !rateProvider) return
    const selected = (rateProviders?.data ?? []).find((p) => p.type === rateProvider)
    if (selected?.requires_address) form.setValue('rate_provider', '')
  }, [shipsToAddress, rateProvider, rateProviders, form])

  // The select displayed the server default while submitting a blank value —
  // harmless (blank resolves to Internal) but the shown and saved values
  // disagreed. Seed it once the default is known, leaving a touched field or
  // a loaded record alone.
  const defaultRateProvider = rateProviders?.default ?? ''
  const rateProviderDirty = !!form.formState.dirtyFields.rate_provider
  useEffect(() => {
    if (!defaultRateProvider || rateProvider || rateProviderDirty) return

    form.setValue('rate_provider', defaultRateProvider)
  }, [defaultRateProvider, rateProvider, rateProviderDirty, form])

  // Picking a carrier answers what to call the method — the merchant would
  // type the carrier's name anyway. Only ever fills a blank name, so an
  // existing method and a merchant who has typed one are left alone.
  const nameDirty = !!form.formState.dirtyFields.name
  const carrierName = (rateProviders?.data ?? []).find(
    (provider) => provider.type === rateProvider && provider.uses_calculator === false,
  )?.name
  useEffect(() => {
    if (!carrierName || nameDirty || form.getValues('name')) return

    form.setValue('name', carrierName)
  }, [carrierName, nameDirty, form])

  return (
    <FormSection>
      <ProviderSelectField
        form={form}
        name="fulfillment_provider"
        label={t('admin.fields.delivery_method.fulfillment_provider.label')}
        help={t('admin.fields.delivery_method.fulfillment_provider.help')}
        options={providerOptions}
      />

      {/* A carrier can only quote a shipment it can address, so a pickup or
            digital method has no rate provider to choose between. */}
      {shipsToAddress && (
        <ProviderSelectField
          form={form}
          name="rate_provider"
          label={t('admin.fields.delivery_method.rate_provider.label')}
          help={t('admin.fields.delivery_method.rate_provider.help')}
          options={rateProviderOptions}
        />
      )}

      {connectableIntegrations.map((integrationType) => (
        <div
          key={integrationType.type}
          className="flex items-center justify-between gap-3 rounded-md border border-dashed p-3"
        >
          <span className="text-sm text-muted-foreground">
            {t('admin.delivery_methods.connect_provider_hint', { name: integrationType.name })}
          </span>
          <Can I="create" a={Subject.Integration}>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => setConnectingType(integrationType)}
            >
              {t('admin.integrations.connect_cta')}
            </Button>
          </Can>
        </div>
      ))}

      {connectingType && (
        <ConfigureIntegrationSheet
          type={connectingType}
          open
          onOpenChange={(next) => {
            if (next) return
            setJustConnected(connectingType.type)
            setConnectingType(null)
            // Provider lists are cached for half an hour — a fresh connect
            // must surface the provider in both selects immediately.
            queryClient.invalidateQueries({ queryKey: rateProvidersKey })
            queryClient.invalidateQueries({ queryKey: fulfillmentProvidersKey })
            queryClient.invalidateQueries({ queryKey: integrationsKey })
          }}
        />
      )}
    </FormSection>
  )
}

/** The rate provider currently chosen, resolved through the store default. */
function useSelectedRateProvider(
  form: UseFormReturn<DeliveryMethodFormValues>,
): DeliveryRateProviderOption | undefined {
  const { data: rateProviders } = useDeliveryRateProviders()
  const rateProvider = form.watch('rate_provider')
  const defaultRateProvider = rateProviders?.default ?? ''

  // Matched on type alone: a saved method keeps its provider even while the
  // integration is disconnected, and reading that as "no provider" would show
  // the method as calculator-priced and offer pricing that never applies.
  return useMemo(
    () =>
      (rateProviders?.data ?? []).find(
        (provider) => provider.type === (rateProvider || defaultRateProvider),
      ),
    [rateProviders, rateProvider, defaultRateProvider],
  )
}

// ---------------------------------------------------------------------------
// Carrier services — which of the provider's services this method offers,
// with per-service label + markup overrides. No rows = everything the carrier
// returns, named by the carrier.
// ---------------------------------------------------------------------------

function CarrierServicesCard({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const selectedRateProvider = useSelectedRateProvider(form)
  const servicesArray = useFieldArray({ control: form.control, name: 'services', keyName: '_key' })
  const rows = form.watch('services') ?? []
  const [editingIndex, setEditingIndex] = useState<number | null>(null)

  const catalog = selectedRateProvider?.service_catalog ?? []
  const catalogError = selectedRateProvider?.service_catalog_error ?? null
  // Only a provider that quotes its own rates has services to narrow; a
  // calculator-priced method has a single price and no service list.
  const carrierPriced = selectedRateProvider?.uses_calculator === false

  // "Choose specific services" is what having rows means, so the radio reads
  // the rows rather than carrying its own state — a saved method reopens on
  // the branch it was left in.
  const [scope, setScope] = useState<'all' | 'selected'>(rows.length > 0 ? 'selected' : 'all')
  useEffect(() => {
    if (rows.length > 0) setScope('selected')
  }, [rows.length])

  if (!carrierPriced) return null

  const rowIndex = (entry: DeliveryRateProviderCatalogEntry) =>
    rows.findIndex((row) => row.carrier === entry.carrier && row.service === entry.service)

  const toggleEntry = (entry: DeliveryRateProviderCatalogEntry, next: boolean) => {
    const index = rowIndex(entry)
    if (next && index === -1) {
      servicesArray.append({
        carrier: entry.carrier,
        service: entry.service,
        label: '',
        markup_flat: '',
        markup_percent: '',
      })
    } else if (!next && index >= 0) {
      servicesArray.remove(index)
    }
  }

  return (
    <FormSection title={t('admin.delivery_methods.carrier_services.label')}>
      {catalogError && (
        <p className="rounded-md bg-muted p-2 text-xs text-muted-foreground">
          {t('admin.delivery_methods.carrier_services.catalog_unavailable', {
            message: catalogError,
          })}
        </p>
      )}

      <RadioGroup
        value={scope}
        onValueChange={(next) => {
          const value = next as 'all' | 'selected'
          setScope(value)
          // Offering everything is the absence of rows, so switching back
          // clears them rather than leaving a hidden narrowing behind.
          if (value === 'all') form.setValue('services', [], { shouldDirty: true })
        }}
      >
        <label htmlFor="services-all" className="flex items-center gap-2 text-sm">
          <RadioGroupItem id="services-all" value="all" />
          {t('admin.delivery_methods.carrier_services.offer_all')}
        </label>
        <label htmlFor="services-selected" className="flex items-center gap-2 text-sm">
          <RadioGroupItem id="services-selected" value="selected" />
          {t('admin.delivery_methods.carrier_services.choose_specific')}
        </label>
      </RadioGroup>

      <span className="text-muted-foreground text-xs">
        {scope === 'all'
          ? t('admin.delivery_methods.carrier_services.all_hint')
          : t('admin.delivery_methods.carrier_services.narrowed_hint', { count: rows.length })}
      </span>

      {scope === 'selected' &&
        (catalog.length > 0 ? (
          <div className="flex flex-col gap-1">
            {catalog.map((entry) => {
              const index = rowIndex(entry)
              const checked = index >= 0
              const key = `${entry.carrier}/${entry.service}`
              return (
                <div key={key} className="flex items-center justify-between gap-2 py-1">
                  <label htmlFor={`service-${key}`} className="flex items-center gap-2 text-sm">
                    <Checkbox
                      id={`service-${key}`}
                      checked={checked}
                      onCheckedChange={(next) => toggleEntry(entry, !!next)}
                    />
                    {entry.label}
                  </label>
                  {checked && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="icon-sm"
                      aria-label={t('admin.delivery_methods.carrier_services.edit_service', {
                        service: entry.label,
                      })}
                      onClick={() => setEditingIndex(index)}
                    >
                      <PencilIcon className="size-4" />
                    </Button>
                  )}
                </div>
              )
            })}
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            {servicesArray.fields.map((row, index) => (
              <div key={row._key} className="grid grid-cols-[1fr_1fr_1fr_auto] gap-2">
                <Input
                  aria-label={t('admin.delivery_methods.carrier_services.carrier')}
                  placeholder={t('admin.delivery_methods.carrier_services.carrier')}
                  {...form.register(`services.${index}.carrier`)}
                />
                <Input
                  aria-label={t('admin.delivery_methods.carrier_services.service')}
                  placeholder={t('admin.delivery_methods.carrier_services.service')}
                  {...form.register(`services.${index}.service`)}
                />
                <Input
                  aria-label={t('admin.fields.delivery_method.service_label.label')}
                  placeholder={t('admin.fields.delivery_method.service_label.label')}
                  {...form.register(`services.${index}.label`)}
                />
                <Button
                  type="button"
                  variant="ghost"
                  size="icon-sm"
                  aria-label={t('admin.actions.remove')}
                  onClick={() => servicesArray.remove(index)}
                >
                  <Trash2Icon className="size-4" />
                </Button>
              </div>
            ))}
            <Button
              type="button"
              variant="outline"
              size="sm"
              className="self-start"
              onClick={() =>
                servicesArray.append({
                  carrier: '',
                  service: '',
                  label: '',
                  markup_flat: '',
                  markup_percent: '',
                })
              }
            >
              <PlusIcon className="size-4" />
              {t('admin.delivery_methods.carrier_services.add_service')}
            </Button>
          </div>
        ))}

      {editingIndex !== null && (
        <ServiceOverridesSheet
          form={form}
          index={editingIndex}
          label={
            catalog.find(
              (entry) =>
                entry.carrier === rows[editingIndex]?.carrier &&
                entry.service === rows[editingIndex]?.service,
            )?.label ?? rows[editingIndex]?.service
          }
          onClose={() => setEditingIndex(null)}
        />
      )}
    </FormSection>
  )
}

/** Label + markup overrides for one chosen carrier service. */
function ServiceOverridesSheet({
  form,
  index,
  label,
  onClose,
}: {
  form: UseFormReturn<DeliveryMethodFormValues>
  index: number
  label?: string
  onClose: () => void
}) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)

  return (
    <Sheet open onOpenChange={(open) => !open && onClose()}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {t('admin.delivery_methods.carrier_services.edit_service', { service: label ?? '' })}
          </SheetTitle>
        </SheetHeader>
        <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
          <Field>
            <FieldLabel htmlFor={`service-label-${index}`}>
              {t('admin.fields.delivery_method.service_label.label')}
            </FieldLabel>
            <Input
              id={`service-label-${index}`}
              placeholder={label}
              {...form.register(`services.${index}.label`)}
            />
          </Field>
          <Field>
            <FieldLabel htmlFor={`service-markup-flat-${index}`}>
              {t('admin.fields.delivery_method.markup_flat.label')}
            </FieldLabel>
            <InputGroup>
              <InputGroupAddon>
                <InputGroupText>{currencySymbol}</InputGroupText>
              </InputGroupAddon>
              <InputGroupInput
                id={`service-markup-flat-${index}`}
                type="number"
                step="0.01"
                min="0"
                placeholder="0"
                {...form.register(`services.${index}.markup_flat`)}
              />
            </InputGroup>
          </Field>
          <Field>
            <FieldLabel htmlFor={`service-markup-percent-${index}`}>
              {t('admin.fields.delivery_method.markup_percent.label')}
            </FieldLabel>
            <InputGroup>
              <InputGroupInput
                id={`service-markup-percent-${index}`}
                type="number"
                step="0.01"
                min="0"
                placeholder="0"
                {...form.register(`services.${index}.markup_percent`)}
              />
              <InputGroupAddon align="inline-end">
                <InputGroupText>%</InputGroupText>
              </InputGroupAddon>
            </InputGroup>
          </Field>
        </div>
        <SheetFooter>
          <Button type="button" onClick={onClose}>
            {t('admin.actions.done')}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}

// ---------------------------------------------------------------------------
// Pricing — the calculator for internally priced methods, markups for
// carrier-quoted ones
// ---------------------------------------------------------------------------

/**
 * The amount an amount-based calculator charges, one input per currency the
 * store sells in. Each row shows the amount for that currency — the
 * per-currency `amounts` hash, or the pre-6.0 single `amount` when its
 * `currency` preference names this row. A currency left blank has no
 * amount, and the method is simply not offered to those carts.
 *
 * A single-currency store sees one plain amount field, exactly as before.
 */
function CurrencyAmountsField({
  values,
  onChange,
}: {
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
}) {
  const { t } = useTranslation()
  const { currencies, defaultCurrency } = useStore()

  // The store's currency list is the source of truth, but a method may already
  // carry an amount in a currency the store has since stopped selling in —
  // dropping that input would silently discard the amount on the next save.
  const amounts = (values.amounts ?? {}) as Record<string, unknown>
  const extraCodes = Object.keys(amounts).join(',')
  const codes = useMemo(() => {
    const supported = currencies.length > 0 ? currencies : [defaultCurrency]
    const extra = extraCodes.split(',').filter((code) => code && !supported.includes(code))
    return [defaultCurrency, ...supported.filter((code) => code !== defaultCurrency), ...extra]
  }, [currencies, defaultCurrency, extraCodes])

  const multiCurrency = codes.length > 1

  function amountFor(code: string): string {
    const raw = amountForCurrency(values, code, defaultCurrency)
    return raw === null ? '' : String(raw)
  }

  function setAmount(code: string, raw: string) {
    onChange(applyCurrencyAmount(values, code, raw, defaultCurrency))
  }

  return (
    <Field>
      <FieldLabel htmlFor={`calculator-amount-${defaultCurrency}`}>
        {t('admin.preferences.amount')}
      </FieldLabel>
      <div className="flex flex-col gap-2">
        {codes.map((code) => (
          <InputGroup key={code}>
            <InputGroupAddon>
              <InputGroupText>{currencyParts(code, i18n.language).symbol}</InputGroupText>
            </InputGroupAddon>
            <InputGroupInput
              id={`calculator-amount-${code}`}
              type="number"
              step="any"
              min="0"
              aria-label={t('admin.delivery_methods.pricing.amount_in_currency', {
                currency: code,
              })}
              value={amountFor(code)}
              onChange={(event) => setAmount(code, event.target.value)}
            />
            <InputGroupAddon align="inline-end">
              <InputGroupText>{code}</InputGroupText>
            </InputGroupAddon>
          </InputGroup>
        ))}
      </div>
      {multiCurrency && (
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_methods.pricing.currency_amounts_help')}
        </span>
      )}
    </Field>
  )
}

function PricingCard({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { defaultCurrency } = useStore()
  const { symbol: currencySymbol } = currencyParts(defaultCurrency, i18n.language)
  const { data: calculators } = useDeliveryCalculators()
  const { data: taxCategories } = useTaxCategories()
  const selectedRateProvider = useSelectedRateProvider(form)
  const calculatorType = form.watch('calculator_type')

  // Carrier providers quote live rates, so the calculator's amount is never
  // read — the field is hidden rather than offering pricing that does nothing.
  // (The record still carries a calculator: the Estimator consults its
  // `available?`, which the API fills in with a free-rate default.)
  const usesCalculator = selectedRateProvider?.uses_calculator ?? true

  const calculatorOptions = (calculators?.data ?? []).map((calculator) => ({
    value: calculator.type,
    label: calculator.name,
  }))
  const selectedCalculator = (calculators?.data ?? []).find((c) => c.type === calculatorType)
  const preferenceSchema = (selectedCalculator?.preference_schema ?? []) as PreferenceField[]

  // An amount-based calculator prices per currency, so its amount fields are
  // rendered by the editor below rather than one-by-one from the schema. The
  // rest of its preferences (weight and total bounds) still render generically.
  const amountBased = AMOUNT_BASED_CALCULATORS.includes(calculatorType ?? '')
  const genericSchema = amountBased
    ? preferenceSchema.filter((field) => !CURRENCY_AMOUNT_KEYS.includes(field.key))
    : preferenceSchema

  const taxCategoryOptions = [
    { value: '', label: t('admin.common.none') },
    ...(taxCategories?.data ?? []).map((tc) => ({ value: tc.id, label: tc.name })),
  ]

  return (
    <FormSection>
      {usesCalculator ? (
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
              <>
                {amountBased && (
                  <CurrencyAmountsField
                    values={(field.value ?? {}) as Record<string, unknown>}
                    onChange={field.onChange}
                  />
                )}
                <PreferencesForm
                  schema={genericSchema}
                  values={(field.value ?? {}) as Record<string, unknown>}
                  onChange={field.onChange}
                />
              </>
            )}
          />
        </>
      ) : (
        <>
          <div className="grid grid-cols-2 gap-3">
            <Field>
              <FieldLabel htmlFor="markup_percent">
                {t('admin.fields.delivery_method.markup_percent.label')}
              </FieldLabel>
              <InputGroup>
                <InputGroupInput
                  id="markup_percent"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0"
                  {...form.register('markup_percent')}
                />
                <InputGroupAddon align="inline-end">
                  <InputGroupText>%</InputGroupText>
                </InputGroupAddon>
              </InputGroup>
            </Field>
            <Field>
              <FieldLabel htmlFor="markup_flat">
                {t('admin.fields.delivery_method.markup_flat.label')}
              </FieldLabel>
              <InputGroup>
                <InputGroupAddon>
                  <InputGroupText>{currencySymbol}</InputGroupText>
                </InputGroupAddon>
                <InputGroupInput
                  id="markup_flat"
                  type="number"
                  step="0.01"
                  min="0"
                  placeholder="0"
                  {...form.register('markup_flat')}
                />
              </InputGroup>
            </Field>
          </div>
          <span className="text-xs text-muted-foreground">
            {t('admin.fields.delivery_method.markup_percent.help')}
          </span>
        </>
      )}

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
    </FormSection>
  )
}

// ---------------------------------------------------------------------------
// Zone — which of the profile's zones this method serves
// ---------------------------------------------------------------------------

function ZoneCard({
  form,
  zones,
}: {
  form: UseFormReturn<DeliveryMethodFormValues>
  zones: DeliveryZone[]
}) {
  const { t } = useTranslation()

  const zoneOptions = [
    { value: '', label: t('admin.delivery_methods.no_zone_restriction') },
    ...zones.map((zone) => ({ value: zone.id, label: zone.name })),
  ]

  return (
    <FormSection>
      <Field>
        <FieldLabel>{t('admin.fields.delivery_method.delivery_zone.label')}</FieldLabel>
        <Controller
          name="delivery_zone_id"
          control={form.control}
          render={({ field }) => (
            <Select items={zoneOptions} value={field.value} onValueChange={field.onChange}>
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {zoneOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        <span className="text-muted-foreground text-xs">
          {t('admin.fields.delivery_method.delivery_zone.help')}
        </span>
      </Field>
    </FormSection>
  )
}

// ---------------------------------------------------------------------------
// Conditions (eligibility rules) — held in form state, saved with the page
// ---------------------------------------------------------------------------

function ConditionsCard({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { data: ruleTypes } = useDeliveryMethodRuleTypes()
  const rulesArray = useFieldArray({ control: form.control, name: 'rules', keyName: '_key' })

  const existingTypes = new Set(rulesArray.fields.map((rule) => rule.type))
  const availableTypes = (ruleTypes?.data ?? []).filter((type) => !existingTypes.has(type.type))

  return (
    <FormSection
      title={t('admin.delivery_methods.conditions.title')}
      action={
        availableTypes.length > 0 && (
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
        )
      }
    >
      <div className="flex flex-col gap-3">
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
    </FormSection>
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
  // Rules naming other records get a picker; every other kind renders its
  // preference schema. Driven by the discovery endpoint, so a plugin rule with
  // the same shape works without a change here.
  const productBacked = ruleType?.association_fields?.includes('product_ids') ?? false
  // Channel ids ride in preferences rather than an association field, but a
  // bare id array is unusable as a text input — it needs the same picker.
  const channelBacked = (ruleType?.preference_schema ?? []).some(
    (preference) => preference.key === 'channel_ids',
  )
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
      ) : channelBacked ? (
        <Controller
          control={form.control}
          name={`rules.${index}.preferences`}
          render={({ field }) => (
            <ResourceMultiAutocomplete<Channel>
              {...channelAutocompleteProps('delivery-method-rule-channels')}
              value={(field.value?.channel_ids ?? []) as string[]}
              onChange={(channelIds) => field.onChange({ ...field.value, channel_ids: channelIds })}
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
