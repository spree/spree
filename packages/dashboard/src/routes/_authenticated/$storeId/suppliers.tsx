import type { Supplier } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ResourceTable,
  resourceSearchSchema,
  Subject,
  usePermissions,
} from '@spree/dashboard-core'
import { Button, RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { PencilIcon, PlusIcon } from '@spree/dashboard-ui/icons'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { SupplierSheet } from '../../../components/spree/supplier-sheet'
import { useDeleteSupplier } from '../../../hooks/use-suppliers'
import '../../../tables/suppliers'

const suppliersSearchSchema = resourceSearchSchema.extend({
  edit: z.string().optional(),
  new: z.coerce.boolean().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/suppliers')({
  validateSearch: suppliersSearchSchema,
  component: SuppliersPage,
})

function SuppliersPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof suppliersSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteSupplier()
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

  useRowClickBridge('data-supplier-id', openEdit)

  async function handleDelete(supplier: Supplier) {
    const ok = await confirm({
      title: t('admin.suppliers.delete_confirm.title'),
      message: t('admin.suppliers.delete_confirm.message', { name: supplier.name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(supplier.id).catch(() => undefined)
  }

  return (
    <>
      <ResourceTable<Supplier>
        tableKey="suppliers"
        queryKey="suppliers"
        queryFn={(params) => adminClient.suppliers.list(params)}
        searchParams={search}
        rowActions={(supplier) => (
          <RowActions
            actions={[
              {
                key: 'edit',
                label: t('admin.actions.edit'),
                icon: <PencilIcon className="size-4" />,
                onSelect: () => openEdit(supplier.id),
              },
              {
                key: 'delete',
                destructive: true,
                // A supplier with a purchasing history is kept: the orders
                // naming it have to keep meaning something, which is what the
                // model's `restrict_with_error` enforces. The Orders column
                // shows why the option is absent.
                visible: permissions.can('destroy', Subject.Supplier) && supplier.can_be_deleted,
                disabled: deleteMutation.isPending,
                onSelect: () => handleDelete(supplier),
              },
            ]}
          />
        )}
        actions={
          <Can I="create" a={Subject.Supplier}>
            <Button size="sm" className="h-[2.125rem]" onClick={openCreate}>
              <PlusIcon className="size-4" />
              {t('admin.suppliers.new_cta')}
            </Button>
          </Can>
        }
      />

      {isCreating && <SupplierSheet open onOpenChange={(open) => !open && closeSheet()} />}
      {editId && <SupplierSheet id={editId} open onOpenChange={(open) => !open && closeSheet()} />}
    </>
  )
}
