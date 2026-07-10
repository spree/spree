import type { Import } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { isImportActive, useDeleteImport } from '@/hooks/use-imports'
import '@/tables/imports'

export const Route = createFileRoute('/_authenticated/$storeId/settings/imports/')({
  validateSearch: resourceSearchSchema,
  component: ImportsPage,
})

function ImportsPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const search = Route.useSearch()
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteImport()

  useRowClickBridge('data-import-id', (id: string) =>
    navigate({
      to: '/$storeId/settings/imports/$importId',
      params: { storeId, importId: id },
    }),
  )

  async function handleDelete(imp: Import) {
    const ok = await confirm({
      title: t('admin.pages.settings.imports.delete_confirm.title'),
      message: t('admin.pages.settings.imports.delete_confirm.message', { number: imp.number }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(imp.id).catch(() => undefined)
  }

  return (
    <ResourceTable<Import>
      tableKey="imports"
      queryKey="imports"
      queryFn={(params) => adminClient.imports.list(params)}
      searchParams={search}
      rowActions={(imp) => (
        <RowActions
          actions={[
            {
              key: 'view',
              label: t('admin.actions.view'),
              onSelect: () =>
                navigate({
                  to: '/$storeId/settings/imports/$importId',
                  params: { storeId, importId: imp.id },
                }),
            },
            {
              key: 'delete',
              destructive: true,
              // Deleting mid-processing is refused server-side (422) — the
              // pipeline's jobs re-load the record while running.
              disabled: deleteMutation.isPending || isImportActive(imp.status),
              onSelect: () => handleDelete(imp),
            },
          ]}
        />
      )}
    />
  )
}
