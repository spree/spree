import { zodResolver } from '@hookform/resolvers/zod'
import {
  InventoryCard,
  mapSpreeErrorsToForm,
  PageHeader,
  PricesCard,
  VariantAvailabilityFields,
  VariantCustomsFields,
  VariantFieldSection,
  VariantIdentityFields,
  VariantOrderingFields,
  VariantShippingFields,
} from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldLabel,
  FormActions,
  ResourceLayout,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusBadge,
  toastManager,
} from '@spree/dashboard-ui'
import type { OfferParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams, useSearch } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { OfferStatusCard } from '../components/offer-status-card'
import { RetryableError } from '../components/retryable-error'
import { newOfferFormDefaults, type OfferFormValues, offerFormSchema } from '../schemas/offer'

/**
 * The plain fields an offer carries, named once.
 *
 * Both directions read this list — loading a saved offer into the form and
 * building the payload back — so a field added to the shared variant sections
 * is added here once rather than in three places, which is how the two halves
 * drifted apart before.
 *
 * The shaped fields are deliberately absent: options, prices and stock levels
 * each need their own reconciliation, and the two booleans need a default.
 */
const OFFER_FIELDS = [
  'sku',
  'barcode',
  'cost_price',
  'weight',
  'height',
  'width',
  'depth',
  'weight_unit',
  'dimensions_unit',
  'hs_code',
  'country_of_origin',
  'customs_description',
  'minimum_order_quantity',
  'order_multiple',
  'purchase_unit',
  'units_per_carton',
  'preorder_ships_at',
  'backorder_limit',
  'delivery_profile_id',
] as const

/** Copies the plain fields across, turning every empty value into `undefined`. */
function pickOfferFields(source: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(OFFER_FIELDS.map((field) => [field, source[field] ?? undefined]))
}

/** Everything the offer form edits, in one request. */
const OFFER_EXPAND = 'prices,stock_levels,product,submission,option_values'

/**
 * One offer, listed or edited.
 *
 * The variant fields are the operator dashboard's, rendered from the shared
 * sections in `@spree/dashboard-core` — the two surfaces are one definition,
 * so a field added there appears here without anybody remembering to
 * (docs/plans/6.0-seller-master-catalog-listings.md, Decision 11).
 *
 * What is missing compared to a product is the point: the name, description
 * and images belong to the marketplace's listing, and a seller sets a price,
 * a condition and what is on their shelf.
 */
export function OfferPage({ mode }: { mode: 'new' | 'edit' }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const params = useParams({ strict: false }) as { variantId?: string }
  const search = useSearch({ strict: false }) as { product?: string }
  const variantId = mode === 'edit' ? params.variantId : undefined
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const offerKey = ['seller', sellerId, 'offer', variantId]
  const {
    data: offer,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: offerKey,
    queryFn: () => sellerClient().variants.get(variantId as string, OFFER_EXPAND),
    enabled: !!variantId,
  })

  // On a new offer the product comes from the picker; on an existing one it
  // is whatever the offer already sits on.
  const masterProductId = offer?.product_id ?? search.product
  const { data: master } = useQuery({
    queryKey: ['seller', sellerId, 'master-product', masterProductId],
    // Dotted: a bare `option_types` expand hands the child serializer an
    // empty expand list, so its own `option_values` association never fires
    // and every axis renders an empty picker.
    queryFn: () =>
      sellerClient().masterProducts.get(masterProductId as string, 'option_types.option_values'),
    enabled: !!masterProductId,
  })

  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })

  const { data: profiles } = useQuery({
    queryKey: ['seller', sellerId, 'delivery-profiles'],
    queryFn: () => sellerClient().deliveryProfiles.list(),
  })

  const form = useForm<OfferFormValues>({
    resolver: zodResolver(offerFormSchema) as never,
    defaultValues: newOfferFormDefaults(),
  })

  // Seed one price row per currency the store trades in, and one option row
  // per axis the master product is sold by — an offer must name a value for
  // every one of them, so the form asks for all of them up front.
  useEffect(() => {
    if (form.formState.isDirty) return

    const axes = master?.option_types ?? []
    const currencies = profile?.supported_currencies ?? []

    if (offer) {
      form.reset({
        variants: [
          {
            ...pickOfferFields(offer),
            track_inventory: offer.track_inventory ?? true,
            preorderable: offer.preorderable ?? false,
            options: axes.map((axis) => ({
              name: axis.name,
              value:
                offer.option_values?.find((value) => value.option_type_name === axis.name)?.name ??
                '',
            })),
            // Every currency the store trades in, so the spreadsheet has a
            // column per currency rather than only the ones already priced.
            prices: currencies.map((currency) => ({
              currency,
              amount: offer.prices?.find((price) => price.currency === currency)?.amount ?? '',
            })),
            stock_levels: (offer.stock_levels ?? []).flatMap((level) =>
              level.stock_location_id
                ? [
                    {
                      id: level.id,
                      stock_location_id: level.stock_location_id,
                      count_on_hand: level.count_on_hand ?? 0,
                      // The grid renders a backorder toggle per warehouse, so
                      // dropping this would blank a seller's setting on load
                      // and again on save.
                      backorderable: level.backorderable ?? false,
                    },
                  ]
                : [],
            ),
          },
        ],
      } as OfferFormValues)
      return
    }

    if (axes.length || currencies.length) {
      form.reset({
        variants: [
          {
            ...newOfferFormDefaults().variants[0],
            options: axes.map((axis) => ({ name: axis.name, value: '' })),
            prices: currencies.map((currency) => ({ currency, amount: '' })),
          },
        ],
      } as OfferFormValues)
    }
  }, [offer, master, profile, form])

  const save = useMutation({
    mutationFn: (values: OfferFormValues) => {
      const row = values.variants[0]
      const payload: OfferParams = {
        ...pickOfferFields(row),
        track_inventory: row.track_inventory,
        preorderable: row.preorderable,
        options: (row.options ?? []).filter((option) => option.value),
        // Only the currencies actually priced: `prices` is a full
        // replacement, and an empty amount would clear a price rather than
        // leave it alone.
        prices: (row.prices ?? []).flatMap((price) =>
          price.amount === '' || price.amount == null
            ? []
            : [{ currency: price.currency, amount: price.amount }],
        ),
        // The spreadsheet writes a row per warehouse it shows, including
        // untouched ones, so a blank count means "nothing here" rather than
        // an instruction to skip the shelf.
        stock_levels: (row.stock_levels ?? []).flatMap((level) =>
          level.stock_location_id
            ? [
                {
                  id: level.id,
                  stock_location_id: level.stock_location_id,
                  count_on_hand: level.count_on_hand ?? 0,
                  backorderable: level.backorderable ?? false,
                },
              ]
            : [],
        ),
      }

      return variantId
        ? sellerClient().variants.update(variantId, payload)
        : sellerClient().variants.create(masterProductId as string, payload)
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ['seller-offers'] })
      void queryClient.invalidateQueries({ queryKey: ['seller', sellerId, 'offer', saved.id] })
      toastManager.add({ type: 'success', title: t('offers.saved') })

      if (!variantId) {
        navigate({
          to: '/$sellerId/offers/$variantId',
          params: { sellerId, variantId: saved.id },
          replace: true,
        })
      }
    },
  })

  async function onSubmit(values: OfferFormValues) {
    try {
      await save.mutateAsync(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        toastManager.add({
          type: 'error',
          title: err instanceof Error ? err.message : t('common.error'),
        })
      }
    }
  }

  if (mode === 'edit' && isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (mode === 'edit' && isError) return <RetryableError onRetry={() => refetch()} />
  if (mode === 'edit' && !offer) return <CenteredMessage>{t('offers.not_found')}</CenteredMessage>
  if (mode === 'new' && !masterProductId)
    return <CenteredMessage>{t('offers.pick_a_product_first')}</CenteredMessage>

  const axes = master?.option_types ?? []

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        {form.formState.errors.root?.message && (
          <p className="text-destructive text-sm" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <ResourceLayout
          header={
            <PageHeader
              title={master?.name ?? t('offers.new_title')}
              backTo="offers"
              badges={
                offer?.status ? (
                  <StatusBadge status={offer.status} label={t(`offers.statuses.${offer.status}`)} />
                ) : undefined
              }
              actions={<FormActions form={form} saveLabel={t('common.save')} />}
            />
          }
          main={
            <>
              {/* Every axis the marketplace sells this product by, each
                  chosen from the values it already carries — a seller files
                  into the marketplace's vocabulary rather than extending it. */}
              {axes.length > 0 && (
                <Card>
                  <CardHeader>
                    <CardTitle>{t('offers.options_title')}</CardTitle>
                  </CardHeader>
                  <CardContent className="flex flex-col gap-3">
                    {axes.map((axis, index) => (
                      <Field key={axis.id}>
                        <FieldLabel htmlFor={`offer-option-${axis.name}`}>{axis.label}</FieldLabel>
                        <Controller
                          name={`variants.0.options.${index}.value`}
                          control={form.control}
                          render={({ field }) => {
                            const items = (axis.option_values ?? []).map((optionValue) => ({
                              value: optionValue.name,
                              label: optionValue.label,
                            }))

                            return (
                              <Select
                                items={items}
                                value={field.value ?? ''}
                                onValueChange={field.onChange}
                              >
                                <SelectTrigger id={`offer-option-${axis.name}`}>
                                  <SelectValue />
                                </SelectTrigger>
                                <SelectContent>
                                  {items.map((item) => (
                                    <SelectItem key={item.value} value={item.value}>
                                      {item.label}
                                    </SelectItem>
                                  ))}
                                </SelectContent>
                              </Select>
                            )
                          }}
                        />
                        <FieldError
                          errors={[form.formState.errors.variants?.[0]?.options?.[index]?.value]}
                        />
                      </Field>
                    ))}
                  </CardContent>
                </Card>
              )}

              {/* The operator's own price spreadsheet, bound to this offer's
                  single row — one definition for both panels. */}
              <PricesCard
                form={form}
                productName={master?.name ?? ''}
                currencies={profile?.supported_currencies}
                defaultCurrency={profile?.default_currency}
              />

              <Card>
                <CardHeader>
                  <CardTitle>{t('offers.details_title')}</CardTitle>
                </CardHeader>
                <CardContent className="flex flex-col gap-6">
                  <VariantFieldSection title={t('admin.products.variants.sheet.identity')}>
                    <VariantIdentityFields
                      form={form}
                      prefix="variants.0"
                      errors={form.formState.errors.variants?.[0]}
                    />
                  </VariantFieldSection>

                  <VariantFieldSection title={t('admin.products.variants.sheet.availability')}>
                    <VariantAvailabilityFields
                      form={form}
                      prefix="variants.0"
                      errors={form.formState.errors.variants?.[0]}
                    />
                  </VariantFieldSection>

                  <VariantFieldSection title={t('admin.fields.shipping.label')}>
                    <VariantShippingFields
                      form={form}
                      prefix="variants.0"
                      errors={form.formState.errors.variants?.[0]}
                    />
                  </VariantFieldSection>

                  <VariantFieldSection title={t('admin.products.variants.sheet.customs')}>
                    <VariantCustomsFields
                      form={form}
                      prefix="variants.0"
                      errors={form.formState.errors.variants?.[0]}
                    />
                  </VariantFieldSection>

                  <VariantFieldSection title={t('admin.products.variants.sheet.ordering')}>
                    <VariantOrderingFields
                      form={form}
                      prefix="variants.0"
                      errors={form.formState.errors.variants?.[0]}
                    />
                  </VariantFieldSection>
                </CardContent>
              </Card>

              {/* The same inventory grid the operator edits. It lists this
                  seller's warehouses, because the panel registers the seller
                  client as its stock-locations resource. */}
              <InventoryCard form={form} />
            </>
          }
          sidebar={
            <>
              {variantId && offer && (
                <OfferStatusCard
                  offer={offer}
                  onDone={() => {
                    void queryClient.invalidateQueries({ queryKey: offerKey })
                    void queryClient.invalidateQueries({ queryKey: ['seller-offers'] })
                  }}
                />
              )}

              {/* The marketplace's listing, so a seller can see what they are
                  competing on without leaving the form. */}
              {master && (
                <Card>
                  <CardHeader>
                    <CardTitle>{t('offers.product_title')}</CardTitle>
                  </CardHeader>
                  <CardContent className="flex flex-col gap-2">
                    <span className="font-medium">{master.name}</span>
                    {master.price?.display_amount && (
                      <span className="text-muted-foreground text-sm">
                        {t('offers.marketplace_price', { price: master.price.display_amount })}
                      </span>
                    )}
                  </CardContent>
                </Card>
              )}

              <Card>
                <CardHeader>
                  <CardTitle>{t('offers.delivery_title')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <Field>
                    <FieldLabel htmlFor="offer-delivery-profile">
                      {t('offers.fields.delivery_profile')}
                    </FieldLabel>
                    <Controller
                      name="variants.0.delivery_profile_id"
                      control={form.control}
                      render={({ field }) => {
                        const items = (profiles?.data ?? []).map((deliveryProfile) => ({
                          value: deliveryProfile.id,
                          label: deliveryProfile.name,
                        }))

                        return (
                          <Select
                            items={items}
                            value={(field.value as string) ?? ''}
                            onValueChange={field.onChange}
                          >
                            <SelectTrigger id="offer-delivery-profile">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {items.map((item) => (
                                <SelectItem key={item.value} value={item.value}>
                                  {item.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                        )
                      }}
                    />
                    <span className="text-muted-foreground text-xs">
                      {t('offers.delivery_help')}
                    </span>
                  </Field>
                </CardContent>
              </Card>
            </>
          }
        />
      </form>
    </FormProvider>
  )
}
