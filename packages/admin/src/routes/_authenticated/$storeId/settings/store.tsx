import { zodResolver } from '@hookform/resolvers/zod'
import type { Store } from '@spree/admin-sdk'
import { createFileRoute } from '@tanstack/react-router'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { toast } from 'sonner'
import { FormActions, useFormSubmitShortcut } from '@/components/spree/form-actions'
import { PageHeader } from '@/components/spree/page-header'
import { ResourceLayout } from '@/components/spree/resource-layout'
import { ErrorState } from '@/components/spree/route-error-boundary'
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card'
import { Field, FieldGroup, FieldLabel } from '@/components/ui/field'
import { Input } from '@/components/ui/input'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { Skeleton } from '@/components/ui/skeleton'
import { useStoreSettings, useUpdateStoreSettings } from '@/hooks/use-store-settings'
import {
  ADMIN_LOCALE_OPTIONS,
  type StoreSettingsFormValues,
  storeSettingsFormSchema,
  UNIT_SYSTEM_OPTIONS,
  WEIGHT_UNIT_OPTIONS,
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
        title="Failed to load store settings"
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
  const updateMutation = useUpdateStoreSettings()

  const form = useForm<StoreSettingsFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(storeSettingsFormSchema) as any,
    defaultValues: storeToFormValues(store),
  })

  // When unit_system flips, reset weight_unit to the first valid option for
  // that system so the form never holds an inconsistent pair.
  const unitSystem = form.watch('preferred_unit_system')
  useEffect(() => {
    const validUnits = WEIGHT_UNIT_OPTIONS[unitSystem]?.map((u) => u.value) ?? []
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
      toast.success('Store settings updated')
      form.reset(values)
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Failed to update store settings')
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title="Store settings"
            subtitle="General configuration for this store."
            actions={<FormActions form={form} />}
          />
        }
        main={
          <>
            <Card>
              <CardHeader>
                <CardTitle>General</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="name">Store name</FieldLabel>
                    <Input
                      id="name"
                      {...form.register('name')}
                      aria-invalid={!!form.formState.errors.name}
                    />
                    {form.formState.errors.name && (
                      <p className="text-sm text-destructive">
                        {form.formState.errors.name.message}
                      </p>
                    )}
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Standards and formats</CardTitle>
              </CardHeader>
              <CardContent>
                <FieldGroup>
                  <Field>
                    <FieldLabel htmlFor="preferred_admin_locale">Admin language</FieldLabel>
                    <Controller
                      name="preferred_admin_locale"
                      control={form.control}
                      render={({ field }) => (
                        <Select
                          value={field.value ?? ''}
                          onValueChange={(v) => field.onChange(v || null)}
                        >
                          <SelectTrigger id="preferred_admin_locale">
                            <SelectValue placeholder="Use the default language" />
                          </SelectTrigger>
                          <SelectContent>
                            {ADMIN_LOCALE_OPTIONS.map((opt) => (
                              <SelectItem key={opt.value} value={opt.value}>
                                {opt.label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </Field>

                  <Field>
                    <FieldLabel htmlFor="preferred_timezone">Timezone</FieldLabel>
                    <Controller
                      name="preferred_timezone"
                      control={form.control}
                      render={({ field }) => (
                        <Select value={field.value} onValueChange={field.onChange}>
                          <SelectTrigger id="preferred_timezone">
                            <SelectValue placeholder="Select a timezone" />
                          </SelectTrigger>
                          <SelectContent className="max-h-80">
                            {TIMEZONES.map((tz) => (
                              <SelectItem key={tz} value={tz}>
                                {tz}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                    {form.formState.errors.preferred_timezone && (
                      <p className="text-sm text-destructive">
                        {form.formState.errors.preferred_timezone.message}
                      </p>
                    )}
                  </Field>

                  <Field>
                    <FieldLabel htmlFor="preferred_unit_system">Unit system</FieldLabel>
                    <Controller
                      name="preferred_unit_system"
                      control={form.control}
                      render={({ field }) => (
                        <Select value={field.value} onValueChange={field.onChange}>
                          <SelectTrigger id="preferred_unit_system">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {UNIT_SYSTEM_OPTIONS.map((opt) => (
                              <SelectItem key={opt.value} value={opt.value}>
                                {opt.label}
                              </SelectItem>
                            ))}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </Field>

                  <Field>
                    <FieldLabel htmlFor="preferred_weight_unit">Weight unit</FieldLabel>
                    <Controller
                      name="preferred_weight_unit"
                      control={form.control}
                      render={({ field }) => (
                        <Select value={field.value} onValueChange={field.onChange}>
                          <SelectTrigger id="preferred_weight_unit">
                            <SelectValue />
                          </SelectTrigger>
                          <SelectContent>
                            {(WEIGHT_UNIT_OPTIONS[unitSystem] ?? WEIGHT_UNIT_OPTIONS.metric).map(
                              (opt) => (
                                <SelectItem key={opt.value} value={opt.value}>
                                  {opt.label}
                                </SelectItem>
                              ),
                            )}
                          </SelectContent>
                        </Select>
                      )}
                    />
                  </Field>
                </FieldGroup>
              </CardContent>
            </Card>
          </>
        }
      />
    </form>
  )
}
