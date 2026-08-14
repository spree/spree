import { zodResolver } from '@hookform/resolvers/zod'
import type { TaxRate } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  CountryCombobox,
  mapSpreeErrorsToForm,
  ResourceTable,
  resourceSearchSchema,
  StateCombobox,
  Subject,
  useCountryStates,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Button,
  Field,
  FieldDescription,
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
import { useTaxCategories } from '../../../../hooks/use-tax-categories'
import {
  useCreateTaxRate,
  useDeleteTaxRate,
  useTaxRate,
  useUpdateTaxRate,
} from '../../../../hooks/use-tax-rates'
import {
  TAX_RATE_DEFAULTS,
  type TaxRateFormValues,
  taxRateFormSchema,
  taxRateValuesToParams,
} from '../../../../schemas/tax-rate'
import '../../../../tables/tax-rates'

const taxRatesSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/tax-rates')({
  validateSearch: taxRatesSearchSchema,
  component: TaxRatesPage,
})

function TaxRatesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof taxRatesSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteTaxRate()
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

  useRowClickBridge('data-tax-rate-id', openEdit)

  async function handleDelete(taxRate: TaxRate) {
    const ok = await confirm({
      title: t('admin.tax_rates.delete_confirm.title'),
      message: t('admin.tax_rates.delete_confirm.message', { name: taxRate.name ?? '' }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(taxRate.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<TaxRate>
        tableKey="tax-rates"
        queryKey="tax-rates"
        queryFn={(params) => adminClient.taxRates.list(params)}
        searchParams={search}
        rowActions={(taxRate) => (
          <RowActions
            actions={[
              { key: 'edit', onSelect: () => openEdit(taxRate.id) },
              {
                key: 'delete',
                destructive: true,
                visible: permissions.can('destroy', Subject.TaxRate),
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(taxRate),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.TaxRate}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.tax_rates.add_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <CreateTaxRateSheet open onOpenChange={(o) => !o && closeSheet()} />}
      {editId && <EditTaxRateSheet id={editId} open onOpenChange={(o) => !o && closeSheet()} />}
    </>
  )
}

function CreateTaxRateSheet({
  open,
  onOpenChange,
}: {
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const createMutation = useCreateTaxRate()
  const form = useForm<TaxRateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxRateFormSchema) as any,
    defaultValues: TAX_RATE_DEFAULTS,
  })

  async function onSubmit(values: TaxRateFormValues) {
    try {
      await createMutation.mutateAsync(taxRateValuesToParams(values))
      form.reset(TAX_RATE_DEFAULTS)
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset(TAX_RATE_DEFAULTS)
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.pages.settings.tax_rates.add_sheet_title')}</SheetTitle>
          <SheetDescription>{t('admin.tax_rates.create_description')}</SheetDescription>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            <TaxRateFormFields form={form} />
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
                : t('admin.tax_rates.create_label')}
            </Button>
          </SheetFooter>
        </form>
      </SheetContent>
    </Sheet>
  )
}

function EditTaxRateSheet({
  id,
  open,
  onOpenChange,
}: {
  id: string
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const { t } = useTranslation()
  const { data: taxRate, isLoading } = useTaxRate(id)
  const updateMutation = useUpdateTaxRate(id)

  const form = useForm<TaxRateFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(taxRateFormSchema) as any,
    defaultValues: TAX_RATE_DEFAULTS,
  })

  useEffect(() => {
    if (taxRate) {
      form.reset({
        name: taxRate.name,
        amount_percentage: taxRate.amount_percentage ?? 0,
        tax_category_id: taxRate.tax_category_id ?? '',
        country_iso: taxRate.country_iso ?? '',
        state_code: taxRate.state_code ?? '',
        included_in_price: taxRate.included_in_price,
        show_rate_in_label: taxRate.show_rate_in_label,
      })
    }
  }, [taxRate, form])

  async function onSubmit(values: TaxRateFormValues) {
    try {
      await updateMutation.mutateAsync(taxRateValuesToParams(values))
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
            {taxRate?.name ?? t('admin.pages.settings.tax_rates.edit_sheet_title')}
          </SheetTitle>
          <SheetDescription>{t('admin.tax_rates.edit_description')}</SheetDescription>
        </SheetHeader>
        {isLoading ? (
          <div className="p-4 text-sm text-muted-foreground">{t('admin.common.loading')}</div>
        ) : (
          <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
            <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
              <TaxRateFormFields form={form} />
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

function TaxRateFormFields({ form }: { form: UseFormReturn<TaxRateFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const { data: taxCategories } = useTaxCategories({ limit: 100 })
  const countryIso = form.watch('country_iso')
  const { states } = useCountryStates(countryIso)

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
          placeholder={t('admin.fields.tax_rate.name.placeholder')}
          aria-invalid={!!errors.name || undefined}
          {...form.register('name')}
        />
        <FieldError errors={[errors.name]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="amount_percentage">
          {t('admin.fields.tax_rate.amount.label')}
        </FieldLabel>
        <Input
          id="amount_percentage"
          type="number"
          step="0.01"
          min="0"
          max="100"
          inputMode="decimal"
          aria-invalid={!!errors.amount_percentage || undefined}
          {...form.register('amount_percentage')}
        />
        <FieldDescription>{t('admin.fields.tax_rate.amount.help')}</FieldDescription>
        <FieldError errors={[errors.amount_percentage]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="tax_category_id">
          {t('admin.fields.tax_rate.tax_category_id.label')}
        </FieldLabel>
        <Controller
          name="tax_category_id"
          control={form.control}
          render={({ field }) => (
            <Select value={field.value} onValueChange={field.onChange}>
              <SelectTrigger id="tax_category_id" aria-invalid={!!errors.tax_category_id}>
                <SelectValue placeholder={t('admin.tax_rates.select_category')}>
                  {(value) =>
                    taxCategories?.data?.find((c) => c.id === value)?.name ?? (value as string)
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {taxCategories?.data?.map((taxCategory) => (
                  <SelectItem key={taxCategory.id} value={taxCategory.id}>
                    {taxCategory.name}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}
        />
        <FieldDescription>{t('admin.fields.tax_rate.tax_category_id.help')}</FieldDescription>
        <FieldError errors={[errors.tax_category_id]} />
      </Field>

      <Field>
        <FieldLabel htmlFor="country_iso">{t('admin.fields.country.label')}</FieldLabel>
        <Controller
          name="country_iso"
          control={form.control}
          render={({ field }) => (
            <CountryCombobox
              value={field.value}
              onValueChange={(iso) => {
                field.onChange(iso)
                // The old state belongs to the old country; keeping it would
                // silently narrow the rate to a state that no longer exists.
                form.setValue('state_code', '', { shouldDirty: true })
              }}
              placeholder={t('admin.tax_rates.every_country')}
            />
          )}
        />
        <FieldDescription>{t('admin.fields.tax_rate.country_iso.help')}</FieldDescription>
      </Field>

      {countryIso && states.length > 0 && (
        <Field>
          <FieldLabel htmlFor="state_code">{t('admin.fields.state.label')}</FieldLabel>
          <Controller
            name="state_code"
            control={form.control}
            render={({ field }) => (
              <StateCombobox
                countryIso={countryIso}
                value={field.value}
                onValueChange={field.onChange}
                states={states}
                placeholder={t('admin.tax_rates.every_state')}
              />
            )}
          />
          <FieldDescription>{t('admin.fields.tax_rate.state_code.help')}</FieldDescription>
        </Field>
      )}

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="included_in_price" className="cursor-pointer">
              {t('admin.fields.tax_rate.included_in_price.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.tax_rate.included_in_price.help')}
            </span>
          </div>
          <Controller
            name="included_in_price"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="included_in_price"
                checked={!!field.value}
                onCheckedChange={field.onChange}
              />
            )}
          />
        </div>
      </Field>

      <Field>
        <div className="flex items-start justify-between gap-4">
          <div className="flex flex-col">
            <FieldLabel htmlFor="show_rate_in_label" className="cursor-pointer">
              {t('admin.fields.tax_rate.show_rate_in_label.label')}
            </FieldLabel>
            <span className="text-xs text-muted-foreground">
              {t('admin.fields.tax_rate.show_rate_in_label.help')}
            </span>
          </div>
          <Controller
            name="show_rate_in_label"
            control={form.control}
            render={({ field }) => (
              <Switch
                id="show_rate_in_label"
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
