import { createFileRoute, redirect } from '@tanstack/react-router'

/**
 * Gift cards moved out of Promotions and into the Loyalty group: a gift card
 * is prepaid money the store owes, not a discount. This URL survives only for
 * the bookmarks and pasted links that still point at it.
 */
export const Route = createFileRoute('/_authenticated/$storeId/promotions/gift-cards')({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$storeId/loyalty/gift-cards',
      params: { storeId: params.storeId },
      replace: true,
    })
  },
})
