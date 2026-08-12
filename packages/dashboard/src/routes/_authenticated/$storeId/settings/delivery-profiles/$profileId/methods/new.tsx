import { createFileRoute, redirect } from '@tanstack/react-router'
import { z } from 'zod/v4'

/**
 * `zone` preselects the zone the merchant clicked "Add method" inside;
 * `group` files the method under the origin group they added it from, which
 * matters only once a profile has been split into several; `provider`
 * preselects the kind of fulfillment they asked for.
 */
const newMethodSearchSchema = z.object({
  zone: z.string().optional(),
  group: z.string().optional(),
  provider: z.enum(['pickup', 'digital']).optional(),
})

/**
 * The method form moved into a sheet on the profile page, so this URL only
 * survives for the links and bookmarks that still point at it: it forwards to
 * the profile with the sheet open, carrying the preselection across.
 */
export const Route = createFileRoute(
  '/_authenticated/$storeId/settings/delivery-profiles/$profileId/methods/new',
)({
  validateSearch: newMethodSearchSchema,
  beforeLoad: ({ params, search }) => {
    throw redirect({
      to: '/$storeId/settings/delivery-profiles/$profileId',
      params: { storeId: params.storeId, profileId: params.profileId },
      search: {
        method: 'new',
        ...(search.zone ? { zone: search.zone } : {}),
        ...(search.group ? { group: search.group } : {}),
        ...(search.provider ? { provider: search.provider } : {}),
      },
      replace: true,
    })
  },
})
