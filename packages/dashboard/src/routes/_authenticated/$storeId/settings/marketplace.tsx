import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store } from '@spree/admin-sdk'
import { currencyParts, mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import {
  Alert,
  AlertDescription,
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
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
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
import { InfoIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, Link } from '@tanstack/react-router'
import { useMemo } from 'react'
import {
  type Control,
  Controller,
  type FieldPath,
  type FieldValues,
  FormProvider,
  useForm,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  usePayoutProviders,
  useStoreSettings,
  useUpdateStoreSettings,
} from '../../../../hooks/use-store-settings'
import {
  fractionToPercentage,
  type MarketplaceSettingsFormValues,
  marketplaceSettingsFormSchema,
  PAYOUT_SCHEDULE_INTERVALS,
  percentageToFraction,
} from '../../../../schemas/marketplace'

export const Route = createFileRoute('/_authenticated/$storeId/settings/marketplace')({
  component: MarketplaceSettingsRoute,
})

function MarketplaceSettingsRoute() {
  const { t } = useTranslation()
  const { data: store, isLoading, error, refetch } = useStoreSettings()

  if (isLoading || !store) {
    if (error) {
      return (
        <ErrorState title={t('admin.store.load_failed_title')} onRetry={() => void refetch()} />
      )
    }

    return <Skeleton className="h-64 w-full" />
  }

  return <MarketplaceSettingsPage store={store} />
}

function MarketplaceSettingsPage({ store }: { store: Store }) {
  const { t, i18n } = useTranslation()
  const { storeId } = Route.useParams()
  const updateMutation = useUpdateStoreSettings()
  const { data: payoutProviders } = usePayoutProviders()
  const { symbol: currencySymbol } = currencyParts(store.default_currency, i18n.language)

  const form = useForm<MarketplaceSettingsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(marketplaceSettingsFormSchema) as any,
    defaultValues: {
      preferred_payout_provider: store.preferred_payout_provider ?? '',
      preferred_default_payouts_schedule_interval:
        (store.preferred_default_payouts_schedule_interval as (typeof PAYOUT_SCHEDULE_INTERVALS)[number]) ??
        'monthly',
      preferred_default_minimum_payout_amount: Number(
        store.preferred_default_minimum_payout_amount ?? 0,
      ),
      preferred_auto_approve_sellers: store.preferred_auto_approve_sellers ?? false,
      preferred_auto_approve_seller_products: store.preferred_auto_approve_seller_products ?? false,
      preferred_send_seller_transactional_emails:
        store.preferred_send_seller_transactional_emails ?? true,
      commission_tax_rate_percentage: fractionToPercentage(
        store.preferred_default_commission_tax_rate,
      ),
    },
  })

  // Blank rather than a class name for the built-in provider, so a
  // marketplace that has connected nothing reads as "we settle these
  // ourselves" rather than as an engine it has to understand.
  const providerOptions = useMemo(
    () => [
      { value: '', label: t('admin.fields.store.payouts.provider_none'), disabled: false },
      ...(payoutProviders?.data ?? [])
        .filter((provider) => !provider.default)
        .map((provider) => ({
          value: provider.id,
          // An unconnected provider stays listed but unselectable, and says so
          // in its own label — a greyed-out row with nothing else on it reads
          // as broken rather than as something still to set up.
          label: provider.available
            ? provider.name
            : t('admin.fields.store.payouts.provider_needs_connection', { name: provider.name }),
          disabled: !provider.available,
        })),
    ],
    [payoutProviders, t],
  )

  // A payout provider is unavailable for exactly one reason: the payment
  // method it settles through is not active on this store. Naming the
  // providers rather than the condition keeps the prompt true if a second
  // connected provider ever ships.
  const unavailableProviders = useMemo(
    () =>
      (payoutProviders?.data ?? []).filter((provider) => !provider.default && !provider.available),
    [payoutProviders],
  )

  const scheduleOptions = useMemo(
    () =>
      PAYOUT_SCHEDULE_INTERVALS.map((interval) => ({
        value: interval,
        label: t(`admin.fields.store.payouts.schedule_intervals.${interval}`),
      })),
    [t],
  )

  const onSubmit = async (values: MarketplaceSettingsFormValues) => {
    try {
      await updateMutation.mutateAsync({
        preferred_payout_provider: values.preferred_payout_provider,
        preferred_default_payouts_schedule_interval:
          values.preferred_default_payouts_schedule_interval,
        preferred_default_minimum_payout_amount: values.preferred_default_minimum_payout_amount,
        preferred_auto_approve_sellers: values.preferred_auto_approve_sellers,
        preferred_auto_approve_seller_products: values.preferred_auto_approve_seller_products,
        preferred_send_seller_transactional_emails:
          values.preferred_send_seller_transactional_emails,
        preferred_default_commission_tax_rate: percentageToFraction(
          values.commission_tax_rate_percentage,
        ),
      })
      form.reset(values)
      toastManager.add({ type: 'success', title: t('admin.messages.store_settings_updated') })
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
      if (!(err instanceof SpreeError)) throw err
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState
  // A provider that moves money asks sellers to onboard with it first, which
  // is worth saying before the choice rather than after.
  const selectedProvider = payoutProviders?.data?.find(
    (provider) => provider.id === form.watch('preferred_payout_provider'),
  )

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <ResourceLayout
          header={
            <PageHeader
              docsPath="sellers/payouts"
              title={t('admin.pages.settings.marketplace.title')}
              description={t('admin.pages.settings.marketplace.subtitle')}
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

              {/* Money first: paying sellers is what an operator configures on
                  day one, and the rest of the page is how they join and what
                  they hear from you. */}
              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.marketplace.payouts_title')}</CardTitle>
                  <CardDescription>
                    {t('admin.pages.settings.marketplace.payouts_description')}
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <Controller
                      control={form.control}
                      name="preferred_payout_provider"
                      render={({ field }) => (
                        <Field>
                          <FieldLabel htmlFor="payout-provider">
                            {t('admin.fields.store.payouts.provider.label')}
                          </FieldLabel>
                          <Select
                            items={providerOptions}
                            value={field.value}
                            onValueChange={(value) => field.onChange(value as string)}
                          >
                            <SelectTrigger id="payout-provider">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {providerOptions.map((option) => (
                                <SelectItem
                                  key={option.value}
                                  value={option.value}
                                  disabled={option.disabled}
                                >
                                  {option.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                          <FieldDescription>
                            {selectedProvider?.requires_payout_account
                              ? t('admin.fields.store.payouts.provider.requires_account')
                              : t('admin.fields.store.payouts.provider.help')}
                          </FieldDescription>
                          {unavailableProviders.map((provider) => (
                            <Alert key={provider.id} variant="info" className="mt-1">
                              <InfoIcon />
                              <AlertDescription>
                                {t('admin.fields.store.payouts.provider_connect_hint', {
                                  name: provider.name,
                                })}{' '}
                                <Link to="/$storeId/settings/payment-methods" params={{ storeId }}>
                                  {t('admin.fields.store.payouts.provider_connect_link')}
                                </Link>
                              </AlertDescription>
                            </Alert>
                          ))}
                          <FieldError errors={[errors.preferred_payout_provider]} />
                        </Field>
                      )}
                    />

                    <Controller
                      control={form.control}
                      name="preferred_default_payouts_schedule_interval"
                      render={({ field }) => (
                        <Field>
                          <FieldLabel htmlFor="payout-schedule">
                            {t('admin.fields.store.payouts.schedule.label')}
                          </FieldLabel>
                          <Select
                            items={scheduleOptions}
                            value={field.value}
                            onValueChange={(value) => field.onChange(value as string)}
                          >
                            <SelectTrigger id="payout-schedule">
                              <SelectValue />
                            </SelectTrigger>
                            <SelectContent>
                              {scheduleOptions.map((option) => (
                                <SelectItem key={option.value} value={option.value}>
                                  {option.label}
                                </SelectItem>
                              ))}
                            </SelectContent>
                          </Select>
                          <FieldDescription>
                            {t('admin.fields.store.payouts.schedule.help')}
                          </FieldDescription>
                          <FieldError
                            errors={[errors.preferred_default_payouts_schedule_interval]}
                          />
                        </Field>
                      )}
                    />

                    <Field>
                      <FieldLabel htmlFor="payout-minimum">
                        {t('admin.fields.store.payouts.minimum.label')}
                      </FieldLabel>
                      <InputGroup>
                        <InputGroupAddon align="inline-start">
                          <InputGroupText>{currencySymbol}</InputGroupText>
                        </InputGroupAddon>
                        <InputGroupInput
                          id="payout-minimum"
                          type="number"
                          min={0}
                          step="0.01"
                          inputMode="decimal"
                          aria-invalid={
                            !!errors.preferred_default_minimum_payout_amount || undefined
                          }
                          {...form.register('preferred_default_minimum_payout_amount')}
                        />
                      </InputGroup>
                      <FieldDescription>
                        {t('admin.fields.store.payouts.minimum.help')}
                      </FieldDescription>
                      <FieldError errors={[errors.preferred_default_minimum_payout_amount]} />
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.marketplace.admission_title')}</CardTitle>
                  <CardDescription>
                    {t('admin.pages.settings.marketplace.admission_description')}
                  </CardDescription>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SwitchField
                      id="marketplace-auto-approve-sellers"
                      label={t('admin.fields.store.auto_approve_sellers.label')}
                      help={t('admin.fields.store.auto_approve_sellers.help')}
                      name="preferred_auto_approve_sellers"
                      control={form.control}
                    />
                    <SwitchField
                      id="marketplace-auto-approve-seller-products"
                      label={t('admin.fields.store.auto_approve_seller_products.label')}
                      help={t('admin.fields.store.auto_approve_seller_products.help')}
                      name="preferred_auto_approve_seller_products"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>{t('admin.pages.settings.marketplace.communication_title')}</CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <SwitchField
                      id="marketplace-send-seller-emails"
                      label={t('admin.fields.store.send_seller_transactional_emails.label')}
                      help={t('admin.fields.store.send_seller_transactional_emails.help')}
                      name="preferred_send_seller_transactional_emails"
                      control={form.control}
                    />
                  </FieldGroup>
                </CardContent>
              </Card>

              <Card>
                <CardHeader>
                  <CardTitle>
                    {t('admin.pages.settings.marketplace.commission_tax_title')}
                  </CardTitle>
                </CardHeader>
                <CardContent>
                  <FieldGroup>
                    <Field>
                      <FieldLabel htmlFor="marketplace-commission-tax-rate">
                        {t('admin.fields.store.default_commission_tax_rate.label')}
                      </FieldLabel>
                      <InputGroup>
                        <InputGroupInput
                          id="marketplace-commission-tax-rate"
                          type="number"
                          min={0}
                          max={100}
                          step="0.01"
                          aria-invalid={!!errors.commission_tax_rate_percentage || undefined}
                          {...form.register('commission_tax_rate_percentage')}
                        />
                        <InputGroupAddon align="inline-end">
                          <InputGroupText>
                            {t('admin.fields.store.default_commission_tax_rate.suffix')}
                          </InputGroupText>
                        </InputGroupAddon>
                      </InputGroup>
                      <FieldDescription>
                        {t('admin.fields.store.default_commission_tax_rate.help')}
                      </FieldDescription>
                      <FieldError errors={[errors.commission_tax_rate_percentage]} />
                    </Field>
                  </FieldGroup>
                </CardContent>
              </Card>
            </>
          }
        />
      </form>
    </FormProvider>
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
