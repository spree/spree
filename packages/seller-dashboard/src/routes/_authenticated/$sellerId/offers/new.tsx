import { createFileRoute } from '@tanstack/react-router'
import { z } from 'zod'
import { OfferPage } from '../../../../pages/offer'

// The master product being listed against, carried in the URL so the form is
// refresh-safe and the picker's choice can be linked to.
const newOfferSearchSchema = z.object({
  product: z.string().optional(),
})

export const Route = createFileRoute('/_authenticated/$sellerId/offers/new')({
  validateSearch: newOfferSearchSchema,
  component: () => <OfferPage mode="new" />,
})
