import { useResourceKeyBuilder } from '@spree/dashboard-core'
import { toastManager, useConfirm } from '@spree/dashboard-ui'
import { useQueryClient } from '@tanstack/react-query'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { ImportWizardDialog } from '../../../../../../components/spree/imports/import-wizard-dialog'
import {
  importWizardSearchSchema,
  useImportWizardSearch,
} from '../../../../../../components/spree/imports/import-wizard-search'
import { PriceListForm } from '../../../../../../components/spree/price-list-editors/price-list-form'
import {
  useDeletePriceList,
  usePriceList,
  useUpdatePriceList,
} from '../../../../../../hooks/use-price-lists'

export const Route = createFileRoute('/_authenticated/$storeId/products/price-lists/$priceListId/')(
  {
    validateSearch: importWizardSearchSchema,
    component: EditPriceListPage,
  },
)

function EditPriceListPage() {
  const { t } = useTranslation()
  const { storeId, priceListId } = Route.useParams()
  const navigate = useNavigate()
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()
  const wizard = useImportWizardSearch(Route.useSearch())

  // The products card reads prices too. It is the one key the wizard leaves
  // alone on completion, since refetching the list itself would reset the
  // form under whatever the merchant has typed but not saved.
  const closeImportWizard = () => {
    queryClient.invalidateQueries({ queryKey: buildKey('price-lists', priceListId, 'products') })
    wizard.close()
  }
  // Pull rules inline via expand — there's no separate /price_rules
  // endpoint anymore; rules ship as a nested array on the price list.
  const { data: priceList } = usePriceList(priceListId, ['price_rules'])
  const updateMutation = useUpdatePriceList(priceListId)
  const deleteMutation = useDeletePriceList()
  const confirm = useConfirm()

  async function onDelete() {
    const ok = await confirm({
      title: t('admin.pages.products.price_lists.delete_confirm.title'),
      message: t('admin.pages.products.price_lists.delete_confirm.message', {
        name: priceList?.name ?? '',
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    try {
      await deleteMutation.mutateAsync(priceListId)
    } catch (err) {
      // Surface failure as a toast and stay on the page — navigating away
      // would tell the user the row vanished when it didn't.
      toastManager.add({
        type: 'error',
        title: err instanceof Error ? err.message : t('admin.errors.failed_to_delete'),
      })
      return
    }
    navigate({ to: '/$storeId/products/price-lists', params: { storeId } })
  }

  return (
    <>
      <PriceListForm
        mode="edit"
        priceList={priceList}
        initialRules={priceList?.price_rules}
        onSubmit={async (payload) => {
          await updateMutation.mutateAsync(payload)
        }}
        onDelete={onDelete}
        onImportCreated={(imp) => wizard.open(imp.id)}
        deletePending={deleteMutation.isPending}
      />
      <ImportWizardDialog importId={wizard.importId} onClose={closeImportWizard} />
    </>
  )
}
