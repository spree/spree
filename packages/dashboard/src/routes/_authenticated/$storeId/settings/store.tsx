import { zodResolver } from '@hookform/resolvers/zod'
import { SpreeError, type Store } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader, useSwitchAdminLocale } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  ErrorState,
  Field,
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
import { useEffect, useMemo } from 'react'
import {
  type Control,
  Controller,
  type FieldPath,
  type FieldValues,
  useForm,
} from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useStoreSettings, useUpdateStoreSettings } from '@/hooks/use-store-settings'
import { getAvailableUiLocales } from '@/i18n-setup'
import {
  type StoreSettingsFormValues,
  storeSettingsFormSchema,
  UNIT_SYSTEMS,
  WEIGHT_UNITS,
} from '@/schemas/store'

export const Route = createFileRoute('/_authenticated/$storeId/settings/store')({
  component: StoreSettingsPage,
})

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
  const updateMutation = useUpdateStoreSettings()
  const switchAdminLocale = useSwitchAdminLocale()

  const form = useForm<StoreSettingsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(storeSettingsFormSchema) as any,
    defaultValues: storeToFormValues(store),
  })

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
    try {
      await updateMutation.mutateAsync({
        name: values.name,
        preferred_admin_locale: values.preferred_admin_locale || undefined,
        preferred_timezone: values.preferred_timezone,
        preferred_unit_system: values.preferred_unit_system,
        preferred_weight_unit: values.preferred_weight_unit,
      })
      toast.success(t('admin.messages.store_settings_updated'))
      // Reset FIRST so the form is no longer dirty — otherwise the language
      // switch below reloads the page while the `beforeunload` dirty-guard is
      // still armed, triggering the browser's "unsaved changes" prompt.
      form.reset(values)
      // Setting the store's admin language adopts it as this admin's own UI
      // language and switches the dashboard into it immediately (same as the
      // profile picker / top-bar). A blank value ("use the default") is not an
      // active choice, so it doesn't force a switch.
      const code = values.preferred_admin_locale
      if (code) await switchAdminLocale(code)
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_update_store'))
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
          </>
        }
      />
    </form>
  )
}

interface SelectFieldProps<TValues extends FieldValues> {
  id: string
  label: string
  placeholder?: string
  name: FieldPath<TValues>
  control: Control<TValues>
  options: ReadonlyArray<{ value: string; label: string }>
}

function SelectField<TValues extends FieldValues>({
  id,
  label,
  placeholder,
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
          <FieldError errors={[fieldState.error]} />
        </Field>
      )}
    />
  )
}
