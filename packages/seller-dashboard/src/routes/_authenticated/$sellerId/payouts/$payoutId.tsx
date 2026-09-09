import { createFileRoute } from '@tanstack/react-router'
import { PayoutPage } from '../../../../pages/payout'

/** One settlement, and the earnings it covered. */
export const Route = createFileRoute('/_authenticated/$sellerId/payouts/$payoutId')({
  component: PayoutPage,
})
