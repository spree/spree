import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { PriceListForm } from '@/components/spree/price-list-editors/price-list-form'
import { useCreatePriceList } from '@/hooks/use-price-lists'

export const Route = createFileRoute('/_authenticated/$storeId/products/price-lists/new')({
  component: NewPriceListPage,
})

function NewPriceListPage() {
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const create = useCreatePriceList()

  return (
    <PriceListForm
      mode="create"
      onSubmit={async (payload) => {
        const list = await create.mutateAsync(payload)
        navigate({
          to: '/$storeId/products/price-lists/$priceListId',
          params: { storeId, priceListId: list.id },
        })
      }}
    />
  )
}
