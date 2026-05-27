import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useTranslation } from 'react-i18next'
import { useConfirm } from '@/components/spree/confirm-dialog'
import { PromotionForm } from '@/components/spree/promotion-editors/promotion-form'
import {
  useDeletePromotion,
  usePromotion,
  usePromotionActions,
  usePromotionRules,
  useUpdatePromotion,
} from '@/hooks/use-promotions'

export const Route = createFileRoute('/_authenticated/$storeId/promotions/$promotionId')({
  component: EditPromotionPage,
})

function EditPromotionPage() {
  const { t } = useTranslation()
  const { storeId, promotionId } = Route.useParams()
  const navigate = useNavigate()
  const { data: promotion } = usePromotion(promotionId)
  // Rules and actions are listed separately because the promotion serializer
  // doesn't embed them; the shared form re-hydrates once all three arrive.
  const { data: rulesData } = usePromotionRules(promotionId)
  const { data: actionsData } = usePromotionActions(promotionId)
  const updateMutation = useUpdatePromotion(promotionId)
  const deleteMutation = useDeletePromotion()
  const confirm = useConfirm()

  async function onDelete() {
    const ok = await confirm({
      title: t('admin.promotions.delete_confirm.title'),
      message: t('admin.promotions.delete_confirm.message', {
        name: promotion?.name ?? t('admin.promotions.delete_confirm.default_name'),
      }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return
    await deleteMutation.mutateAsync(promotionId)
    navigate({ to: '/$storeId/promotions', params: { storeId } })
  }

  return (
    <PromotionForm
      mode="edit"
      promotion={promotion}
      initialRules={rulesData?.data}
      initialActions={actionsData?.data}
      onSubmit={async (payload) => {
        await updateMutation.mutateAsync(payload)
      }}
      onDelete={onDelete}
      deletePending={deleteMutation.isPending}
    />
  )
}
