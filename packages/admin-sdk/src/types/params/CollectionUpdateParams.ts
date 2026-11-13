// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CollectionPublicationParams } from './CollectionPublicationParams'
import type { CollectionRuleParams } from './CollectionRuleParams'
import type { CustomFieldValueParams } from './CustomFieldValueParams'

export type CollectionUpdateParams = {
  name?: string
  /** Rich text HTML. Reads come back as this (plain text) plus `description_html`. */
  description?: string
  permalink?: string
  /**
   * 1-based position among the store's collections; the server shifts its siblings. The nested
   * products reposition endpoints, unlike this, take 0-based indexes.
   */
  position?: number
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  /** A `signed_id` from `files.upload()` for the landscape image, or null to remove it. */
  image_signed_id?: string | null
  /** A `signed_id` from `files.upload()` for the square image, or null to remove it. */
  square_image_signed_id?: string | null
  /**
   * Ignored. Membership combines `rules`, hand-picked products and exclusions.
   * @deprecated Ignored: a collection is automatic while it has `rules`. Send `rules: []` to remove
   * them. Removed in 6.2.
   */
  automatic?: boolean
  /** Whether a product must match all rules or any of them. Defaults to `all`. */
  rules_match_policy?: 'all' | 'any'
  /**
   * Default product sort for the storefront listing; a shopper's own sort wins. Defaults to
   * `manual`.
   */
  sort_order?: 'manual' | 'best_selling' | 'price asc' | 'price desc' | 'available_on desc' | 'available_on asc' | 'name asc' | 'name desc'
  /**
   * The complete desired rule set. Entries with an `id` update, entries without one are created,
   * and existing rules left out are removed.
   */
  rules?: CollectionRuleParams[]
  /**
   * The complete set of channels the collection is published on. Channels left out are unpublished.
   * Omit on create to publish on every active channel.
   */
  publications?: CollectionPublicationParams[]
  /** Custom field values, each validated against its definition. */
  custom_fields?: CustomFieldValueParams[]
}
