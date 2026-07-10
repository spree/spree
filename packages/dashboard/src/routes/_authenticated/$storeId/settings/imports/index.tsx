import type { Import } from '@spree/admin-sdk'
import { adminClient, ResourceTable, resourceSearchSchema } from '@spree/dashboard-core'
import { RowActions, useConfirm, useRowClickBridge } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { ImportWizardDialog } from '@/components/spree/imports/import-wizard-dialog'
import { isImportActive, useDeleteImport } from '@/hooks/use-imports'
import '@/tables/imports'

// `import` carries the prefixed id of the import whose wizard dialog is open,
// so the flow is deep-linkable and survives refresh (same pattern as the
// webhooks `delivery` param).
const importsSearchSchema = resourceSearchSchema.extend({
  import: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$storeId/settings/imports/')({
  validateSearch: importsSearchSchema,
  component: ImportsPage,
})

function ImportsPage() {
  const { t } = useTranslation()
  const search = Route.useSearch() as z.infer<typeof importsSearchSchema>
  const navigate = useNavigate()
  const confirm = useConfirm()
  const deleteMutation = useDeleteImport()

  const openWizard = (id: string) =>
    navigate({ search: (prev: Record<string, unknown>) => ({ ...prev, import: id }) as never })

  const closeWizard = () =>
    navigate({
      search: (prev: Record<string, unknown>) => {
        const { import: _i, ...rest } = prev
        return rest as never
      },
    })

  useRowClickBridge('data-import-id', openWizard)

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
    <>
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
                onSelect: () => openWizard(imp.id),
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

      <ImportWizardDialog importId={search.import ?? null} onClose={closeWizard} />
    </>
  )
}
