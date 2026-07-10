import { adminClient, Can, ResourceTable, Subject } from '@spree/dashboard-core'
import { Button, RowActions, Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle, useConfirm } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useForm } from 'react-hook-form'
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

  const editId = search.edit
  const isCreating = !!search.new
  const resource = useTaxRate(editId, !editId)
  const { data, isLoading } = useTaxRates()

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

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">{t('admin.tax_rates.title', 'Tax Rates')}</h1>
        <Can do="create" on={Subject.TaxRate}>
          <Button onClick={openCreate} size="sm" variant="default">
            <PlusIcon className="w-4 h-4 mr-2" />
            {t('admin.actions.new')}
          </Button>
        </Can>
      </div>

      <ResourceTable
        name="tax-rates"
        columns={[
          { key: 'name', label: t('admin.tax_rates.name') },
          { key: 'amount', label: t('admin.tax_rates.amount') },
          { key: 'tax_category_id', label: t('admin.tax_rates.tax_category') },
          {
            key: 'actions',
            label: t('admin.actions.title'),
            Cell: ({ row }) => (
              <RowActions>
                <Button variant="ghost" size="sm" onClick={() => openEdit(row.id)}>
                  {t('admin.actions.edit')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={async () => {
                    const ok = await confirm({
                      title: t('admin.tax_rates.delete_confirm.title'),
                      message: t('admin.tax_rates.delete_confirm.message', { name: row.name }),
                      variant: 'destructive',
                    })
                    if (ok) {
                      deleteMutation.mutate({ id: row.id }, { onSuccess: () => queryClient.invalidateQueries() })
                    }
                  }}
                >
                  {t('admin.actions.delete')}
                </Button>
              </RowActions>
            ),
          },
        ]}
        data={data?.data || []}
        isLoading={isLoading}
        resourceName="tax-rates"
      />

      <Sheet open={isCreating || !!editId} onOpenChange={closeSheet}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>{isCreating ? t('admin.tax_rates.new') : t('admin.tax_rates.edit')}</SheetTitle>
          </SheetHeader>
          {(isCreating || resource.data) && (
            <TaxRateForm mode={isCreating ? 'create' : 'edit'} taxRate={resource.data} onSuccess={closeSheet} />
          )}
        </SheetContent>
      </Sheet>
    </div>
  )
}

function TaxRateForm({ mode, taxRate, onSuccess }) {
  const { t } = useTranslation()
  const createMutation = useCreateTaxRate()
  const updateMutation = useUpdateTaxRate()
  const { data: taxCategories } = useTaxCategories()
  const { data: zones } = useZones()
  const { register, handleSubmit, formState: { errors } } = useForm({
    defaultValues: taxRate || { name: '', amount: 0, included_in_price: false },
  })

  const onSubmit = (data) => {
    if (mode === 'create') {
      createMutation.mutate(data, { onSuccess })
    } else {
      updateMutation.mutate({ id: taxRate.id, ...data }, { onSuccess })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label>{t('admin.tax_rates.name')}</label>
        <input {...register('name', { required: true })} className="w-full px-2 py-1 border rounded" />
      </div>
      <div>
        <label>{t('admin.tax_rates.amount')} (%)</label>
        <input type="number" step="0.01" {...register('amount', { required: true })} className="w-full px-2 py-1 border rounded" />
      </div>
      <div>
        <label>{t('admin.tax_rates.tax_category')}</label>
        <select {...register('tax_category_id', { required: true })} className="w-full px-2 py-1 border rounded">
          <option value="">{t('admin.common.select')}</option>
          {taxCategories?.data?.map((cat) => (
            <option key={cat.id} value={cat.id}>
              {cat.name}
            </option>
          ))}
        </select>
      </div>
      <div>
        <label>
          <input type="checkbox" {...register('included_in_price')} />
          {t('admin.tax_rates.included_in_price')}
        </label>
      </div>
      <SheetFooter>
        <Button type="submit" disabled={createMutation.isPending || updateMutation.isPending}>
          {t('admin.actions.save')}
        </Button>
      </SheetFooter>
    </form>
  )
}
