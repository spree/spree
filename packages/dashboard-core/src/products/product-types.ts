/**
 * What the shared product form reads off a product, its variants and its
 * media.
 *
 * Structural rather than either SDK's generated type, for the same reason
 * `PanelStockLocation` is: the operator's Admin API and a seller's Seller API
 * serialize the same records, and the cards only ever touch the fields both
 * carry. Typing these against `@spree/admin-sdk` would make the form
 * unusable in a panel that holds no admin credential.
 *
 * Everything a panel may omit is optional, so a card can hide what it was not
 * given rather than render a blank.
 */

export interface PanelMedia {
  id: string
  media_type?: string
  alt?: string | null
  position?: number
  variant_ids?: string[]
  focal_point_x?: number | null
  focal_point_y?: number | null
  external_video_url?: string | null
  video_url?: string | null
  video_embed_url?: string | null
  poster_url?: string | null
  original_url?: string | null
  mini_url?: string | null
  small_url?: string | null
  medium_url?: string | null
  large_url?: string | null
  xlarge_url?: string | null
  download_url?: string | null
}

export interface PanelVariant {
  id: string
  sku?: string | null
  barcode?: string | null
  options_text?: string
  position?: number
  price?: { amount?: string | null; currency?: string | null } | null
  prices?: Array<{
    amount?: string | null
    currency?: string | null
    compare_at_amount?: string | null
  }>
  cost_price?: string | null
  cost_currency?: string | null
  weight?: number | null
  height?: number | null
  width?: number | null
  depth?: number | null
  weight_unit?: string | null
  dimensions_unit?: string | null
  hs_code?: string | null
  country_of_origin?: string | null
  customs_description?: string | null
  minimum_order_quantity?: number | null
  order_multiple?: number | null
  purchase_unit?: string | null
  units_per_carton?: number | null
  track_inventory?: boolean
  preorderable?: boolean
  preorder_ships_at?: string | null
  backorder_limit?: number | null
  total_on_hand?: number | null
  available_stock?: number | null
  option_values?: Array<{ id: string; name: string; option_type_name: string }>
  stock_levels?: PanelStockLevel[]
  /** Marketplace configuration; a seller's serializer leaves these out. */
  tax_category_id?: string | null
  delivery_profile_id?: string | null
}

export interface PanelProduct {
  id: string
  name: string
  slug?: string
  status?: string
  description?: string | null
  description_html?: string | null
  meta_title?: string | null
  meta_description?: string | null
  meta_keywords?: string | null
  product_type_id?: string | null
  variant_count?: number
  /**
   * Either shape: the operator's serializer expands the records, a seller's
   * answers plain ids. The mapper reads whichever it was given.
   */
  category_ids?: string[]
  collection_ids?: string[]
  categories?: Array<{ id: string; name?: string }>
  collections?: Array<{ id: string; name?: string; automatic?: boolean }>
  tags?: string[]
  metadata?: Record<string, unknown> | null
  default_variant_id?: string
  price?: { amount?: string | null; currency?: string | null } | null
  variants?: PanelVariant[]
  default_variant?: PanelVariant
  media?: PanelMedia[]
  custom_fields?: Array<{ id?: string; custom_field_definition_id: string; value?: unknown }>
  /** Operator-only surfaces; absent on a seller's serializer. */
  product_publications?: Array<{
    id?: string
    channel_id: string
    published_at?: string | null
    unpublished_at?: string | null
  }>
  tax_category_id?: string | null
  /** Both panels: a seller picks a profile from the marketplace's list. */
  delivery_profile_id?: string | null
}

/**
 * One shelf's worth of a variant — the count and where it sits, which is all
 * the form reads.
 */
export interface PanelStockLevel {
  id?: string
  stock_location_id: string | null
  stock_location_name?: string | null
  stock_location?: { id?: string; name?: string | null } | null
  count_on_hand: number
  backorderable: boolean
}
