import { Can, ResourceTable, Subject } from '@spree/dashboard-core'
import { Button, RowActions, Sheet, SheetContent, SheetFooter, SheetHeader, SheetTitle, useConfirm } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PlusIcon } from 'lucide-react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import {
  useCreateZone,
  useDeleteZone,
  useZone,
  useZones,
  useUpdateZone,
  useCountries,
} from '@/hooks/use-zones'

const zonesSearchSchema = z.object({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
  q: z.string().optional(),
  page: z.coerce.number().optional(),
  limit: z.coerce.number().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/zones')({
  validateSearch: zonesSearchSchema,
  component: ZonesPage,
})

function ZonesPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof zonesSearchSchema>
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const confirm = useConfirm()
  const deleteMutation = useDeleteZone()

  const editId = search.edit
  const isCreating = !!search.new
  const resource = useZone(editId, !editId)
  const { data, isLoading } = useZones()

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
        <h1 className="text-2xl font-bold">{t('admin.zones.title', 'Zones')}</h1>
        <Can do="create" on={Subject.Zone}>
          <Button onClick={openCreate} size="sm" variant="default">
            <PlusIcon className="w-4 h-4 mr-2" />
            {t('admin.actions.new')}
          </Button>
        </Can>
      </div>

      <ResourceTable
        name="zones"
        columns={[
          { key: 'name', label: t('admin.zones.name') },
          { key: 'description', label: t('admin.zones.description') },
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
                      title: t('admin.zones.delete_confirm.title'),
                      message: t('admin.zones.delete_confirm.message', { name: row.name }),
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
        resourceName="zones"
      />

      <Sheet open={isCreating || !!editId} onOpenChange={closeSheet}>
        <SheetContent>
          <SheetHeader>
            <SheetTitle>{isCreating ? t('admin.zones.new') : t('admin.zones.edit')}</SheetTitle>
          </SheetHeader>
          {(isCreating || resource.data) && (
            <ZoneForm mode={isCreating ? 'create' : 'edit'} zone={resource.data} onSuccess={closeSheet} />
          )}
        </SheetContent>
      </Sheet>
    </div>
  )
}

function ZoneForm({ mode, zone, onSuccess }) {
  const { t } = useTranslation()
  const createMutation = useCreateZone()
  const updateMutation = useUpdateZone()
  const { data: countries } = useCountries()
  const { register, handleSubmit, formState: { errors } } = useForm({
    defaultValues: zone || { name: '', description: '', default_tax: false },
  })

  const onSubmit = (data) => {
    if (mode === 'create') {
      createMutation.mutate(data, { onSuccess })
    } else {
      updateMutation.mutate({ id: zone.id, ...data }, { onSuccess })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)} className="space-y-4">
      <div>
        <label>{t('admin.zones.name')}</label>
        <input {...register('name', { required: true })} className="w-full px-2 py-1 border rounded" />
      </div>
      <div>
        <label>{t('admin.zones.description')}</label>
        <textarea {...register('description')} className="w-full px-2 py-1 border rounded" />
      </div>
      <div>
        <label>
          <input type="checkbox" {...register('default_tax')} />
          {t('admin.zones.default_tax')}
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
