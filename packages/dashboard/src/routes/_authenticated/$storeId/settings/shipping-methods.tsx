import { adminClient, Can, ResourceTable, Subject, useStore } from '@spree/dashboard-core'
import { Button, RowActions, Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle, useConfirm } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon, MoreVerticalIcon } from 'lucide-react'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateShippingMethod,
  useDeleteShippingMethod,
  useShippingMethod,
  useShippingMethods,
  useUpdateShippingMethod,
} from '@/hooks/use-shipping-methods'

const shippingMethodsSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/shipping-methods')({
  validateSearch: shippingMethodsSearchSchema,
  component: ShippingMethodsPage,
})

function ShippingMethodsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof shippingMethodsSearchSchema>
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteShippingMethod()

  const editId = search.edit
  const isCreating = !!search.new
  const resource = useShippingMethod(editId, !editId)
  const { data, isLoading } = useShippingMethods()

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
        <h1 className="text-2xl font-bold">{t('admin.shipping_methods.title', 'Shipping Methods')}</h1>
        <Can do="create" on={Subject.ShippingMethod}>
          <Button onClick={openCreate} size="sm" variant="default">
            <PlusIcon className="w-4 h-4 mr-2" />
            {t('admin.actions.new')}
          </Button>
        </Can>
      </div>

      <ResourceTable
        name="shipping-methods"
        columns={[
          { key: 'name', label: t('admin.shipping_methods.name') },
          { key: 'display_on', label: t('admin.shipping_methods.display_on') },
          {
            key: 'actions',
            label: t('admin.actions.title'),
            Cell: ({ row }) => (
              <RowActions>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={() => openEdit(row.id)}
                >
                  {t('admin.actions.edit')}
                </Button>
                <Button
                  variant="ghost"
                  size="sm"
                  onClick={async () => {
                    const ok = await confirm({
                      title: t('admin.shipping_methods.delete_confirm.title'),
                      message: t('admin.shipping_methods.delete_confirm.message', { name: row.name }),
                      variant: 'destructive',
                    })
                    if (ok) {
                      deleteMutation.mutate({ id: row.id, storeId }, {
                        onSuccess: () => queryClient.invalidateQueries(),
                      })
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
        resourceName="shipping-methods"
      />

      <Sheet open={isCreating || !!editId} onOpenChange={closeSheet}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>
              {isCreating ? t('admin.shipping_methods.new') : t('admin.shipping_methods.edit')}
            </SheetTitle>
          </SheetHeader>
          {(isCreating || resource.data) && (
            <ShippingMethodForm
              mode={isCreating ? 'create' : 'edit'}
              shippingMethod={resource.data}
              onSuccess={() => {
                closeSheet()
                queryClient.invalidateQueries()
              }}
            />
          )}
        </SheetContent>
      </Sheet>
    </div>
  )
}

function ShippingMethodForm({ mode, shippingMethod, onSuccess }) {
  const { t } = useTranslation()
  const createMutation = useCreateShippingMethod()
  const updateMutation = useUpdateShippingMethod()
  const { register, handleSubmit, formState: { errors } } = useForm({
    defaultValues: shippingMethod || {
      name: '',
      display_on: 1,
    },
  })

  const onSubmit = (data) => {
    if (mode === 'create') {
      createMutation.mutate(data, { onSuccess })
    } else {
      updateMutation.mutate({ id: shippingMethod.id, ...data }, { onSuccess })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label>{t('admin.shipping_methods.name')}</label>
        <input {...register('name', { required: true })} className="w-full px-2 py-1 border rounded" />
        {errors.name && <span className="text-red-500">{t('admin.errors.required')}</span>}
      </div>
      <div>
        <label>{t('admin.shipping_methods.display_on')}</label>
        <select {...register('display_on')} className="w-full px-2 py-1 border rounded">
          <option value={1}>{t('admin.shipping_methods.display_on_frontend')}</option>
          <option value={2}>{t('admin.shipping_methods.display_on_backend')}</option>
        </select>
      </div>
      <SheetFooter>
        <Button type="submit" variant="default" disabled={createMutation.isPending || updateMutation.isPending}>
          {t('admin.actions.save')}
        </Button>
      </SheetFooter>
    </form>
  )
}
