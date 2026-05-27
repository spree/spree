import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PromotionForm } from '@/components/spree/promotion-editors/promotion-form'
import { useCreatePromotion } from '@/hooks/use-promotions'

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
        navigate({
          to: '/$storeId/promotions/$promotionId',
          params: { storeId, promotionId: promotion.id },
        })
      }}
    />
  )
}
