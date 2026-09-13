import { createFileRoute, redirect } from '@tanstack/react-router'

/**
 * Gift cards moved out of Promotions and into the Loyalty group: a gift card
 * is prepaid money the store owes, not a discount. This URL survives only for
 * the bookmarks and pasted links that still point at it.
 */
export const Route = createFileRoute('/_authenticated/$storeId/promotions/gift-cards')({
  // Passed through as-is: no ancestor validates search here, so without this
  // the `search` handed to `beforeLoad` is empty and the redirect would drop
  // whatever the bookmark carried.
  validateSearch: (search: Record<string, unknown>) => search,
  beforeLoad: ({ params, search }) => {
    throw redirect({
      to: '/$storeId/loyalty/gift-cards',
      params: { storeId: params.storeId },
      // Carried through: the create action used to link here with `?new=true`,
      // and a bookmark can hold a filter or a sort worth keeping.
      search: search as never,
      replace: true,
    })
  },
})
