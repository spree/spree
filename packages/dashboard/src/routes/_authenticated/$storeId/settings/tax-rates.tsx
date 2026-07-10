import { adminClient, Can, mapSpreeErrorsToForm, ResourceTable, Subject, usePermissions } from '@spree/dashboard-core'
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
  SheetFooter,
  SheetHeader,
  SheetTitle,
  useConfirm,
  useRowClickBridge,
} from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useEffect } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateTaxRate,
  useDeleteTaxRate,
  useTaxRate,
  useTaxRates,
  useUpdateTaxRate,
  useTaxCategories,
  useZones,
} from '@/hooks/use-tax-rates'

const taxRatesSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/tax-rates')({
  validateSearch: taxRatesSearchSchema,
  component: TaxRatesPage,
})

function TaxRatesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof taxRatesSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
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

  async function handleDelete(taxRate: { id: string; name: string }) {
    const ok = await confirm({
      title: t('admin.tax_rates.delete_confirm.title'),
      message: t('admin.tax_rates.delete_confirm.message', { name: taxRate.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(taxRate.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable
        tableKey="tax-rates"
        queryKey="tax-rates"
        queryFn={(params) => adminClient.request('GET', '/tax_rates', { params: { ...params, per_page: 100 } })}
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
              {t('admin.tax_rates.add_cta', 'New Tax Rate')}
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
  const { data: categoriesResponse } = useTaxCategories()
  const categories = categoriesResponse?.data ?? []
  const form = useForm({
    defaultValues: { name: '', amount: '0', tax_category_id: '', included_in_price: false },
  })

  async function onSubmit(values: Record<string, unknown>) {
    try {
      await createMutation.mutateAsync({
        ...values,
        amount: Number(values.amount),
      })
      form.reset()
      onOpenChange(false)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) throw err
    }
  }

  return (
    <Sheet
      open={open}
      onOpenChange={(next) => {
        if (!next) form.reset()
        onOpenChange(next)
      }}
    >
      <SheetContent>
        <SheetHeader>
          <SheetTitle>{t('admin.tax_rates.new', 'New Tax Rate')}</SheetTitle>
        </SheetHeader>
        <form onSubmit={form.handleSubmit(onSubmit)} className="flex min-h-0 flex-1 flex-col">
          <div className="flex flex-1 flex-col gap-4 overflow-y-auto p-4">
            {form.formState.errors.root?.message && (
              <p className="text-sm text-destructive" role="alert">
                {form.formState.errors.root.message}
              </p>
            )}
            <FieldGroup>
              <Field>
                <FieldLabel htmlFor="name">{t('admin.tax_rates.name', 'Name')}</FieldLabel>
                <Input id="name" autoFocus {...form.register('name', { required: true })} />
                <FieldError errors={[form.formState.errors.name]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="amount">{t('admin.tax_rates.amount', 'Amount (%)')}</FieldLabel>
                <Input id="amount" type="number" step="0.01" {...form.register('amount', { required: true })} />
                <FieldError errors={[form.formState.errors.amount]} />
              </Field>

              <Field>
                <FieldLabel htmlFor="tax_category_id">{t('admin.tax_rates.tax_category', 'Tax Category')}</FieldLabel>
                <Controller
                  name="tax_category_id"
                  control={form.control}
                  rules={{ required: true }}
                  render={({ field }) => (
                    <Select value={field.value} onValueChange={field.onChange}>
                      <SelectTrigger id="tax_category_id" className="w-full" aria-invalid={!!form.formState.errors.tax_category_id}>
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {categories.map((cat) => (
                          <SelectItem key={cat.id} value={cat.id}>
                            {cat.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
                <FieldError errors={[form.formState.errors.tax_category_id]} />
              </Field>

              <Field>
                <div className="flex items-center gap-2">
                  <Controller
                    name="included_in_price"
                    control={form.control}
                    render={({ field }) => (
                      <Checkbox id="included_in_price" checked={!!field.value} onCheckedChange={field.onChange} />
                    )}
                  />
                  <FieldLabel htmlFor="included_in_price" className="cursor-pointer mb-0">
                    {t('admin.tax_rates.included_in_price', 'Included in Price')}
                  </FieldLabel>
                </div>
              </Field>
            </FieldGroup>
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
              {form.formState.isSubmitting ? t('admin.actions.creating') : t('admin.actions.save')}
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
  const updateMutation = useUpdateTaxRate()
  const { data: categoriesResponse } = useTaxCategories()
  const categories = categoriesResponse?.data ?? []
  const form = useForm({
    defaultValues: { name: '', amount: '0', tax_category_id: '', included_in_price: false },
  })

  useEffect(() => {
    if (taxRate) {
      form.reset({
        name: taxRate.name,
        amount: String(taxRate.amount),
        tax_category_id: taxRate.tax_category_id,
        included_in_price: taxRate.included_in_price,
      })
    }
  }, [taxRate, form])

  async function onSubmit(values: Record<string, unknown>) {
    try {
      await updateMutation.mutateAsync({
        id,
        ...values,
        amount: Number(values.amount),
      })
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
          <SheetTitle>{taxRate?.name ?? t('admin.tax_rates.edit', 'Edit Tax Rate')}</SheetTitle>
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
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="name">{t('admin.tax_rates.name', 'Name')}</FieldLabel>
                  <Input id="name" {...form.register('name', { required: true })} />
                  <FieldError errors={[form.formState.errors.name]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="amount">{t('admin.tax_rates.amount', 'Amount (%)')}</FieldLabel>
                  <Input id="amount" type="number" step="0.01" {...form.register('amount', { required: true })} />
                  <FieldError errors={[form.formState.errors.amount]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="tax_category_id">{t('admin.tax_rates.tax_category', 'Tax Category')}</FieldLabel>
                  <Controller
                    name="tax_category_id"
                    control={form.control}
                    rules={{ required: true }}
                    render={({ field }) => (
                      <Select value={field.value} onValueChange={field.onChange}>
                        <SelectTrigger id="tax_category_id" className="w-full" aria-invalid={!!form.formState.errors.tax_category_id}>
                          <SelectValue />
                        </SelectTrigger>
                        <SelectContent>
                          {categories.map((cat) => (
                            <SelectItem key={cat.id} value={cat.id}>
                              {cat.name}
                            </SelectItem>
                          ))}
                        </SelectContent>
                      </Select>
                    )}
                  />
                  <FieldError errors={[form.formState.errors.tax_category_id]} />
                </Field>

                <Field>
                  <div className="flex items-center gap-2">
                    <Controller
                      name="included_in_price"
                      control={form.control}
                      render={({ field }) => (
                        <Checkbox id="included_in_price" checked={!!field.value} onCheckedChange={field.onChange} />
                      )}
                    />
                    <FieldLabel htmlFor="included_in_price" className="cursor-pointer mb-0">
                      {t('admin.tax_rates.included_in_price', 'Included in Price')}
                    </FieldLabel>
                  </div>
                </Field>
              </FieldGroup>
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
