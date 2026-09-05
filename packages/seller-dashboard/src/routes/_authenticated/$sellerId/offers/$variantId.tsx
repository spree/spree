import { createFileRoute } from '@tanstack/react-router'
import { OfferPage } from '../../../../pages/offer'

export const Route = createFileRoute('/_authenticated/$sellerId/offers/$variantId')({
  component: () => <OfferPage mode="edit" />,
})
