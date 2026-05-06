// Request parameter types for Admin API endpoints
// Based on the Admin API OpenAPI specification

export interface StoreUpdateParams {
  name?: string
  preferred_admin_locale?: string
  preferred_timezone?: string
  preferred_weight_unit?: string
  preferred_unit_system?: string
}

export interface OptionTypeCreateParams {
  name: string
  presentation: string
  position?: number
  filterable?: boolean
  option_values?: Array<{
    name?: string
    presentation?: string
    position?: number
  }>
}

export interface OptionTypeUpdateParams {
  name?: string
  presentation?: string
  position?: number
  filterable?: boolean
  option_values?: Array<{
    id?: string
    name?: string
    presentation?: string
    position?: number
  }>
}

export interface LineItemCreateParams {
  variant_id: string
  quantity?: number
}

export interface LineItemUpdateParams {
  quantity?: number
}

export interface PaymentCreateParams {
  payment_method_id: string
  amount?: number
  source_id?: string
}

export interface RefundCreateParams {
  payment_id: string
  amount: number
  refund_reason_id?: string
}

export interface FulfillmentUpdateParams {
  tracking?: string
  selected_delivery_rate_id?: string
}

export interface AddressInputParams {
  first_name?: string
  last_name?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  country_iso?: string
  state_abbr?: string
  phone?: string
}

export interface OrderCreateParams {
  email?: string
  customer_id?: string
  user_id?: string
  use_customer_default_address?: boolean
  currency?: string
  market_id?: string
  locale?: string
  customer_note?: string
  internal_note?: string
  metadata?: Record<string, unknown>
  shipping_address?: AddressInputParams
  shipping_address_id?: string
  billing_address?: AddressInputParams
  billing_address_id?: string
  items?: Array<{
    variant_id: string
    quantity: number
    metadata?: Record<string, unknown>
  }>
  coupon_code?: string
}

export interface OrderUpdateParams {
  email?: string
  customer_id?: string
  customer_note?: string
  internal_note?: string
  ship_address?: AddressInputParams
  bill_address?: AddressInputParams
  line_items?: Array<{
    variant_id?: string
    quantity?: number
  }>
}

export interface OrderCompleteParams {
  payment_pending?: boolean
  notify_customer?: boolean
}

export interface OrderCancelParams {
  reason?: 'customer' | 'declined' | 'fraud' | 'inventory' | 'staff' | 'other' | 'expired'
  note?: string
  restock_items?: boolean
  refund_payments?: boolean
  refund_amount?: number
  notify_customer?: boolean
}

export interface OrderApproveParams {
  level?: string
  note?: string
}

export interface GiftCardApplyParams {
  code: string
}

export interface StoreCreditApplyParams {
  amount?: number
}

export interface CustomerCreateParams {
  email: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  internal_note?: string
  metadata?: Record<string, unknown>
  tags?: string[]
}

export interface CustomerUpdateParams {
  email?: string
  first_name?: string
  last_name?: string
  phone?: string
  accepts_email_marketing?: boolean
  internal_note?: string
  metadata?: Record<string, unknown>
  tags?: string[]
}

export interface CustomerAddressParams {
  firstname?: string
  lastname?: string
  first_name?: string
  last_name?: string
  address1?: string
  address2?: string
  city?: string
  zipcode?: string
  postal_code?: string
  country_id?: string
  state_id?: string
  country_iso?: string
  state_abbr?: string
  phone?: string
  company?: string
  label?: string
  is_default_billing?: boolean
  is_default_shipping?: boolean
}

export interface CustomerStoreCreditCreateParams {
  amount: number
  currency: string
  category_id: string
  memo?: string
}

export interface CustomerStoreCreditUpdateParams {
  amount?: number
  category_id?: string
  memo?: string
}

export interface DirectUploadCreateParams {
  blob: {
    filename: string
    byte_size: number
    checksum: string
    content_type: string
  }
}

export interface MediaCreateParams {
  alt?: string
  position?: number
  type?: string
  url?: string
  signed_id?: string
}

export interface MediaUpdateParams {
  alt?: string
  position?: number
}

export interface ProductCreateParams {
  name: string
  description?: string
  slug?: string
  status?: 'draft' | 'active' | 'archived'
  sku?: string
  tax_category_id?: string
  category_ids?: Array<string>
  tags?: Array<string>
  variants?: VariantCreateParams[]
}

export interface ProductUpdateParams {
  name?: string
  description?: string
  slug?: string
  status?: 'draft' | 'active' | 'archived'
  sku?: string
  tax_category_id?: string
  category_ids?: Array<string>
  tags?: Array<string>
  variants?: VariantUpdateParams[]
}

export interface CategoryCreateParams {
  name: string
  parent_id?: string
  position?: number
  description?: string
  permalink?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  hide_from_nav?: boolean
  sort_order?: string
}

export interface CategoryUpdateParams {
  name?: string
  parent_id?: string
  position?: number
  description?: string
  permalink?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  hide_from_nav?: boolean
  sort_order?: string
}

export interface VariantOptionPair {
  name: string
  value: string
}

export interface VariantPrice {
  currency: string
  amount: number
  compare_at_amount?: number
}

export interface VariantStockItem {
  stock_location_id: string
  count_on_hand: number
  backorderable?: boolean
}

export interface VariantCreateParams {
  sku?: string
  compare_at_price?: number
  cost_price?: number
  cost_currency?: string
  weight?: number
  height?: number
  width?: number
  depth?: number
  weight_unit?: string
  dimensions_unit?: string
  track_inventory?: boolean
  tax_category_id?: string
  position?: number
  barcode?: string
  options?: VariantOptionPair[]
  prices?: VariantPrice[]
  stock_items?: VariantStockItem[]
}

export interface VariantUpdateParams {
  sku?: string
  compare_at_price?: number
  cost_price?: number
  cost_currency?: string
  weight?: number
  height?: number
  width?: number
  depth?: number
  weight_unit?: string
  dimensions_unit?: string
  track_inventory?: boolean
  tax_category_id?: string
  position?: number
  barcode?: string
  options?: VariantOptionPair[]
  prices?: VariantPrice[]
  stock_items?: VariantStockItem[]
}

export interface CustomFieldCreateParams {
  custom_field_definition_id: string
  value: unknown
}

export interface CustomFieldUpdateParams {
  value: unknown
}

export interface CustomFieldDefinitionCreateParams {
  namespace?: string
  key: string
  label?: string
  field_type: string
  resource_type: string
  storefront_visible?: boolean
}

export interface CustomFieldDefinitionUpdateParams {
  namespace?: string
  key?: string
  label?: string
  field_type?: string
  storefront_visible?: boolean
}

/**
 * Owner type passed to the generic `client.customFields(ownerType, ownerId)`
 * escape hatch. The first-class six (products, variants, orders, customers,
 * categories, option_types) have dedicated `client.<resource>.customFields`
 * accessors and don't need this.
 */
export type CustomFieldOwnerType =
  | 'Spree::Product'
  | 'Spree::Variant'
  | 'Spree::Order'
  | 'Spree::User'
  | 'Spree::Category'
  | 'Spree::OptionType'
  | (string & {})
