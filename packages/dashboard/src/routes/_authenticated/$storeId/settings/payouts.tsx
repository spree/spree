import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
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
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute } from '@tanstack/react-router'
import { useMemo } from 'react'
import { Controller, FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  usePayoutProviders,
  useStoreSettings,
  useUpdateStoreSettings,
} from '../../../../hooks/use-store-settings'
import {
  PAYOUT_SCHEDULE_INTERVALS,
  type PayoutSettingsFormValues,
  payoutSettingsFormSchema,
} from '../../../../schemas/payouts'

export const Route = createFileRoute('/_authenticated/$storeId/settings/payouts')({
  component: PayoutSettingsRoute,
})

function PayoutSettingsRoute() {
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

  return <PayoutSettingsPage store={store} />
}

function PayoutSettingsPage({ store }: { store: Store }) {
  const { t } = useTranslation()
  const updateMutation = useUpdateStoreSettings()
  const { data: payoutProviders } = usePayoutProviders()

  const form = useForm<PayoutSettingsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(payoutSettingsFormSchema) as any,
    defaultValues: {
      preferred_payout_provider: store.preferred_payout_provider ?? '',
      preferred_default_payouts_schedule_interval:
        (store.preferred_default_payouts_schedule_interval as (typeof PAYOUT_SCHEDULE_INTERVALS)[number]) ??
        'monthly',
      preferred_default_minimum_payout_amount: Number(
        store.preferred_default_minimum_payout_amount ?? 0,
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
          label: provider.name,
          disabled: !provider.available,
        })),
    ],
    [payoutProviders, t],
  )

  const scheduleOptions = useMemo(
    () =>
      PAYOUT_SCHEDULE_INTERVALS.map((interval) => ({
        value: interval,
        label: t(`admin.fields.store.payouts.schedule_intervals.${interval}`),
      })),
    [t],
  )

  const onSubmit = async (values: PayoutSettingsFormValues) => {
    try {
      await updateMutation.mutateAsync({
        preferred_payout_provider: values.preferred_payout_provider,
        preferred_default_payouts_schedule_interval:
          values.preferred_default_payouts_schedule_interval,
        preferred_default_minimum_payout_amount: values.preferred_default_minimum_payout_amount,
      })
      form.reset(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
      if (!(err instanceof SpreeError)) throw err
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const { errors } = form.formState
  // A provider that moves money asks sellers to onboard with it first, which
  // is worth saying before the choice rather than after.
  const selected = payoutProviders?.data?.find(
    (provider) => provider.id === form.watch('preferred_payout_provider'),
  )

  return (
    <FormProvider {...form}>
      <form onSubmit={form.handleSubmit(onSubmit)}>
        <ResourceLayout
          header={
            <PageHeader
              title={t('admin.pages.settings.payouts.title')}
              subtitle={t('admin.pages.settings.payouts.subtitle')}
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
                  <CardTitle>{t('admin.fields.store.payouts.title')}</CardTitle>
                  <CardDescription>{t('admin.fields.store.payouts.description')}</CardDescription>
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
                            {selected?.requires_payout_account
                              ? t('admin.fields.store.payouts.provider.requires_account')
                              : t('admin.fields.store.payouts.provider.help')}
                          </FieldDescription>
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
                      <Input
                        id="payout-minimum"
                        type="number"
                        min={0}
                        step="0.01"
                        aria-invalid={!!errors.preferred_default_minimum_payout_amount || undefined}
                        {...form.register('preferred_default_minimum_payout_amount')}
                      />
                      <FieldDescription>
                        {t('admin.fields.store.payouts.minimum.help')}
                      </FieldDescription>
                      <FieldError errors={[errors.preferred_default_minimum_payout_amount]} />
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
