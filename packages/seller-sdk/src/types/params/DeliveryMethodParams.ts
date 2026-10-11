// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { DeliveryMethodRuleParams } from './DeliveryMethodRuleParams'

export type DeliveryMethodParams = {
  name?: string
  admin_name?: string | null
  code?: string | null
  /** One of the marketplace's delivery profiles. */
  delivery_profile_id?: string
  /** Narrows where the method ships; null serves everywhere the profile reaches. */
  delivery_zone_id?: string | null
  storefront_visible?: boolean
  tracking_url?: string | null
  estimated_transit_business_days_min?: number | null
  estimated_transit_business_days_max?: number | null
  /**
   * How the method is priced: a type from `/delivery_methods/calculators` and its preferences, per
   * that type's `schema`.
   */
  calculator?: {
    type?: string
    preferences?: Record<string, unknown>
  }
  /**
   * Replaces the whole set: a rule dropped here is deleted, so re-send surviving rules with their
   * `id`. An empty list clears every condition.
   */
  rules?: DeliveryMethodRuleParams[]
}
