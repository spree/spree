import { createFileRoute } from '@tanstack/react-router'
import { PayoutPage } from '../../../../pages/payout'

export const Route = createFileRoute('/_authenticated/$sellerId/payouts/$payoutId')({
  component: PayoutPage,
})
