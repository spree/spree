import { zodResolver } from '@hookform/resolvers/zod'
import type {
  PaymentMethod,
  PaymentMethodCreateParams,
  PaymentMethodUpdateParams,
  PreferenceField,
} from '@spree/admin-sdk'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect, useMemo, useRef, useState } from 'react'
import { useForm } from 'react-hook-form'
import { z } from 'zod/v4'
import { adminClient } from '@/client'
import { Can } from '@/components/spree/can'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { PaymentMethodForm } from '@/components/spree/payment-method-editors/payment-method-form'
import type { PaymentMethodFormValues } from '@/components/spree/payment-method-editors/types'
import { defaultPreferences } from '@/components/spree/preferences-form'
import { ResourceTable, resourceSearchSchema } from '@/components/spree/resource-table'
import { useRowClickBridge } from '@/components/spree/row-click-bridge'
import { Button } from '@/components/ui/button'
import {
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@/components/ui/sheet'
import {
  useCreatePaymentMethod,
  useDeletePaymentMethod,
  usePaymentMethod,
  usePaymentMethodTypes,
  useUpdatePaymentMethod,
} from '@/hooks/use-payment-methods'
import { Subject } from '@/lib/permissions'
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
  const search = Route.useSearch() as z.infer<typeof paymentMethodsSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()

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

  return (
    <>
      <ResourceTable<PaymentMethod>
        tableKey="payment-methods"
        queryKey="payment-methods"
        queryFn={(params) => adminClient.paymentMethods.list(params)}
        searchParams={search}
        actions={
          <Can I="create" a={Subject.PaymentMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              Add payment method
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

const baseFormSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),
  storefront_visible: z.boolean(),
  active: z.boolean(),
  auto_capture: z.boolean(),
})

const createFormSchema = baseFormSchema.extend({
  type: z.string().min(1, 'Pick a provider'),
})

const BASE_DEFAULTS: PaymentMethodFormValues = {
  name: '',
  description: '',
  storefront_visible: true,
  active: true,
  auto_capture: false,
}

const CREATE_DEFAULTS: PaymentMethodFormValues = { ...BASE_DEFAULTS, type: '' }

function valuesToCreateParams(
  v: PaymentMethodFormValues,
  preferences: Record<string, unknown>,
): PaymentMethodCreateParams {
  return {
    type: v.type ?? '',
    name: v.name,
    description: v.description?.length ? v.description : null,
    active: v.active,
    auto_capture: v.auto_capture,
    storefront_visible: v.storefront_visible,
    ...(Object.keys(preferences).length > 0 ? { preferences } : {}),
  }
}

function valuesToUpdateParams(v: PaymentMethodFormValues): PaymentMethodUpdateParams {
  return {
    name: v.name,
    description: v.description?.length ? v.description : null,
    active: v.active,
    auto_capture: v.auto_capture,
    storefront_visible: v.storefront_visible,
  }
}

function CreatePaymentMethodSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const createMutation = useCreatePaymentMethod()
  const { data: typesResponse, isLoading: loadingTypes } = usePaymentMethodTypes()
  const providerTypes = useMemo(() => typesResponse?.data ?? [], [typesResponse])

  const form = useForm<PaymentMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(createFormSchema) as any,
    defaultValues: CREATE_DEFAULTS,
  })

  const [preferences, setPreferences] = useState<Record<string, unknown>>({})
  const providerType = form.watch('type') ?? ''
  const preferenceSchema: PreferenceField[] = useMemo(
    () => providerTypes.find((t) => t.type === providerType)?.preference_schema ?? [],
    [providerTypes, providerType],
  )

  function handleProviderTypeChange(next: string) {
    const nextSchema = providerTypes.find((t) => t.type === next)?.preference_schema ?? []
    setPreferences(defaultPreferences(nextSchema))
  }

  async function onSubmit(values: PaymentMethodFormValues) {
    await createMutation.mutateAsync(valuesToCreateParams(values, preferences))
    form.reset(CREATE_DEFAULTS)
    setPreferences({})
    onOpenChange(false)
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) {
          form.reset(CREATE_DEFAULTS)
          setPreferences({})
        }
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>Add payment method</SheetTitle>
          <SheetDescription>Pick a provider and configure it in one step.</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
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
              Cancel
            </Button>
            <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
              {form.formState.isSubmitting ? 'Creating…' : 'Create payment method'}
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
  const { data: paymentMethod, isLoading } = usePaymentMethod(id)
  const updateMutation = useUpdatePaymentMethod(id)
  const deleteMutation = useDeletePaymentMethod()
  const confirm = useConfirm()

  const form = useForm<PaymentMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(baseFormSchema) as any,
    defaultValues: BASE_DEFAULTS,
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
    const params = valuesToUpdateParams(values)
    if (preferencesDirty) params.preferences = preferences
    await updateMutation.mutateAsync(params)
    form.reset(values)
    originalPreferencesRef.current = JSON.stringify(preferences)
    onOpenChange(false)
  }

  async function onDelete() {
    const ok = await confirm({
      title: 'Delete payment method?',
      message: `${paymentMethod?.name ?? 'This payment method'} will be removed. Existing payments referencing it remain intact.`,
      variant: 'destructive',
      confirmLabel: 'Delete',
    })
    if (!ok) return
    await deleteMutation.mutateAsync(id)
    onOpenChange(false)
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
          <SheetTitle>{paymentMethod?.name ?? 'Edit payment method'}</SheetTitle>
          <SheetDescription>
            {providerLabel ? `Provider: ${providerLabel}` : 'Update name, visibility, or status.'}
          </SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">Loading…</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
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
              <Can I="destroy" a={Subject.PaymentMethod}>
                <Button
                  type="button"
                  variant="ghost"
                  size="sm"
                  onClick={onDelete}
                  disabled={form.formState.isSubmitting || deleteMutation.isPending}
                  className="mr-auto text-destructive hover:bg-destructive/10 hover:text-destructive"
                >
                  Delete
                </Button>
              </Can>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => onOpenChange(false)}
                disabled={form.formState.isSubmitting}
              >
                Cancel
              </Button>
              <Button
                type="submit"
                size="sm"
                disabled={
                  form.formState.isSubmitting || (!form.formState.isDirty && !preferencesDirty)
                }
              >
                {form.formState.isSubmitting ? 'Saving…' : 'Save'}
              </Button>
            </SheetFooter>
          </form>
        )}
      </SheetContent>
    </Sheet>
  )
}
