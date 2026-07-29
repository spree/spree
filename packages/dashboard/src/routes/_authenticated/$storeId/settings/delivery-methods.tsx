import { zodResolver } from '@hookform/resolvers/zod'
import type { DeliveryMethod } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RowActions,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Switch,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, type UseFormReturn, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateDeliveryMethod,
  useDeleteDeliveryMethod,
  useDeliveryCalculators,
  useDeliveryMethod,
  useUpdateDeliveryMethod,
} from '../../../../hooks/use-delivery-methods'
import { useDeliveryZones } from '../../../../hooks/use-delivery-zones'
import { useTaxCategories } from '../../../../hooks/use-tax-categories'
import {
  DELIVERY_METHOD_DEFAULTS,
  type DeliveryMethodFormValues,
  deliveryMethodFormSchema,
  deliveryMethodValuesToParams,
  FULFILLMENT_TYPES,
} from '../../../../schemas/delivery-method'
import '../../../../tables/delivery-methods'

const deliveryMethodsSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/delivery-methods')({
  validateSearch: deliveryMethodsSearchSchema,
  component: DeliveryMethodsPage,
})

function DeliveryMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof deliveryMethodsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteDeliveryMethod()
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

  useRowClickBridge('data-delivery-method-id', openEdit)

  async function handleDelete(deliveryMethod: DeliveryMethod) {
    const ok = await confirm({
      title: t('admin.delivery_methods.delete_confirm.title'),
      message: t('admin.delivery_methods.delete_confirm.message', {
        name: deliveryMethod.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(deliveryMethod.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<DeliveryMethod>
        tableKey="delivery-methods"
        queryKey="delivery-methods"
        queryFn={(params) => adminClient.deliveryMethods.list(params)}
        searchParams={search}
        rowActions={(deliveryMethod) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(deliveryMethod.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.DeliveryMethod),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(deliveryMethod),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.DeliveryMethod}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.delivery_methods.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateDeliveryMethodSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && (
        <EditDeliveryMethodSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />
      )}
    </>
  )
}

function CreateDeliveryMethodSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateDeliveryMethod()
  const form = useForm<DeliveryMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryMethodFormSchema) as any,
    defaultValues: DELIVERY_METHOD_DEFAULTS,
  })

  async function onSubmit(values: DeliveryMethodFormValues) {
    try {
      await createMutation.mutateAsync(deliveryMethodValuesToParams(values))
      form.reset(DELIVERY_METHOD_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(DELIVERY_METHOD_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.delivery_methods.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.delivery_methods.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <DeliveryMethodFormFields form={form} />
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
                : t('admin.delivery_methods.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditDeliveryMethodSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: deliveryMethod, isLoading } = useDeliveryMethod(id)
  const updateMutation = useUpdateDeliveryMethod(id)

  const form = useForm<DeliveryMethodFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(deliveryMethodFormSchema) as any,
    defaultValues: DELIVERY_METHOD_DEFAULTS,
  })

  useEffect(() => {
    if (deliveryMethod) {
      form.reset({
        name: deliveryMethod.name,
        admin_name: deliveryMethod.admin_name ?? '',
        code: deliveryMethod.code ?? '',
        fulfillment_type:
          (deliveryMethod.fulfillment_type as DeliveryMethodFormValues['fulfillment_type']) ??
          'shipping',
        storefront_visible: deliveryMethod.storefront_visible,
        tracking_url: deliveryMethod.tracking_url ?? '',
        estimated_transit_business_days_min:
          deliveryMethod.estimated_transit_business_days_min?.toString() ?? '',
        estimated_transit_business_days_max:
          deliveryMethod.estimated_transit_business_days_max?.toString() ?? '',
        tax_category_id: deliveryMethod.tax_category_id ?? '',
        calculator_type: deliveryMethod.calculator_type ?? '',
        calculator_preferences:
          (deliveryMethod.calculator_preferences as Record<string, unknown>) ?? {},
        delivery_zone_ids: deliveryMethod.delivery_zone_ids ?? [],
      })
    }
  }, [deliveryMethod, form])

  async function onSubmit(values: DeliveryMethodFormValues) {
    try {
      await updateMutation.mutateAsync(deliveryMethodValuesToParams(values))
      form.reset(values)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent>
        <SheetHeader>
          <SheetTitle>
            {deliveryMethod?.name ?? t('admin.delivery_methods.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.delivery_methods.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <DeliveryMethodFormFields form={form} />
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
                disabled={form.formState.isSubmitting || !form.formState.isDirty}
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

function DeliveryMethodFormFields({ form }: { form: UseFormReturn<DeliveryMethodFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data: calculators } = useDeliveryCalculators()
  const { data: zones } = useDeliveryZones()
  const { data: taxCategories } = useTaxCategories()

  const fulfillmentType = form.watch('fulfillment_type')
  const calculatorType = form.watch('calculator_type')

  const fulfillmentTypeOptions = FULFILLMENT_TYPES.map((value) => ({
    value,
    label: t(`admin.delivery_methods.fulfillment_types.${value}`),
  }))

  const calculatorOptions = (calculators?.data ?? []).map((calculator) => ({
    value: calculator.type,
    label: calculator.name,
  }))

  const selectedCalculator = (calculators?.data ?? []).find((c) => c.type === calculatorType)
  const preferenceSchema = (selectedCalculator?.preference_schema ?? []) as Array<{
    key: string
    type: string
    default: unknown
  }>

  const taxCategoryOptions = [
    { value: '', label: t('admin.common.none') },
    ...(taxCategories?.data ?? []).map((tc) => ({ value: tc.id, label: tc.name })),
  ]

  return (
    <FieldGroup>
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
        <FieldLabel>{t('admin.fields.delivery_method.fulfillment_type.label')}</FieldLabel>
        <Controller
          name="fulfillment_type"
          control={form.control}
          render={({ field }) => (
            <Select
              items={fulfillmentTypeOptions}
              value={field.value}
              onValueChange={field.onChange}
            >
              <SelectTrigger>
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {fulfillmentTypeOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
      </Field>

      {(fulfillmentType === 'shipping' || fulfillmentType === 'pickup_point') && (
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

          {preferenceSchema
            .filter((preference) => preference.type !== 'boolean')
            .map((preference) => (
              <Field key={preference.key}>
                <FieldLabel htmlFor={`calculator-${preference.key}`}>
                  {t(`admin.fields.calculator.${preference.key}.label`, {
                    defaultValue: preference.key,
                  })}
                </FieldLabel>
                <Controller
                  name={`calculator_preferences.${preference.key}`}
                  control={form.control}
                  render={({ field }) => (
                    <Input
                      id={`calculator-${preference.key}`}
                      value={(field.value as string | number | undefined)?.toString() ?? ''}
                      onChange={(e) => field.onChange(e.target.value)}
                    />
                  )}
                />
              </Field>
            ))}

          <Field>
            <FieldLabel>{t('admin.fields.delivery_method.delivery_zones.label')}</FieldLabel>
            <Controller
              name="delivery_zone_ids"
              control={form.control}
              render={({ field }) => (
                <div className="flex flex-col gap-2">
                  {(zones?.data ?? []).length === 0 && (
                    <span className="text-xs text-muted-foreground">
                      {t('admin.delivery_methods.no_zones_hint')}
                    </span>
                  )}
                  {(zones?.data ?? []).map((zone) => {
                    const checked = field.value.includes(zone.id)
                    return (
                      <label
                        key={zone.id}
                        htmlFor={`delivery-zone-${zone.id}`}
                        className="flex items-center gap-2 text-sm"
                      >
                        <Checkbox
                          id={`delivery-zone-${zone.id}`}
                          checked={checked}
                          onCheckedChange={(next) => {
                            field.onChange(
                              next
                                ? [...field.value, zone.id]
                                : field.value.filter((zoneId: string) => zoneId !== zone.id),
                            )
                          }}
                        />
                        {zone.name}
                      </label>
                    )
                  })}
                </div>
              )}
            />
          </Field>
        </>
      )}

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
    </FieldGroup>
  )
}
