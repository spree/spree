import { createFileRoute, redirect } from '@tanstack/react-router'

// Payouts folded into the single Marketplace settings page — one form for the
// seven store preferences a marketplace configures. The old address keeps
// working.
export const Route = createFileRoute('/_authenticated/$storeId/settings/payouts')({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$storeId/settings/marketplace',
      params: { storeId: params.storeId },
    })
  },
  component: () => null,
})
