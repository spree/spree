import { createFileRoute, redirect } from '@tanstack/react-router'

/**
 * The method form moved into a sheet on the profile page, so this URL only
 * survives for the links and bookmarks that still point at it: it forwards to
 * the profile with that method's sheet open.
 */
export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/delivery-profiles/$profileId/methods/$methodId',
)({
  beforeLoad: ({ params }) => {
    throw redirect({
      to: '/$storeId/settings/delivery-profiles/$profileId',
      params: { storeId: params.storeId, profileId: params.profileId },
      search: { method: params.methodId },
      replace: true,
    })
  },
})
