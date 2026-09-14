import { createFileRoute, redirect } from '@tanstack/react-router'

// Commission rates moved out of Settings and under Sellers, beside the
// transfers and payouts they feed. The old address keeps working.
export const Route = createFileRoute('/_authenticated/$storeId/settings/commission-rates')({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$storeId/sellers/commission-rates',
      params: { storeId: params.storeId },
    })
  },
  component: () => null,
})
