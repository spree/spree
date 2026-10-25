// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { DeliveryMethodServiceParams } from './DeliveryMethodServiceParams'

export type DeliveryMethodCreateParams = {
  name: string
  admin_name?: string | null
  code?: string | null
  /** Fulfillment provider shorthand (see the fulfillment providers endpoint), e.g. `manual`. */
  fulfillment_provider?: string
  pickup_point_provider?: string | null
  /**
   * Rate provider shorthand (see the rate providers endpoint), e.g. `easy_post`. Omit or send null
   * for the built-in provider, which prices through the method's calculator.
   */
  rate_provider?: string | null
  storefront_visible?: boolean
  /**
   * Marketplace only: whether a seller's packages may be quoted by this method. Off by default, and
   * refused on a method that belongs to a seller.
   */
  available_to_sellers?: boolean
  tracking_url?: string | null
  estimated_transit_business_days_min?: number | null
  estimated_transit_business_days_max?: number | null
  /** Prefixed tax category ID (`taxcat_...`), or null to clear. */
  tax_category_id?: string | null
  /** Method-level flat handling fee added on top of provider-quoted rates. */
  markup_flat?: string | null
  /**
   * Method-level percentage handling fee added on top of provider-quoted rates. Ignored for
   * calculator-priced methods.
   */
  markup_percent?: string | null
  /** Delivery profile this method belongs to (`fp_...`); defaults to the store default profile. */
  delivery_profile_id?: string
  /**
   * Origin group offering this method (`og_...`); defaults to the zone's group, else the profile's
   * default group.
   */
  delivery_origin_group_id?: string
  /**
   * Delivery zone narrowing destinations (`dz_...`), or null for no restriction. Must belong to the
   * method's profile.
   */
  delivery_zone_id?: string | null
  /** Pickup locations (`sloc_...`); replaces the full set. */
  stock_location_ids?: string[]
  /**
   * How the method prices a shipment: a type from the calculators endpoint and its preferences,
   * matching that type's `schema`.
   */
  calculator?: {
    type?: string
    preferences?: Record<string, unknown>
  }
  /** Eligibility rules. Replaces the full set: omitted rules are removed. */
  rules?: {
    id?: string
    /** A rule kind from the delivery method rule types endpoint. */
    type?: string
    active?: boolean
    preferences?: Record<string, unknown>
    /** Products an association-backed rule (`excluded_products_rule`) applies to. */
    product_ids?: string[]
  }[]
  /**
   * Carrier service rows: which provider services this method offers. Replaces the full set:
   * omitted rows are removed; no rows means every service the provider returns is offered.
   */
  services?: DeliveryMethodServiceParams[]
}
