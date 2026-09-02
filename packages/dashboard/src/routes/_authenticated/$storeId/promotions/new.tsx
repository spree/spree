import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PromotionForm } from '../../../../components/spree/promotion-editors/promotion-form'
import { useCreatePromotion } from '../../../../hooks/use-promotions'

export const Route = createFileRoute('/_authenticated/$storeId/promotions/new')({
  component: NewPromotionPage,
})

function NewPromotionPage() {
  const navigate = useNavigate()
  const { storeId } = Route.useParams()
  const createMutation = useCreatePromotion()

  return (
    <PromotionForm
      mode="create"
      onSubmit={async (payload) => {
        const promotion = await createMutation.mutateAsync(payload)
        // Replace history rather than pushing — otherwise the detail page's
        // back button lands the merchant on the (now-stale) new promotion form.
        navigate({
          to: '/$storeId/promotions/$promotionId',
          params: { storeId, promotionId: promotion.id },
          replace: true,
        })
      }}
    />
  )
}
