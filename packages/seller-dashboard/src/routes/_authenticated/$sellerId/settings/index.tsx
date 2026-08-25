import { createFileRoute, redirect } from '@tanstack/react-router'

/**
 * Settings is a launcher, not a page — landing on it bare would show the rail
 * beside an empty pane, so it opens the first entry, as the operator's
 * dashboard does.
 */
export const Route = createFileRoute('/_authenticated/$sellerId/settings/')({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$sellerId/settings/stock-locations',
      params: { sellerId: params.sellerId },
      replace: true,
    })
  },
})
