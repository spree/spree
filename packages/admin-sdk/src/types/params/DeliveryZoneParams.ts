// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { DeliveryZoneMemberParams } from './DeliveryZoneMemberParams'

export type DeliveryZoneParams = {
  name?: string
  description?: string | null
  /** Delivery profile this zone belongs to (`fp_...`); defaults to the store default profile. */
  delivery_profile_id?: string
  /** Origin group this zone belongs to (`og_...`). */
  delivery_origin_group_id?: string
  /** Replaces the zone's full member set atomically. */
  members?: DeliveryZoneMemberParams[]
}
