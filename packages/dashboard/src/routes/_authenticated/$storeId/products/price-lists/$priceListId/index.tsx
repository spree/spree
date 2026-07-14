import { useConfirm } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { PriceListForm } from '../../../../../../components/spree/price-list-editors/price-list-form'
import {
  useDeletePriceList,
  usePriceList,
  useUpdatePriceList,
} from '../../../../../../hooks/use-price-lists'

export const Route = createFileRoute('/_authenticated/$storeId/products/price-lists/$priceListId/')(
  {
    component: EditPriceListPage,
  },
)

function EditPriceListPage() {
  const { t } = useTranslation()
  const { storeId, priceListId } = Route.useParams()
  const navigate = useNavigate()
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
      toast.error(err instanceof Error ? err.message : t('admin.errors.failed_to_delete'))
      return
    }
    navigate({ to: '/$storeId/products/price-lists', params: { storeId } })
  }

  return (
    <PriceListForm
      mode="edit"
      priceList={priceList}
      initialRules={priceList?.price_rules}
      onSubmit={async (payload) => {
        await updateMutation.mutateAsync(payload)
      }}
      onDelete={onDelete}
      deletePending={deleteMutation.isPending}
    />
  )
}
