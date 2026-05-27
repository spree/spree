import { zodResolver } from '@hookform/resolvers/zod'
import type { PaymentMethod, PreferenceField } from '@spree/admin-sdk'
import {
  Button,
  RowActions,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { PaymentMethodForm } from '@/components/spree/payment-method-editors/payment-method-form'
import type { PaymentMethodFormValues } from '@/components/spree/payment-method-editors/types'
import { defaultPreferences } from '@/components/spree/preferences-form'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import {
  useCreatePaymentMethod,
  useDeletePaymentMethod,
  usePaymentMethod,
  usePaymentMethodTypes,
  useUpdatePaymentMethod,
} from '@/hooks/use-payment-methods'
import { mapSpreeErrorsToForm } from '@/lib/form-errors'
import { Subject } from '@/lib/permissions'
import { usePermissions } from '@/providers/permission-provider'
import { useStore } from '@/providers/store-provider'
import {
  PAYMENT_METHOD_BASE_DEFAULTS,
  PAYMENT_METHOD_CREATE_DEFAULTS,
  paymentMethodBaseFormSchema,
  paymentMethodCreateFormSchema,
  paymentMethodValuesToCreateParams,
  paymentMethodValuesToUpdateParams,
} from '@/schemas/payment-method'
import '@/tables/payment-methods'

const paymentMethodsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/payment-methods')({
  validateSearch: paymentMethodsSearchSchema,
  component: PaymentMethodsPage,
})

function PaymentMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof paymentMethodsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeletePaymentMethod()
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

  useRowClickBridge('data-payment-method-id', openEdit)

  async function handleDelete(method: PaymentMethod) {
    const ok = await confirm({
      title: t('admin.payment_methods.delete_confirm.title'),
      message: t('admin.payment_methods.delete_confirm.message', { name: method.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    // `useDeletePaymentMethod` toasts on success/error via `onError`; the
    // `.catch` only swallows the rethrow so the row-action callback doesn't
    // surface an unhandled rejection.
    await deleteMutation.mutateAsync(method.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<PaymentMethod>
        tableKey="payment-methods"
        queryKey="payment-methods"
        queryFn={(params) => adminClient.paymentMethods.list(params)}
        searchParams={search}
        rowActions={(method) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(method.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.PaymentMethod),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(method),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.PaymentMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.payment_methods.add_cta')}
            </Button>
          </Can>
        }
        reorder={{
          onReorder: async (id, position) => {
            await adminClient.paymentMethods.update(id, { position })
            queryClient.invalidateQueries({ queryKey: ['payment-methods'] })
          },
        }}
      />

      {isCreating && <CreatePaymentMethodSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditPaymentMethodSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreatePaymentMethodSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreatePaymentMethod()
  const { data: typesResponse, isLoading: loadingTypes } = usePaymentMethodTypes()
  const providerTypes = useMemo(() => typesResponse?.data ?? [], [typesResponse])
  // Seed `currency`-typed preferences with the store default so the merchant
  // sees and submits a real value — `CurrencySelect` only displays the
  // fallback now (it no longer commits via onChange).
  const { defaultCurrency } = useStore()

  const form = useForm<PaymentMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(paymentMethodCreateFormSchema) as any,
    defaultValues: PAYMENT_METHOD_CREATE_DEFAULTS,
  })

  const [preferences, setPreferences] = useState<Record<string, unknown>>({})
  const providerType = form.watch('type') ?? ''
  const preferenceSchema: PreferenceField[] = useMemo(
    () => providerTypes.find((t) => t.type === providerType)?.preference_schema ?? [],
    [providerTypes, providerType],
  )

  function handleProviderTypeChange(next: string) {
    const nextSchema = providerTypes.find((t) => t.type === next)?.preference_schema ?? []
    setPreferences(defaultPreferences(nextSchema, { currency: defaultCurrency }))
  }

  async function onSubmit(values: PaymentMethodFormValues) {
    try {
      await createMutation.mutateAsync(paymentMethodValuesToCreateParams(values, preferences))
      form.reset(PAYMENT_METHOD_CREATE_DEFAULTS)
      setPreferences({})
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
          form.reset(PAYMENT_METHOD_CREATE_DEFAULTS)
          setPreferences({})
        }
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.payment_methods.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.payment_methods.create_description')}</SheetDescription>
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
            />
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
                : t('admin.payment_methods.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditPaymentMethodSheet({
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
      auto_capture: paymentMethod.auto_capture ?? false,
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
  // Title-case the shorthand for the sheet header — `stripe` → `Stripe`,
  // `store_credit` → `Store Credit`.
  const providerLabel = providerType
    .split('_')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ')

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
                preferenceSchema={paymentMethod?.preference_schema ?? []}
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
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="submit"
                size="sm"
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
