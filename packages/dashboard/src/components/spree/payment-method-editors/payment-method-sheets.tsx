import { zodResolver } from '@hookform/resolvers/zod'
import type { PaymentMethodType, PreferenceSchema } from '@spree/admin-sdk'
import { defaultPreferences, mapSpreeErrorsToForm, useStore } from '@spree/dashboard-core'
import {
  Button,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  useCreatePaymentMethod,
  usePaymentMethod,
  usePaymentMethodTypes,
  useUpdatePaymentMethod,
} from '../../../hooks/use-payment-methods'
import {
  PAYMENT_METHOD_BASE_DEFAULTS,
  PAYMENT_METHOD_CREATE_DEFAULTS,
  paymentMethodBaseFormSchema,
  paymentMethodCreateFormSchema,
  paymentMethodValuesToCreateParams,
  paymentMethodValuesToUpdateParams,
} from '../../../schemas/payment-method'
import { SetupGuideLink } from '../integrations/setup-guide-link'
import { PaymentMethodForm } from './payment-method-form'
import type { PaymentMethodFormValues } from './types'

/** Readable provider name from its wire shorthand — `store_credit` → `Store Credit`. */
export function paymentProviderLabel(type: string) {
  return type
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')
}

/**
 * Add-payment-method sheet. Pass `initialType` to open it with that provider
 * already chosen, as the integrations gallery does from a provider card.
 */
export function CreatePaymentMethodSheet({
  open,
  onOpenChange,
  initialType,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
  initialType?: PaymentMethodType
}) {
  const { t } = useTranslation()
  const createMutation = useCreatePaymentMethod()
  const { data: typesResponse, isLoading: loadingTypes } = usePaymentMethodTypes()
  const providerTypes = useMemo(
    () => (typesResponse?.data ?? []).filter((type) => !type.installed),
    [typesResponse],
  )
  // Seed `currency`-typed preferences with the store default so the merchant
  // sees and submits a real value — `CurrencySelect` only displays the
  // fallback now (it no longer commits via onChange).
  const { defaultCurrency } = useStore()

  const createDefaults: PaymentMethodFormValues = initialType
    ? { ...PAYMENT_METHOD_CREATE_DEFAULTS, type: initialType.type, name: initialType.label }
    : PAYMENT_METHOD_CREATE_DEFAULTS
  const initialPreferences = () =>
    initialType ? defaultPreferences(initialType.schema, { currency: defaultCurrency }) : {}

  const form = useForm<PaymentMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(paymentMethodCreateFormSchema) as any,
    defaultValues: createDefaults,
  })

  const [preferences, setPreferences] = useState<Record<string, unknown>>(initialPreferences)
  const providerType = form.watch('type') ?? ''
  const preferenceSchema: PreferenceSchema | undefined = useMemo(
    () => providerTypes.find((t) => t.type === providerType)?.schema,
    [providerTypes, providerType],
  )

  function handleProviderTypeChange(next: string) {
    const nextSchema = providerTypes.find((t) => t.type === next)?.schema
    setPreferences(defaultPreferences(nextSchema, { currency: defaultCurrency }))
  }

  async function onSubmit(values: PaymentMethodFormValues) {
    try {
      await createMutation.mutateAsync(paymentMethodValuesToCreateParams(values, preferences))
      form.reset(createDefaults)
      setPreferences(initialPreferences())
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          form.reset(createDefaults)
          setPreferences(initialPreferences())
        }
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.payment_methods.add_sheet_title')}</SheetTitle>
          <SheetDescription>
            {initialType
              ? t('admin.payment_methods.provider_description', { provider: initialType.label })
              : t('admin.payment_methods.create_description')}
          </SheetDescription>
          <SetupGuideLink
            url={providerTypes.find((entry) => entry.type === providerType)?.docs_url}
          />
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <PaymentMethodForm
              mode="create"
              form={form}
              providerTypes={providerTypes}
              loadingTypes={loadingTypes}
              preferenceSchema={preferenceSchema}
              providerType={providerType}
              paymentMethod={null}
              preferences={preferences}
              onPreferencesChange={setPreferences}
              onProviderTypeChange={handleProviderTypeChange}
              providerLocked={!!initialType}
            />
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
                : t('admin.payment_methods.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

export function EditPaymentMethodSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: paymentMethod, isLoading } = usePaymentMethod(id)
  const updateMutation = useUpdatePaymentMethod(id)
  // The provider's preference schema comes from its `/types` entry, matched
  // by the record's `type`.
  const { data: typesData } = usePaymentMethodTypes({ enabled: open })
  const preferenceSchema = typesData?.data.find(
    (entry) => entry.type === paymentMethod?.type,
  )?.schema

  const form = useForm<PaymentMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(paymentMethodBaseFormSchema) as any,
    defaultValues: PAYMENT_METHOD_BASE_DEFAULTS,
  })
  const [preferences, setPreferences] = useState<Record<string, unknown>>({})
  // Snapshot of the preferences last loaded from the server. Derive the
  // dirty state by comparing JSON shape — avoids a separate flag that
  // can drift out of sync with the actual values.
  const originalPreferencesRef = useRef<string>('{}')
  // Track the loaded record so we don't clobber in-flight edits when the
  // cache invalidates after a save.
  const loadedIdRef = useRef<string | undefined>(undefined)

  useEffect(() => {
    if (!paymentMethod || paymentMethod.id === loadedIdRef.current) return
    form.reset({
      name: paymentMethod.name,
      description: paymentMethod.description ?? '',
      storefront_visible: paymentMethod.storefront_visible ?? true,
      active: paymentMethod.active,
      capture_method: paymentMethod.capture_method ?? '',
    })
    const initialPreferences = (paymentMethod.preferences as Record<string, unknown>) ?? {}
    setPreferences(initialPreferences)
    originalPreferencesRef.current = JSON.stringify(initialPreferences)
    loadedIdRef.current = paymentMethod.id
  }, [paymentMethod, form])

  const preferencesDirty = useMemo(
    () => JSON.stringify(preferences) !== originalPreferencesRef.current,
    [preferences],
  )

  async function onSubmit(values: PaymentMethodFormValues) {
    const params = paymentMethodValuesToUpdateParams(values)
    if (preferencesDirty) params.preferences = preferences
    try {
      await updateMutation.mutateAsync(params)
      form.reset(values)
      originalPreferencesRef.current = JSON.stringify(preferences)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  // STI shorthand for slot lookup, e.g. `bogus`, `stripe`. The API
  // returns it on the `type` attribute (see PaymentMethodSerializer).
  const providerType = paymentMethod?.type ?? ''
  const providerLabel = paymentProviderLabel(providerType)

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {paymentMethod?.name ?? t('admin.pages.settings.payment_methods.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>
            {providerLabel
              ? t('admin.payment_methods.provider_description', { provider: providerLabel })
              : t('admin.payment_methods.edit_description')}
          </SheetDescription>
          <SetupGuideLink url={paymentMethod?.docs_url} />
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              {form.formState.errors.root?.message && (
                <p className="text-sm text-destructive" role="alert">
                  {form.formState.errors.root.message}
                </p>
              )}
              <PaymentMethodForm
                mode="edit"
                form={form}
                preferenceSchema={preferenceSchema}
                providerType={providerType}
                paymentMethod={paymentMethod ?? null}
                preferences={preferences}
                onPreferencesChange={setPreferences}
              />
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
                disabled={
                  form.formState.isSubmitting || (!form.formState.isDirty && !preferencesDirty)
                }
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
