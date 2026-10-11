// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValueParams } from './CustomFieldValueParams'
import type { PriceParams } from './PriceParams'
import type { ProductDigitalAssetParams } from './ProductDigitalAssetParams'
import type { ProductMediaParams } from './ProductMediaParams'
import type { ProductPublicationParams } from './ProductPublicationParams'
import type { ProductVariantParams } from './ProductVariantParams'

export type ProductUpdateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  name?: string
  /** Rich text HTML. Reads come back as this (plain text) plus `description_html`. */
  description?: string
  slug?: string
  status?: 'draft' | 'active' | 'archived'
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  tax_category_id?: string
  /**
   * The product type this product is created from (`pt_...`). Its option types and categories seed
   * onto the product and its custom field definitions drive the product form. Editing the type
   * later never rewrites existing products.
   */
  product_type_id?: string | null
  /**
   * The delivery profile deciding how this product ships (`fp_...`); null falls back to the store
   * default.
   */
  delivery_profile_id?: string | null
  promotionable?: boolean
  tags?: string[]
  category_ids?: string[]
  /**
   * Manual collections this product belongs to. Automatic collections are kept as they are, since
   * their rules decide membership.
   */
  collection_ids?: string[]
  metadata?: Record<string, unknown>
  /**
   * Shorthand for a simple (no-options) product: per-currency prices that forward to the product's
   * sole variant. For products with options, set prices per variant under `variants` instead. Don't
   * pass both.
   */
  prices?: PriceParams[]
  /** Custom field values, each validated against its definition. */
  custom_fields?: CustomFieldValueParams[]
  /**
   * Media written with the product. Entries with `id` update an existing asset; entries with
   * `signed_id` attach a fresh upload; an external video needs only its URL.
   */
  media?: ProductMediaParams[]
  /**
   * Downloadable files written with the product. Each entry carries a `signed_id` (an upload to
   * private storage) or a `provider_type` (a provider-backed asset), and attaches to the default
   * variant unless `variant_id` is given. An `id` updates that asset in place, so replaying the
   * list does not duplicate it; removal uses the nested digital assets endpoint.
   */
  digital_assets?: ProductDigitalAssetParams[]
  product_publications?: ProductPublicationParams[]
  /**
   * Every purchasable attribute (sku, prices, stock, weight, dimensions) lives on variants. An
   * entry without `options` upserts onto the default variant of a simple product; pass `id` to
   * update an existing variant.
   */
  variants?: ProductVariantParams[]
}
