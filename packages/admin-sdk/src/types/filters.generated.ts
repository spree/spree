// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.

import type * as Filter from '@spree/sdk-core'

export type AddressFields = Filter.TextFilters<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'first_name' | 'last_name' | 'phone' | 'postal_code' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type AdminUserFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'email' | 'first_name' | 'last_name'>
  & Filter.IdFilters<'id'>

export type AllowedOriginFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'origin'>

export type ApiKeyFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type CatalogFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>

export type CatalogOrderMinimumFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CategoryFields = Filter.BooleanFilters<'automatic'>
  & Filter.RangeFilters<'children_count' | 'depth' | 'position' | 'products_count', number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'parent_id'>
  & Filter.TextFilters<'name' | 'permalink' | 'pretty_name'>

export type ChannelFields = Filter.BooleanFilters<'active' | 'default'>
  & Filter.TextFilters<'code' | 'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'store_id'>

export type ClaimReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type CollectionFields = Filter.BooleanFilters<'automatic'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name' | 'permalink'>
  & Filter.RangeFilters<'position' | 'products_count', number>
  & Filter.EnumFilters<'sort_order', 'manual' | 'best_selling' | 'price asc' | 'price desc' | 'available_on desc' | 'available_on asc' | 'name asc' | 'name desc'>

export type CommissionLineFields = Filter.RangeFilters<'amount' | 'created_at' | 'rate' | 'tax_amount' | 'total' | 'updated_at'>
  & Filter.TextFilters<'currency'>
  & Filter.IdFilters<'id' | 'order_id'>
  & Filter.EnumFilters<'kind', 'percentage' | 'fixed'>

export type CommissionRateFields = Filter.TextFilters<'code' | 'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at' | 'value'>
  & Filter.BooleanFilters<'enabled' | 'include_shipping' | 'tax_inclusive'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'position', number>
  & Filter.EnumFilters<'kind', 'percentage' | 'fixed'>

export type CommissionRuleFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CompanyFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'parent_id'>
  & Filter.TextFilters<'name'>
  & Filter.BooleanFilters<'po_number_required'>
  & Filter.EnumFilters<'kind', 'company' | 'division'>

export type CompanyMembershipFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CouponCodeFields = Filter.TextFilters<'code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'promotion_id'>
  & Filter.EnumFilters<'state', 'unused' | 'used'>

export type CreditCardFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type CustomFieldFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CustomFieldDefinitionFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'field_type' | 'id' | 'resource_type'>
  & Filter.TextFilters<'key' | 'label' | 'namespace'>
  & Filter.BooleanFilters<'searchable' | 'sortable' | 'storefront_visible'>

export type CustomerFields = Filter.BooleanFilters<'accepts_email_marketing'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'email' | 'first_name' | 'last_name' | 'phone'>
  & Filter.IdFilters<'id'>

export type CustomerGroupFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type DeliveryFields = Filter.TextFilters<'carrier' | 'tracking_number'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'status', 'pending' | 'pre_transit' | 'in_transit' | 'out_for_delivery' | 'available_for_pickup' | 'delivered' | 'return_to_sender' | 'failure' | 'unknown'>

export type DeliveryMethodFields = Filter.BooleanFilters<'available_to_sellers' | 'storefront_visible'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.TextFilters<'name'>

export type DeliveryProfileFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>

export type DiscountFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type EmailTemplateRevisionFields = Filter.RangeFilters<'created_at'>
  & Filter.IdFilters<'id'>

export type ExportFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id' | 'type'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'format', 'csv'>

export type ExternalReferenceFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'external_id' | 'system'>
  & Filter.IdFilters<'id' | 'resource_type'>

export type FulfillmentFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'number'>

export type GiftCardFields = Filter.TextFilters<'code' | 'currency'>
  & Filter.RangeFilters<'created_at' | 'expires_at' | 'updated_at'>
  & Filter.IdFilters<'created_by_id' | 'customer_id' | 'gift_card_batch_id' | 'id'>
  & Filter.EnumFilters<'state', 'active' | 'partially_redeemed' | 'redeemed' | 'canceled'>
  & Filter.EnumFilters<'status', 'active' | 'partially_redeemed' | 'redeemed' | 'canceled'>

export type GiftCardBatchFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'prefix'>

export type ImportFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id' | 'type'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'status', 'pending' | 'mapping' | 'completed_mapping' | 'processing' | 'completed' | 'failed'>

export type ImportRowFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'row_number', number>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed'>

export type IntegrationFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type InvitationFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type LineItemFields = Filter.RangeFilters<'additional_tax_total' | 'adjustment_total' | 'cost_price' | 'created_at' | 'discount_total' | 'included_tax_total' | 'non_taxable_adjustment_total' | 'pre_tax_amount' | 'price' | 'taxable_adjustment_total' | 'updated_at'>
  & Filter.IdFilters<'id' | 'order_id' | 'tax_category_id' | 'variant_id'>
  & Filter.RangeFilters<'quantity', number>

export type MarketFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'default_locale' | 'name'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'position', number>

export type MediaFields = Filter.TextFilters<'alt'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'position', number>
  & Filter.EnumFilters<'media_type', 'image' | 'video' | 'external_video'>

export type OptionTypeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'label' | 'name'>
  & Filter.RangeFilters<'position', number>
  & Filter.EnumFilters<'kind', 'dropdown' | 'color_swatch' | 'buttons'>

export type OptionValueFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'label' | 'name'>
  & Filter.RangeFilters<'position', number>

export type OrderFields = Filter.IdFilters<'channel_id' | 'customer_id' | 'id' | 'order_group_id' | 'seller_id'>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'delivery_total' | 'item_total' | 'total' | 'updated_at'>
  & Filter.BooleanFilters<'considered_risky'>
  & Filter.TextFilters<'coupon_code' | 'currency' | 'email' | 'number' | 'po_number'>
  & Filter.RangeFilters<'total_quantity', number>
  & Filter.EnumFilters<'fulfillment_status', 'backorder' | 'canceled' | 'partial' | 'unfulfilled' | 'fulfilled' | 'delivered' | 'pending' | 'ready' | 'shipped'>
  & Filter.EnumFilters<'payment_state', 'none' | 'authorized' | 'partially_paid' | 'paid' | 'partially_refunded' | 'refunded' | 'overcharged' | 'voided' | 'balance_due' | 'credit_owed' | 'failed' | 'void'>
  & Filter.EnumFilters<'payment_status', 'none' | 'authorized' | 'partially_paid' | 'paid' | 'partially_refunded' | 'refunded' | 'overcharged' | 'voided' | 'balance_due' | 'credit_owed' | 'failed' | 'void'>
  & Filter.EnumFilters<'shipment_state', 'backorder' | 'canceled' | 'partial' | 'unfulfilled' | 'fulfilled' | 'delivered' | 'pending' | 'ready' | 'shipped'>
  & Filter.EnumFilters<'status', 'draft' | 'placed' | 'canceled'>

export type OrderCancellationReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type OrderGroupFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'email' | 'number'>
  & Filter.IdFilters<'id'>

export type OrderRoutingRuleFields = Filter.BooleanFilters<'active'>
  & Filter.IdFilters<'channel_id' | 'id' | 'store_id' | 'type'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.RangeFilters<'position', number>

export type PackageTypeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.BooleanFilters<'default'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.TextFilters<'name'>
  & Filter.EnumFilters<'kind', 'box' | 'envelope' | 'carton' | 'pallet' | 'container'>

export type PaymentFields = Filter.RangeFilters<'amount' | 'created_at' | 'updated_at'>
  & Filter.TextFilters<'avs_response' | 'cvv_response_code' | 'cvv_response_message' | 'response_code'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'state', 'checkout' | 'processing' | 'pending' | 'completed' | 'failed' | 'void' | 'invalid'>
  & Filter.EnumFilters<'status', 'checkout' | 'processing' | 'pending' | 'completed' | 'failed' | 'void' | 'invalid'>

export type PaymentMethodFields = Filter.BooleanFilters<'active' | 'storefront_visible'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'type'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>

export type PolicyFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'owner_id' | 'owner_type'>
  & Filter.TextFilters<'name'>

export type PriceFields = Filter.RangeFilters<'amount' | 'compare_at_amount' | 'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency'>
  & Filter.IdFilters<'id' | 'price_list_id' | 'variant_id'>
  & Filter.RangeFilters<'min_quantity', number>

export type PriceListFields = Filter.IdFilters<'catalog_id' | 'id'>
  & Filter.RangeFilters<'created_at' | 'ends_at' | 'starts_at' | 'updated_at'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>
  & Filter.EnumFilters<'match_policy', 'all' | 'any'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'inactive' | 'scheduled'>

export type ProductFields = Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'price' | 'updated_at'>
  & Filter.TextFilters<'description' | 'name' | 'slug'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'archived' | 'proposed' | 'rejected'>

export type ProductCategoryFields = Filter.IdFilters<'category_id' | 'id' | 'product_id'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.RangeFilters<'position', number>

export type ProductTypeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type PromotionFields = Filter.TextFilters<'code' | 'name' | 'path'>
  & Filter.RangeFilters<'created_at' | 'expires_at' | 'starts_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'promotion_category_id'>
  & Filter.EnumFilters<'kind', 'coupon_code' | 'automatic'>

export type PromotionActionFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'position', number>

export type PromotionRuleFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type PurchaseOrderFields = Filter.RangeFilters<'cancel_by' | 'closed_short_at' | 'created_at' | 'expected_at' | 'ordered_at' | 'received_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'number' | 'reference'>
  & Filter.IdFilters<'destination_location_id' | 'id' | 'supplier_id'>
  & Filter.EnumFilters<'status', 'draft' | 'ordered' | 'partially_received' | 'received' | 'over_received' | 'canceled'>

export type PurchaseOrderItemFields = Filter.RangeFilters<'created_at' | 'unit_cost' | 'updated_at'>
  & Filter.IdFilters<'id' | 'variant_id'>
  & Filter.RangeFilters<'quantity_ordered' | 'quantity_received' | 'quantity_rejected', number>

export type RefundFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type RefundReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type ReturnReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type RoleFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type SellerFields = Filter.TextFilters<'contact_email' | 'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'status', 'pending' | 'invited' | 'canceled' | 'onboarding' | 'ready_for_review' | 'approved' | 'rejected' | 'suspended'>

export type SellerRequirementFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>

export type ShippingLabelFields = Filter.TextFilters<'carrier' | 'tracking_number'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'source', 'purchased' | 'uploaded'>
  & Filter.EnumFilters<'status', 'purchased' | 'refund_requested' | 'refunded'>

export type StockLevelFields = Filter.RangeFilters<'allocated_count' | 'count_on_hand' | 'incoming_count' | 'reserved_count', number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'stock_location_id' | 'variant_id'>

export type StockLocationFields = Filter.BooleanFilters<'active' | 'default' | 'pickup_enabled' | 'returns_enabled'>
  & Filter.TextFilters<'country_code' | 'kind' | 'name' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>

export type StockMovementFields = Filter.RangeFilters<'created_at' | 'unit_cost' | 'updated_at'>
  & Filter.IdFilters<'exchange_id' | 'fulfillment_id' | 'id' | 'order_id' | 'purchase_order_id' | 'return_id' | 'stock_item_id' | 'stock_level_id' | 'stock_receipt_id' | 'stock_transfer_id'>
  & Filter.RangeFilters<'quantity', number>
  & Filter.TextFilters<'reason'>
  & Filter.EnumFilters<'kind', 'received' | 'allocated' | 'shipped' | 'released' | 'adjusted'>

export type StockReceiptFields = Filter.RangeFilters<'created_at' | 'received_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'receivable_id' | 'receivable_type' | 'received_by_id' | 'received_by_type'>
  & Filter.TextFilters<'number' | 'reference'>

export type StockTransferFields = Filter.RangeFilters<'closed_short_at' | 'created_at' | 'received_at' | 'shipped_at' | 'updated_at'>
  & Filter.IdFilters<'destination_location_id' | 'id' | 'source_location_id'>
  & Filter.TextFilters<'number' | 'reference'>
  & Filter.EnumFilters<'status', 'draft' | 'ready_to_ship' | 'in_transit' | 'partially_received' | 'received' | 'over_received' | 'canceled'>

export type StockTransferItemFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'variant_id'>
  & Filter.RangeFilters<'quantity_received' | 'quantity_rejected' | 'quantity_shipped', number>

export type StoreFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type StoreCreditFields = Filter.RangeFilters<'amount' | 'created_at' | 'updated_at'>
  & Filter.IdFilters<'created_by_id' | 'customer_id' | 'id'>
  & Filter.TextFilters<'currency' | 'memo'>

export type StoreCreditEventFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type SupplierFields = Filter.TextFilters<'city' | 'contact_name' | 'country_code' | 'email' | 'name' | 'phone'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type TagFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type TaxCategoryFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.BooleanFilters<'is_default'>
  & Filter.TextFilters<'name' | 'tax_code'>

export type TaxExemptionCertificateFields = Filter.TextFilters<'certificate_number' | 'reason_code'>
  & Filter.RangeFilters<'created_at' | 'expires_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'status', 'pending' | 'verified' | 'expired' | 'revoked'>

export type TaxIdentifierFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type TaxLineFields = Filter.TextFilters<'country_code' | 'provider_id' | 'state_code' | 'taxability_reason'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.BooleanFilters<'included'>

export type TaxRateFields = Filter.RangeFilters<'amount' | 'created_at' | 'rate' | 'updated_at'>
  & Filter.TextFilters<'country_code' | 'name' | 'state_code'>
  & Filter.IdFilters<'id' | 'tax_category_id'>
  & Filter.BooleanFilters<'included_in_price'>

export type VariantFields = Filter.IdFilters<'carton_package_type_id' | 'id' | 'product_id'>
  & Filter.RangeFilters<'carton_weight' | 'cost_price' | 'created_at' | 'deleted_at' | 'depth' | 'discontinue_on' | 'height' | 'updated_at' | 'weight' | 'width'>
  & Filter.RangeFilters<'cartons_per_pallet' | 'minimum_order_quantity' | 'order_multiple' | 'position' | 'units_per_carton', number>
  & Filter.TextFilters<'cost_currency' | 'country_of_origin' | 'hs_code' | 'sku'>
  & Filter.BooleanFilters<'track_inventory'>
  & Filter.EnumFilters<'purchase_unit', 'unit' | 'carton'>

export type WebhookDeliveryFields = Filter.RangeFilters<'created_at' | 'delivered_at' | 'updated_at'>
  & Filter.TextFilters<'event_name'>
  & Filter.RangeFilters<'execution_time' | 'response_code', number>
  & Filter.IdFilters<'id'>
  & Filter.BooleanFilters<'success'>

export type WebhookEndpointFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name' | 'url'>

/**
 * Filters your app adds to Address lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface AddressFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface AddressFilterExtensions {}

/** Sort fields your app adds to Address lists, as keys: `{ erp_id: true }`. */
export interface AddressSortExtensions {}

export type AddressFilters = AddressFields
  & Filter.OrFilters
  & AddressFilterExtensions

export type AddressSort = Filter.SortKey<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'created_at' | 'first_name' | 'id' | 'last_name' | 'phone' | 'postal_code' | 'state_code' | 'updated_at' | (keyof AddressSortExtensions & string)>

/**
 * Filters your app adds to AdminUser lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface AdminUserFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface AdminUserFilterExtensions {}

/** Sort fields your app adds to AdminUser lists, as keys: `{ erp_id: true }`. */
export interface AdminUserSortExtensions {}

export type AdminUserFilters = AdminUserFields
  & Filter.Prefixed<'spree_roles_', RoleFields>
  & Filter.OrFilters
  & AdminUserFilterExtensions

export type AdminUserSort = Filter.SortKey<'created_at' | 'email' | 'first_name' | 'id' | 'last_name' | 'updated_at' | (keyof AdminUserSortExtensions & string)>

/**
 * Filters your app adds to AllowedOrigin lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface AllowedOriginFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface AllowedOriginFilterExtensions {}

/** Sort fields your app adds to AllowedOrigin lists, as keys: `{ erp_id: true }`. */
export interface AllowedOriginSortExtensions {}

export type AllowedOriginFilters = AllowedOriginFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & AllowedOriginFilterExtensions

export type AllowedOriginSort = Filter.SortKey<'created_at' | 'id' | 'origin' | 'updated_at' | (keyof AllowedOriginSortExtensions & string)>

/**
 * Filters your app adds to ApiKey lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ApiKeyFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ApiKeyFilterExtensions {}

/** Sort fields your app adds to ApiKey lists, as keys: `{ erp_id: true }`. */
export interface ApiKeySortExtensions {}

export type ApiKeyFilters = ApiKeyFields
  & Filter.OrFilters
  & ApiKeyFilterExtensions

export type ApiKeySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof ApiKeySortExtensions & string)>

/**
 * Filters your app adds to Catalog lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CatalogFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CatalogFilterExtensions {}

/** Sort fields your app adds to Catalog lists, as keys: `{ erp_id: true }`. */
export interface CatalogSortExtensions {}

export type CatalogFilters = CatalogFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & CatalogFilterExtensions

export type CatalogSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'position' | 'updated_at' | (keyof CatalogSortExtensions & string)>

/**
 * Filters your app adds to CatalogOrderMinimum lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CatalogOrderMinimumFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CatalogOrderMinimumFilterExtensions {}

/** Sort fields your app adds to CatalogOrderMinimum lists, as keys: `{ erp_id: true }`. */
export interface CatalogOrderMinimumSortExtensions {}

export type CatalogOrderMinimumFilters = CatalogOrderMinimumFields
  & Filter.OrFilters
  & CatalogOrderMinimumFilterExtensions

export type CatalogOrderMinimumSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof CatalogOrderMinimumSortExtensions & string)>

/**
 * Filters your app adds to Category lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CategoryFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CategoryFilterExtensions {}

/** Sort fields your app adds to Category lists, as keys: `{ erp_id: true }`. */
export interface CategorySortExtensions {}

export type CategoryFilters = CategoryFields
  & Filter.Prefixed<'parent_', CategoryFields & Filter.Prefixed<'parent_', CategoryFields>>
  & {
    search?: string
  }
  & Filter.OrFilters
  & CategoryFilterExtensions

export type CategorySort = Filter.SortKey<'automatic' | 'children_count' | 'created_at' | 'depth' | 'id' | 'name' | 'parent_id' | 'permalink' | 'position' | 'pretty_name' | 'products_count' | 'updated_at' | (keyof CategorySortExtensions & string)>

/**
 * Filters your app adds to Channel lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ChannelFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ChannelFilterExtensions {}

/** Sort fields your app adds to Channel lists, as keys: `{ erp_id: true }`. */
export interface ChannelSortExtensions {}

export type ChannelFilters = ChannelFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & ChannelFilterExtensions

export type ChannelSort = Filter.SortKey<'active' | 'code' | 'created_at' | 'default' | 'id' | 'name' | 'store_id' | 'updated_at' | (keyof ChannelSortExtensions & string)>

/**
 * Filters your app adds to ClaimReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ClaimReasonFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ClaimReasonFilterExtensions {}

/** Sort fields your app adds to ClaimReason lists, as keys: `{ erp_id: true }`. */
export interface ClaimReasonSortExtensions {}

export type ClaimReasonFilters = ClaimReasonFields
  & Filter.OrFilters
  & ClaimReasonFilterExtensions

export type ClaimReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | (keyof ClaimReasonSortExtensions & string)>

/**
 * Filters your app adds to Collection lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CollectionFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CollectionFilterExtensions {}

/** Sort fields your app adds to Collection lists, as keys: `{ erp_id: true }`. */
export interface CollectionSortExtensions {}

export type CollectionFilters = CollectionFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & CollectionFilterExtensions

export type CollectionSort = Filter.SortKey<'automatic' | 'created_at' | 'id' | 'name' | 'permalink' | 'position' | 'products_count' | 'sort_order' | 'updated_at' | (keyof CollectionSortExtensions & string)>

/**
 * Filters your app adds to CommissionLine lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CommissionLineFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CommissionLineFilterExtensions {}

/** Sort fields your app adds to CommissionLine lists, as keys: `{ erp_id: true }`. */
export interface CommissionLineSortExtensions {}

export type CommissionLineFilters = CommissionLineFields
  & Filter.Prefixed<'commission_rate_', CommissionRateFields & Filter.Prefixed<'commission_rules_', CommissionRuleFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & CommissionLineFilterExtensions

export type CommissionLineSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'kind' | 'order_id' | 'rate' | 'tax_amount' | 'total' | 'updated_at' | (keyof CommissionLineSortExtensions & string)>

/**
 * Filters your app adds to CommissionRate lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CommissionRateFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CommissionRateFilterExtensions {}

/** Sort fields your app adds to CommissionRate lists, as keys: `{ erp_id: true }`. */
export interface CommissionRateSortExtensions {}

export type CommissionRateFilters = CommissionRateFields
  & Filter.Prefixed<'commission_rules_', CommissionRuleFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & CommissionRateFilterExtensions

export type CommissionRateSort = Filter.SortKey<'code' | 'created_at' | 'enabled' | 'id' | 'include_shipping' | 'kind' | 'name' | 'position' | 'tax_inclusive' | 'updated_at' | 'value' | (keyof CommissionRateSortExtensions & string)>

/**
 * Filters your app adds to Company lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CompanyFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CompanyFilterExtensions {}

/** Sort fields your app adds to Company lists, as keys: `{ erp_id: true }`. */
export interface CompanySortExtensions {}

export type CompanyFilters = CompanyFields
  & Filter.Prefixed<'children_', CompanyFields & Filter.Prefixed<'children_', CompanyFields> & Filter.Prefixed<'external_references_', ExternalReferenceFields> & Filter.Prefixed<'memberships_', CompanyMembershipFields> & Filter.Prefixed<'parent_', CompanyFields>>
  & Filter.Prefixed<'external_references_', ExternalReferenceFields>
  & Filter.Prefixed<'memberships_', CompanyMembershipFields>
  & Filter.Prefixed<'parent_', CompanyFields & Filter.Prefixed<'children_', CompanyFields> & Filter.Prefixed<'external_references_', ExternalReferenceFields> & Filter.Prefixed<'memberships_', CompanyMembershipFields> & Filter.Prefixed<'parent_', CompanyFields>>
  & {
    search?: string
  }
  & Filter.OrFilters
  & CompanyFilterExtensions

export type CompanySort = Filter.SortKey<'created_at' | 'id' | 'kind' | 'name' | 'parent_id' | 'po_number_required' | 'updated_at' | (keyof CompanySortExtensions & string)>

/**
 * Filters your app adds to CompanyMembership lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CompanyMembershipFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CompanyMembershipFilterExtensions {}

/** Sort fields your app adds to CompanyMembership lists, as keys: `{ erp_id: true }`. */
export interface CompanyMembershipSortExtensions {}

export type CompanyMembershipFilters = CompanyMembershipFields
  & Filter.OrFilters
  & CompanyMembershipFilterExtensions

export type CompanyMembershipSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof CompanyMembershipSortExtensions & string)>

/**
 * Filters your app adds to CouponCode lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CouponCodeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CouponCodeFilterExtensions {}

/** Sort fields your app adds to CouponCode lists, as keys: `{ erp_id: true }`. */
export interface CouponCodeSortExtensions {}

export type CouponCodeFilters = CouponCodeFields
  & Filter.Prefixed<'promotion_', PromotionFields & Filter.Prefixed<'coupon_codes_', CouponCodeFields>>
  & Filter.OrFilters
  & CouponCodeFilterExtensions

export type CouponCodeSort = Filter.SortKey<'code' | 'created_at' | 'id' | 'promotion_id' | 'state' | 'updated_at' | (keyof CouponCodeSortExtensions & string)>

/**
 * Filters your app adds to CreditCard lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CreditCardFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CreditCardFilterExtensions {}

/** Sort fields your app adds to CreditCard lists, as keys: `{ erp_id: true }`. */
export interface CreditCardSortExtensions {}

export type CreditCardFilters = CreditCardFields
  & Filter.OrFilters
  & CreditCardFilterExtensions

export type CreditCardSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof CreditCardSortExtensions & string)>

/**
 * Filters your app adds to Customer lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CustomerFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CustomerFilterExtensions {}

/** Sort fields your app adds to Customer lists, as keys: `{ erp_id: true }`. */
export interface CustomerSortExtensions {}

export type CustomerFilters = CustomerFields
  & Filter.Prefixed<'addresses_', AddressFields>
  & Filter.Prefixed<'bill_address_', AddressFields>
  & Filter.Prefixed<'customer_groups_', CustomerGroupFields>
  & Filter.Prefixed<'orders_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'ship_address_', AddressFields>
  & Filter.Prefixed<'spree_roles_', RoleFields>
  & Filter.Prefixed<'tags_', TagFields>
  & {
    anonymized?: boolean
    search?: string
    with_min_total_spent?: string
    with_standing_for_company?: string | string[]
  }
  & Filter.OrFilters
  & CustomerFilterExtensions

export type CustomerSort = Filter.SortKey<'accepts_email_marketing' | 'created_at' | 'email' | 'first_name' | 'id' | 'last_name' | 'phone' | 'updated_at' | (keyof CustomerSortExtensions & string)>

/**
 * Filters your app adds to CustomerGroup lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CustomerGroupFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CustomerGroupFilterExtensions {}

/** Sort fields your app adds to CustomerGroup lists, as keys: `{ erp_id: true }`. */
export interface CustomerGroupSortExtensions {}

export type CustomerGroupFilters = CustomerGroupFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & CustomerGroupFilterExtensions

export type CustomerGroupSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof CustomerGroupSortExtensions & string)>

/**
 * Filters your app adds to CustomField lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CustomFieldFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CustomFieldFilterExtensions {}

/** Sort fields your app adds to CustomField lists, as keys: `{ erp_id: true }`. */
export interface CustomFieldSortExtensions {}

export type CustomFieldFilters = CustomFieldFields
  & Filter.OrFilters
  & CustomFieldFilterExtensions

export type CustomFieldSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof CustomFieldSortExtensions & string)>

/**
 * Filters your app adds to CustomFieldDefinition lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface CustomFieldDefinitionFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CustomFieldDefinitionFilterExtensions {}

/** Sort fields your app adds to CustomFieldDefinition lists, as keys: `{ erp_id: true }`. */
export interface CustomFieldDefinitionSortExtensions {}

export type CustomFieldDefinitionFilters = CustomFieldDefinitionFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & CustomFieldDefinitionFilterExtensions

export type CustomFieldDefinitionSort = Filter.SortKey<'created_at' | 'field_type' | 'id' | 'key' | 'label' | 'namespace' | 'resource_type' | 'searchable' | 'sortable' | 'storefront_visible' | 'updated_at' | (keyof CustomFieldDefinitionSortExtensions & string)>

/**
 * Filters your app adds to Delivery lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface DeliveryFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DeliveryFilterExtensions {}

/** Sort fields your app adds to Delivery lists, as keys: `{ erp_id: true }`. */
export interface DeliverySortExtensions {}

export type DeliveryFilters = DeliveryFields
  & Filter.OrFilters
  & DeliveryFilterExtensions

export type DeliverySort = Filter.SortKey<'carrier' | 'created_at' | 'id' | 'status' | 'tracking_number' | 'updated_at' | (keyof DeliverySortExtensions & string)>

/**
 * Filters your app adds to DeliveryMethod lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface DeliveryMethodFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DeliveryMethodFilterExtensions {}

/** Sort fields your app adds to DeliveryMethod lists, as keys: `{ erp_id: true }`. */
export interface DeliveryMethodSortExtensions {}

export type DeliveryMethodFilters = DeliveryMethodFields
  & Filter.Prefixed<'seller_', SellerFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & DeliveryMethodFilterExtensions

export type DeliveryMethodSort = Filter.SortKey<'available_to_sellers' | 'created_at' | 'id' | 'name' | 'seller_id' | 'storefront_visible' | 'updated_at' | (keyof DeliveryMethodSortExtensions & string)>

/**
 * Filters your app adds to DeliveryProfile lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface DeliveryProfileFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DeliveryProfileFilterExtensions {}

/** Sort fields your app adds to DeliveryProfile lists, as keys: `{ erp_id: true }`. */
export interface DeliveryProfileSortExtensions {}

export type DeliveryProfileFilters = DeliveryProfileFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & DeliveryProfileFilterExtensions

export type DeliveryProfileSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'position' | 'updated_at' | (keyof DeliveryProfileSortExtensions & string)>

/**
 * Filters your app adds to Discount lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface DiscountFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DiscountFilterExtensions {}

/** Sort fields your app adds to Discount lists, as keys: `{ erp_id: true }`. */
export interface DiscountSortExtensions {}

export type DiscountFilters = DiscountFields
  & Filter.OrFilters
  & DiscountFilterExtensions

export type DiscountSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof DiscountSortExtensions & string)>

/**
 * Filters your app adds to EmailTemplateRevision lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface EmailTemplateRevisionFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface EmailTemplateRevisionFilterExtensions {}

/** Sort fields your app adds to EmailTemplateRevision lists, as keys: `{ erp_id: true }`. */
export interface EmailTemplateRevisionSortExtensions {}

export type EmailTemplateRevisionFilters = EmailTemplateRevisionFields
  & Filter.OrFilters
  & EmailTemplateRevisionFilterExtensions

export type EmailTemplateRevisionSort = Filter.SortKey<'created_at' | 'id' | (keyof EmailTemplateRevisionSortExtensions & string)>

/**
 * Filters your app adds to Export lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ExportFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ExportFilterExtensions {}

/** Sort fields your app adds to Export lists, as keys: `{ erp_id: true }`. */
export interface ExportSortExtensions {}

export type ExportFilters = ExportFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & ExportFilterExtensions

export type ExportSort = Filter.SortKey<'created_at' | 'format' | 'id' | 'number' | 'seller_id' | 'type' | 'updated_at' | (keyof ExportSortExtensions & string)>

/**
 * Filters your app adds to Fulfillment lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface FulfillmentFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface FulfillmentFilterExtensions {}

/** Sort fields your app adds to Fulfillment lists, as keys: `{ erp_id: true }`. */
export interface FulfillmentSortExtensions {}

export type FulfillmentFilters = FulfillmentFields
  & Filter.OrFilters
  & FulfillmentFilterExtensions

export type FulfillmentSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'updated_at' | (keyof FulfillmentSortExtensions & string)>

/**
 * Filters your app adds to GiftCard lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface GiftCardFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface GiftCardFilterExtensions {}

/** Sort fields your app adds to GiftCard lists, as keys: `{ erp_id: true }`. */
export interface GiftCardSortExtensions {}

export type GiftCardFilters = GiftCardFields
  & Filter.Prefixed<'batch_', GiftCardBatchFields>
  & Filter.Prefixed<'customers_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'orders_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'users_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & {
    active?: boolean
    expired?: boolean
    partially_redeemed?: boolean
    redeemed?: boolean
    search?: string
  }
  & Filter.OrFilters
  & GiftCardFilterExtensions

export type GiftCardSort = Filter.SortKey<'code' | 'created_at' | 'created_by_id' | 'currency' | 'customer_id' | 'expires_at' | 'gift_card_batch_id' | 'id' | 'state' | 'status' | 'updated_at' | (keyof GiftCardSortExtensions & string)>

/**
 * Filters your app adds to GiftCardBatch lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface GiftCardBatchFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface GiftCardBatchFilterExtensions {}

/** Sort fields your app adds to GiftCardBatch lists, as keys: `{ erp_id: true }`. */
export interface GiftCardBatchSortExtensions {}

export type GiftCardBatchFilters = GiftCardBatchFields
  & Filter.OrFilters
  & GiftCardBatchFilterExtensions

export type GiftCardBatchSort = Filter.SortKey<'created_at' | 'id' | 'prefix' | 'updated_at' | (keyof GiftCardBatchSortExtensions & string)>

/**
 * Filters your app adds to Import lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ImportFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ImportFilterExtensions {}

/** Sort fields your app adds to Import lists, as keys: `{ erp_id: true }`. */
export interface ImportSortExtensions {}

export type ImportFilters = ImportFields
  & Filter.Prefixed<'seller_', SellerFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & ImportFilterExtensions

export type ImportSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'seller_id' | 'status' | 'type' | 'updated_at' | (keyof ImportSortExtensions & string)>

/**
 * Filters your app adds to ImportRow lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ImportRowFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ImportRowFilterExtensions {}

/** Sort fields your app adds to ImportRow lists, as keys: `{ erp_id: true }`. */
export interface ImportRowSortExtensions {}

export type ImportRowFilters = ImportRowFields
  & Filter.OrFilters
  & ImportRowFilterExtensions

export type ImportRowSort = Filter.SortKey<'created_at' | 'id' | 'row_number' | 'status' | 'updated_at' | (keyof ImportRowSortExtensions & string)>

/**
 * Filters your app adds to Integration lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface IntegrationFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface IntegrationFilterExtensions {}

/** Sort fields your app adds to Integration lists, as keys: `{ erp_id: true }`. */
export interface IntegrationSortExtensions {}

export type IntegrationFilters = IntegrationFields
  & Filter.OrFilters
  & IntegrationFilterExtensions

export type IntegrationSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof IntegrationSortExtensions & string)>

/**
 * Filters your app adds to Invitation lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface InvitationFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface InvitationFilterExtensions {}

/** Sort fields your app adds to Invitation lists, as keys: `{ erp_id: true }`. */
export interface InvitationSortExtensions {}

export type InvitationFilters = InvitationFields
  & Filter.OrFilters
  & InvitationFilterExtensions

export type InvitationSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof InvitationSortExtensions & string)>

/**
 * Filters your app adds to LineItem lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface LineItemFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface LineItemFilterExtensions {}

/** Sort fields your app adds to LineItem lists, as keys: `{ erp_id: true }`. */
export interface LineItemSortExtensions {}

export type LineItemFilters = LineItemFields
  & Filter.Prefixed<'order_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'tax_category_', TaxCategoryFields>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.OrFilters
  & LineItemFilterExtensions

export type LineItemSort = Filter.SortKey<'additional_tax_total' | 'adjustment_total' | 'cost_price' | 'created_at' | 'discount_total' | 'id' | 'included_tax_total' | 'non_taxable_adjustment_total' | 'order_id' | 'pre_tax_amount' | 'price' | 'quantity' | 'tax_category_id' | 'taxable_adjustment_total' | 'updated_at' | 'variant_id' | (keyof LineItemSortExtensions & string)>

/**
 * Filters your app adds to Market lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface MarketFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface MarketFilterExtensions {}

/** Sort fields your app adds to Market lists, as keys: `{ erp_id: true }`. */
export interface MarketSortExtensions {}

export type MarketFilters = MarketFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & MarketFilterExtensions

export type MarketSort = Filter.SortKey<'created_at' | 'currency' | 'default_locale' | 'id' | 'name' | 'position' | 'updated_at' | (keyof MarketSortExtensions & string)>

/**
 * Filters your app adds to Media lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface MediaFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface MediaFilterExtensions {}

/** Sort fields your app adds to Media lists, as keys: `{ erp_id: true }`. */
export interface MediaSortExtensions {}

export type MediaFilters = MediaFields
  & {
    attached?: boolean
    filename_cont?: string
    unattached?: boolean
  }
  & Filter.OrFilters
  & MediaFilterExtensions

export type MediaSort = Filter.SortKey<'alt' | 'created_at' | 'id' | 'media_type' | 'position' | 'updated_at' | (keyof MediaSortExtensions & string)>

/**
 * Filters your app adds to OptionType lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface OptionTypeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface OptionTypeFilterExtensions {}

/** Sort fields your app adds to OptionType lists, as keys: `{ erp_id: true }`. */
export interface OptionTypeSortExtensions {}

export type OptionTypeFilters = OptionTypeFields
  & {
    search?: string
    search_by_name?: string
  }
  & Filter.OrFilters
  & OptionTypeFilterExtensions

export type OptionTypeSort = Filter.SortKey<'created_at' | 'id' | 'kind' | 'label' | 'name' | 'position' | 'updated_at' | (keyof OptionTypeSortExtensions & string)>

/**
 * Filters your app adds to Order lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface OrderFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface OrderFilterExtensions {}

/** Sort fields your app adds to Order lists, as keys: `{ erp_id: true }`. */
export interface OrderSortExtensions {}

export type OrderFilters = OrderFields
  & Filter.Prefixed<'bill_address_', AddressFields>
  & Filter.Prefixed<'channel_', ChannelFields>
  & Filter.Prefixed<'customer_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'fulfillments_', FulfillmentFields>
  & Filter.Prefixed<'line_items_', LineItemFields & Filter.Prefixed<'order_', OrderFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields> & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'order_group_', OrderGroupFields & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'orders_', OrderFields>>
  & Filter.Prefixed<'promotions_', PromotionFields & Filter.Prefixed<'coupon_codes_', CouponCodeFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.Prefixed<'ship_address_', AddressFields>
  & Filter.Prefixed<'shipments_', FulfillmentFields>
  & Filter.Prefixed<'store_', StoreFields>
  & Filter.Prefixed<'tags_', TagFields>
  & {
    complete?: boolean
    incomplete?: boolean
    partially_refunded?: boolean
    refunded?: boolean
    search?: string
  }
  & Filter.OrFilters
  & OrderFilterExtensions

export type OrderSort = Filter.SortKey<'channel_id' | 'completed_at' | 'considered_risky' | 'coupon_code' | 'created_at' | 'currency' | 'customer_id' | 'delivery_total' | 'email' | 'fulfillment_status' | 'id' | 'item_total' | 'number' | 'order_group_id' | 'payment_state' | 'payment_status' | 'po_number' | 'seller_id' | 'shipment_state' | 'status' | 'total' | 'total_quantity' | 'updated_at' | (keyof OrderSortExtensions & string)>

/**
 * Filters your app adds to OrderCancellationReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface OrderCancellationReasonFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface OrderCancellationReasonFilterExtensions {}

/** Sort fields your app adds to OrderCancellationReason lists, as keys: `{ erp_id: true }`. */
export interface OrderCancellationReasonSortExtensions {}

export type OrderCancellationReasonFilters = OrderCancellationReasonFields
  & Filter.OrFilters
  & OrderCancellationReasonFilterExtensions

export type OrderCancellationReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | (keyof OrderCancellationReasonSortExtensions & string)>

/**
 * Filters your app adds to OrderRoutingRule lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface OrderRoutingRuleFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface OrderRoutingRuleFilterExtensions {}

/** Sort fields your app adds to OrderRoutingRule lists, as keys: `{ erp_id: true }`. */
export interface OrderRoutingRuleSortExtensions {}

export type OrderRoutingRuleFilters = OrderRoutingRuleFields
  & Filter.OrFilters
  & OrderRoutingRuleFilterExtensions

export type OrderRoutingRuleSort = Filter.SortKey<'active' | 'channel_id' | 'created_at' | 'id' | 'position' | 'store_id' | 'type' | 'updated_at' | (keyof OrderRoutingRuleSortExtensions & string)>

/**
 * Filters your app adds to PackageType lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PackageTypeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PackageTypeFilterExtensions {}

/** Sort fields your app adds to PackageType lists, as keys: `{ erp_id: true }`. */
export interface PackageTypeSortExtensions {}

export type PackageTypeFilters = PackageTypeFields
  & Filter.Prefixed<'seller_', SellerFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & PackageTypeFilterExtensions

export type PackageTypeSort = Filter.SortKey<'created_at' | 'default' | 'id' | 'kind' | 'name' | 'seller_id' | 'updated_at' | (keyof PackageTypeSortExtensions & string)>

/**
 * Filters your app adds to Payment lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PaymentFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PaymentFilterExtensions {}

/** Sort fields your app adds to Payment lists, as keys: `{ erp_id: true }`. */
export interface PaymentSortExtensions {}

export type PaymentFilters = PaymentFields
  & Filter.Prefixed<'order_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'payment_method_', PaymentMethodFields>
  & Filter.OrFilters
  & PaymentFilterExtensions

export type PaymentSort = Filter.SortKey<'amount' | 'avs_response' | 'created_at' | 'cvv_response_code' | 'cvv_response_message' | 'id' | 'response_code' | 'state' | 'status' | 'updated_at' | (keyof PaymentSortExtensions & string)>

/**
 * Filters your app adds to PaymentMethod lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PaymentMethodFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PaymentMethodFilterExtensions {}

/** Sort fields your app adds to PaymentMethod lists, as keys: `{ erp_id: true }`. */
export interface PaymentMethodSortExtensions {}

export type PaymentMethodFilters = PaymentMethodFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & PaymentMethodFilterExtensions

export type PaymentMethodSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'position' | 'storefront_visible' | 'type' | 'updated_at' | (keyof PaymentMethodSortExtensions & string)>

/**
 * Filters your app adds to Policy lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PolicyFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PolicyFilterExtensions {}

/** Sort fields your app adds to Policy lists, as keys: `{ erp_id: true }`. */
export interface PolicySortExtensions {}

export type PolicyFilters = PolicyFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & PolicyFilterExtensions

export type PolicySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'owner_id' | 'owner_type' | 'updated_at' | (keyof PolicySortExtensions & string)>

/**
 * Filters your app adds to Price lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PriceFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PriceFilterExtensions {}

/** Sort fields your app adds to Price lists, as keys: `{ erp_id: true }`. */
export interface PriceSortExtensions {}

export type PriceFilters = PriceFields
  & Filter.Prefixed<'price_list_', PriceListFields>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & {
    search?: string
  }
  & Filter.OrFilters
  & PriceFilterExtensions

export type PriceSort = Filter.SortKey<'amount' | 'compare_at_amount' | 'created_at' | 'currency' | 'id' | 'min_quantity' | 'price_list_id' | 'updated_at' | 'variant_id' | (keyof PriceSortExtensions & string)>

/**
 * Filters your app adds to PriceList lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PriceListFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PriceListFilterExtensions {}

/** Sort fields your app adds to PriceList lists, as keys: `{ erp_id: true }`. */
export interface PriceListSortExtensions {}

export type PriceListFilters = PriceListFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & PriceListFilterExtensions

export type PriceListSort = Filter.SortKey<'catalog_id' | 'created_at' | 'ends_at' | 'id' | 'match_policy' | 'name' | 'position' | 'starts_at' | 'status' | 'updated_at' | (keyof PriceListSortExtensions & string)>

/**
 * Filters your app adds to Product lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ProductFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ProductFilterExtensions {}

/** Sort fields your app adds to Product lists, as keys: `{ erp_id: true }`. */
export interface ProductSortExtensions {}

export type ProductFilters = ProductFields
  & Filter.Prefixed<'categories_', CategoryFields & Filter.Prefixed<'parent_', CategoryFields>>
  & Filter.Prefixed<'channels_', ChannelFields>
  & Filter.Prefixed<'collections_', CollectionFields>
  & Filter.Prefixed<'default_variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.Prefixed<'labels_', TagFields>
  & Filter.Prefixed<'option_types_', OptionTypeFields>
  & Filter.Prefixed<'product_categories_', ProductCategoryFields>
  & Filter.Prefixed<'product_type_', ProductTypeFields & Filter.Prefixed<'option_types_', OptionTypeFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.Prefixed<'store_', StoreFields>
  & Filter.Prefixed<'tags_', TagFields>
  & Filter.Prefixed<'variants_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & {
    ascend_by_price?: boolean
    descend_by_price?: boolean
    in_categories?: string | string[]
    in_category?: string
    in_collection?: string
    in_stock?: boolean
    in_taxon?: string
    not_discontinued?: boolean
    out_of_stock?: boolean
    price_between?: [string, string]
    price_gte?: string
    price_lte?: string
    search?: string
    search_by_name?: string
    with_option_value_ids?: string | string[]
  }
  & Filter.OrFilters
  & ProductFilterExtensions

export type ProductSort = Filter.SortKey<'available_on' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'name' | 'price' | 'seller_id' | 'slug' | 'status' | 'updated_at' | (keyof ProductSortExtensions & string)>

export type ProductSearchFilters = ProductFields
  & Filter.Prefixed<'categories_', CategoryFields & Filter.Prefixed<'parent_', CategoryFields>>
  & Filter.Prefixed<'channels_', ChannelFields>
  & Filter.Prefixed<'collections_', CollectionFields>
  & Filter.Prefixed<'default_variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.Prefixed<'labels_', TagFields>
  & Filter.Prefixed<'option_types_', OptionTypeFields>
  & Filter.Prefixed<'product_categories_', ProductCategoryFields>
  & Filter.Prefixed<'product_type_', ProductTypeFields & Filter.Prefixed<'option_types_', OptionTypeFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.Prefixed<'store_', StoreFields>
  & Filter.Prefixed<'tags_', TagFields>
  & Filter.Prefixed<'variants_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & {
    ascend_by_price?: boolean
    descend_by_price?: boolean
    in_categories?: string | string[]
    in_category?: string
    in_collection?: string
    in_stock?: boolean
    in_taxon?: string
    not_discontinued?: boolean
    out_of_stock?: boolean
    price_between?: [string, string]
    price_gte?: string
    price_lte?: string
    search?: string
    search_by_name?: string
    with_option_value_ids?: string | string[]
  }
  & Filter.OrFilters
  & Filter.CustomFieldFilters
  & ProductFilterExtensions

export type ProductSearchSort = Filter.SortKey<'available_on' | 'best_selling' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'manual' | 'name' | 'price' | 'seller_id' | 'slug' | 'status' | 'updated_at' | (keyof ProductSortExtensions & string) | `cf_${string}`>

/**
 * Filters your app adds to ProductType lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ProductTypeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ProductTypeFilterExtensions {}

/** Sort fields your app adds to ProductType lists, as keys: `{ erp_id: true }`. */
export interface ProductTypeSortExtensions {}

export type ProductTypeFilters = ProductTypeFields
  & Filter.Prefixed<'option_types_', OptionTypeFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & ProductTypeFilterExtensions

export type ProductTypeSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof ProductTypeSortExtensions & string)>

/**
 * Filters your app adds to Promotion lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PromotionFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PromotionFilterExtensions {}

/** Sort fields your app adds to Promotion lists, as keys: `{ erp_id: true }`. */
export interface PromotionSortExtensions {}

export type PromotionFilters = PromotionFields
  & Filter.Prefixed<'coupon_codes_', CouponCodeFields & Filter.Prefixed<'promotion_', PromotionFields>>
  & {
    search?: string
  }
  & Filter.OrFilters
  & PromotionFilterExtensions

export type PromotionSort = Filter.SortKey<'code' | 'created_at' | 'expires_at' | 'id' | 'kind' | 'name' | 'path' | 'promotion_category_id' | 'starts_at' | 'updated_at' | (keyof PromotionSortExtensions & string)>

/**
 * Filters your app adds to PromotionAction lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PromotionActionFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PromotionActionFilterExtensions {}

/** Sort fields your app adds to PromotionAction lists, as keys: `{ erp_id: true }`. */
export interface PromotionActionSortExtensions {}

export type PromotionActionFilters = PromotionActionFields
  & Filter.OrFilters
  & PromotionActionFilterExtensions

export type PromotionActionSort = Filter.SortKey<'created_at' | 'id' | 'position' | 'updated_at' | (keyof PromotionActionSortExtensions & string)>

/**
 * Filters your app adds to PromotionRule lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PromotionRuleFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PromotionRuleFilterExtensions {}

/** Sort fields your app adds to PromotionRule lists, as keys: `{ erp_id: true }`. */
export interface PromotionRuleSortExtensions {}

export type PromotionRuleFilters = PromotionRuleFields
  & Filter.OrFilters
  & PromotionRuleFilterExtensions

export type PromotionRuleSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof PromotionRuleSortExtensions & string)>

/**
 * Filters your app adds to PurchaseOrder lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface PurchaseOrderFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PurchaseOrderFilterExtensions {}

/** Sort fields your app adds to PurchaseOrder lists, as keys: `{ erp_id: true }`. */
export interface PurchaseOrderSortExtensions {}

export type PurchaseOrderFilters = PurchaseOrderFields
  & Filter.Prefixed<'destination_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'items_', PurchaseOrderItemFields & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'supplier_', SupplierFields>
  & {
    closed?: boolean
    open?: boolean
    overdue?: boolean
    past_cancel_by?: boolean
    search?: string
  }
  & Filter.OrFilters
  & PurchaseOrderFilterExtensions

export type PurchaseOrderSort = Filter.SortKey<'cancel_by' | 'closed_short_at' | 'created_at' | 'currency' | 'destination_location_id' | 'expected_at' | 'id' | 'number' | 'ordered_at' | 'received_at' | 'reference' | 'status' | 'supplier_id' | 'updated_at' | (keyof PurchaseOrderSortExtensions & string)>

/**
 * Filters your app adds to Refund lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface RefundFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface RefundFilterExtensions {}

/** Sort fields your app adds to Refund lists, as keys: `{ erp_id: true }`. */
export interface RefundSortExtensions {}

export type RefundFilters = RefundFields
  & Filter.OrFilters
  & RefundFilterExtensions

export type RefundSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof RefundSortExtensions & string)>

/**
 * Filters your app adds to RefundReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface RefundReasonFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface RefundReasonFilterExtensions {}

/** Sort fields your app adds to RefundReason lists, as keys: `{ erp_id: true }`. */
export interface RefundReasonSortExtensions {}

export type RefundReasonFilters = RefundReasonFields
  & Filter.OrFilters
  & RefundReasonFilterExtensions

export type RefundReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | (keyof RefundReasonSortExtensions & string)>

/**
 * Filters your app adds to ReturnReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ReturnReasonFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ReturnReasonFilterExtensions {}

/** Sort fields your app adds to ReturnReason lists, as keys: `{ erp_id: true }`. */
export interface ReturnReasonSortExtensions {}

export type ReturnReasonFilters = ReturnReasonFields
  & Filter.OrFilters
  & ReturnReasonFilterExtensions

export type ReturnReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | (keyof ReturnReasonSortExtensions & string)>

/**
 * Filters your app adds to Role lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface RoleFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface RoleFilterExtensions {}

/** Sort fields your app adds to Role lists, as keys: `{ erp_id: true }`. */
export interface RoleSortExtensions {}

export type RoleFilters = RoleFields
  & Filter.OrFilters
  & RoleFilterExtensions

export type RoleSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof RoleSortExtensions & string)>

/**
 * Filters your app adds to Seller lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface SellerFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface SellerFilterExtensions {}

/** Sort fields your app adds to Seller lists, as keys: `{ erp_id: true }`. */
export interface SellerSortExtensions {}

export type SellerFilters = SellerFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & SellerFilterExtensions

export type SellerSort = Filter.SortKey<'contact_email' | 'created_at' | 'id' | 'name' | 'status' | 'updated_at' | (keyof SellerSortExtensions & string)>

/**
 * Filters your app adds to SellerRequirement lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface SellerRequirementFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface SellerRequirementFilterExtensions {}

/** Sort fields your app adds to SellerRequirement lists, as keys: `{ erp_id: true }`. */
export interface SellerRequirementSortExtensions {}

export type SellerRequirementFilters = SellerRequirementFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & SellerRequirementFilterExtensions

export type SellerRequirementSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'position' | 'updated_at' | (keyof SellerRequirementSortExtensions & string)>

/**
 * Filters your app adds to ShippingLabel lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface ShippingLabelFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ShippingLabelFilterExtensions {}

/** Sort fields your app adds to ShippingLabel lists, as keys: `{ erp_id: true }`. */
export interface ShippingLabelSortExtensions {}

export type ShippingLabelFilters = ShippingLabelFields
  & Filter.OrFilters
  & ShippingLabelFilterExtensions

export type ShippingLabelSort = Filter.SortKey<'carrier' | 'created_at' | 'id' | 'source' | 'status' | 'tracking_number' | 'updated_at' | (keyof ShippingLabelSortExtensions & string)>

/**
 * Filters your app adds to StockLevel lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StockLevelFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockLevelFilterExtensions {}

/** Sort fields your app adds to StockLevel lists, as keys: `{ erp_id: true }`. */
export interface StockLevelSortExtensions {}

export type StockLevelFilters = StockLevelFields
  & Filter.Prefixed<'stock_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & {
    search?: string
    with_stock_status?: string | string[]
  }
  & Filter.OrFilters
  & StockLevelFilterExtensions

export type StockLevelSort = Filter.SortKey<'allocated_count' | 'count_on_hand' | 'created_at' | 'id' | 'incoming_count' | 'reserved_count' | 'stock_location_id' | 'updated_at' | 'variant_id' | (keyof StockLevelSortExtensions & string)>

/**
 * Filters your app adds to StockLocation lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StockLocationFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockLocationFilterExtensions {}

/** Sort fields your app adds to StockLocation lists, as keys: `{ erp_id: true }`. */
export interface StockLocationSortExtensions {}

export type StockLocationFilters = StockLocationFields
  & Filter.Prefixed<'seller_', SellerFields>
  & {
    search?: string
  }
  & Filter.OrFilters
  & StockLocationFilterExtensions

export type StockLocationSort = Filter.SortKey<'active' | 'country_code' | 'created_at' | 'default' | 'id' | 'kind' | 'name' | 'pickup_enabled' | 'returns_enabled' | 'seller_id' | 'state_code' | 'updated_at' | (keyof StockLocationSortExtensions & string)>

/**
 * Filters your app adds to StockMovement lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StockMovementFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockMovementFilterExtensions {}

/** Sort fields your app adds to StockMovement lists, as keys: `{ erp_id: true }`. */
export interface StockMovementSortExtensions {}

export type StockMovementFilters = StockMovementFields
  & Filter.Prefixed<'stock_level_', StockLevelFields & Filter.Prefixed<'stock_location_', StockLocationFields> & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.OrFilters
  & StockMovementFilterExtensions

export type StockMovementSort = Filter.SortKey<'created_at' | 'exchange_id' | 'fulfillment_id' | 'id' | 'kind' | 'order_id' | 'purchase_order_id' | 'quantity' | 'reason' | 'return_id' | 'stock_item_id' | 'stock_level_id' | 'stock_receipt_id' | 'stock_transfer_id' | 'unit_cost' | 'updated_at' | (keyof StockMovementSortExtensions & string)>

/**
 * Filters your app adds to StockReceipt lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StockReceiptFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockReceiptFilterExtensions {}

/** Sort fields your app adds to StockReceipt lists, as keys: `{ erp_id: true }`. */
export interface StockReceiptSortExtensions {}

export type StockReceiptFilters = StockReceiptFields
  & Filter.OrFilters
  & StockReceiptFilterExtensions

export type StockReceiptSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'receivable_id' | 'receivable_type' | 'received_at' | 'received_by_id' | 'received_by_type' | 'reference' | 'updated_at' | (keyof StockReceiptSortExtensions & string)>

/**
 * Filters your app adds to StockTransfer lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StockTransferFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockTransferFilterExtensions {}

/** Sort fields your app adds to StockTransfer lists, as keys: `{ erp_id: true }`. */
export interface StockTransferSortExtensions {}

export type StockTransferFilters = StockTransferFields
  & Filter.Prefixed<'destination_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'items_', StockTransferItemFields & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'source_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & {
    closed?: boolean
    open?: boolean
    search?: string
  }
  & Filter.OrFilters
  & StockTransferFilterExtensions

export type StockTransferSort = Filter.SortKey<'closed_short_at' | 'created_at' | 'destination_location_id' | 'id' | 'number' | 'received_at' | 'reference' | 'shipped_at' | 'source_location_id' | 'status' | 'updated_at' | (keyof StockTransferSortExtensions & string)>

/**
 * Filters your app adds to StoreCredit lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StoreCreditFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StoreCreditFilterExtensions {}

/** Sort fields your app adds to StoreCredit lists, as keys: `{ erp_id: true }`. */
export interface StoreCreditSortExtensions {}

export type StoreCreditFilters = StoreCreditFields
  & Filter.Prefixed<'created_by_', AdminUserFields & Filter.Prefixed<'spree_roles_', RoleFields>>
  & Filter.Prefixed<'customer_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & {
    from_gift_card?: boolean
    outstanding?: boolean
    search?: string
  }
  & Filter.OrFilters
  & StoreCreditFilterExtensions

export type StoreCreditSort = Filter.SortKey<'amount' | 'created_at' | 'created_by_id' | 'currency' | 'customer_id' | 'id' | 'memo' | 'updated_at' | (keyof StoreCreditSortExtensions & string)>

/**
 * Filters your app adds to StoreCreditEvent lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface StoreCreditEventFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StoreCreditEventFilterExtensions {}

/** Sort fields your app adds to StoreCreditEvent lists, as keys: `{ erp_id: true }`. */
export interface StoreCreditEventSortExtensions {}

export type StoreCreditEventFilters = StoreCreditEventFields
  & Filter.OrFilters
  & StoreCreditEventFilterExtensions

export type StoreCreditEventSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof StoreCreditEventSortExtensions & string)>

/**
 * Filters your app adds to Supplier lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface SupplierFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface SupplierFilterExtensions {}

/** Sort fields your app adds to Supplier lists, as keys: `{ erp_id: true }`. */
export interface SupplierSortExtensions {}

export type SupplierFilters = SupplierFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & SupplierFilterExtensions

export type SupplierSort = Filter.SortKey<'city' | 'contact_name' | 'country_code' | 'created_at' | 'email' | 'id' | 'name' | 'phone' | 'updated_at' | (keyof SupplierSortExtensions & string)>

/**
 * Filters your app adds to TaxExemptionCertificate lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface TaxExemptionCertificateFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface TaxExemptionCertificateFilterExtensions {}

/** Sort fields your app adds to TaxExemptionCertificate lists, as keys: `{ erp_id: true }`. */
export interface TaxExemptionCertificateSortExtensions {}

export type TaxExemptionCertificateFilters = TaxExemptionCertificateFields
  & Filter.OrFilters
  & TaxExemptionCertificateFilterExtensions

export type TaxExemptionCertificateSort = Filter.SortKey<'certificate_number' | 'created_at' | 'expires_at' | 'id' | 'reason_code' | 'status' | 'updated_at' | (keyof TaxExemptionCertificateSortExtensions & string)>

/**
 * Filters your app adds to TaxIdentifier lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface TaxIdentifierFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface TaxIdentifierFilterExtensions {}

/** Sort fields your app adds to TaxIdentifier lists, as keys: `{ erp_id: true }`. */
export interface TaxIdentifierSortExtensions {}

export type TaxIdentifierFilters = TaxIdentifierFields
  & Filter.OrFilters
  & TaxIdentifierFilterExtensions

export type TaxIdentifierSort = Filter.SortKey<'created_at' | 'id' | 'updated_at' | (keyof TaxIdentifierSortExtensions & string)>

/**
 * Filters your app adds to TaxLine lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface TaxLineFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface TaxLineFilterExtensions {}

/** Sort fields your app adds to TaxLine lists, as keys: `{ erp_id: true }`. */
export interface TaxLineSortExtensions {}

export type TaxLineFilters = TaxLineFields
  & Filter.OrFilters
  & TaxLineFilterExtensions

export type TaxLineSort = Filter.SortKey<'country_code' | 'created_at' | 'id' | 'included' | 'provider_id' | 'state_code' | 'taxability_reason' | 'updated_at' | (keyof TaxLineSortExtensions & string)>

/**
 * Filters your app adds to TaxRate lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface TaxRateFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface TaxRateFilterExtensions {}

/** Sort fields your app adds to TaxRate lists, as keys: `{ erp_id: true }`. */
export interface TaxRateSortExtensions {}

export type TaxRateFilters = TaxRateFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & TaxRateFilterExtensions

export type TaxRateSort = Filter.SortKey<'amount' | 'country_code' | 'created_at' | 'id' | 'included_in_price' | 'name' | 'rate' | 'state_code' | 'tax_category_id' | 'updated_at' | (keyof TaxRateSortExtensions & string)>

/**
 * Filters your app adds to Variant lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface VariantFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface VariantFilterExtensions {}

/** Sort fields your app adds to Variant lists, as keys: `{ erp_id: true }`. */
export interface VariantSortExtensions {}

export type VariantFilters = VariantFields
  & Filter.Prefixed<'option_values_', OptionValueFields>
  & Filter.Prefixed<'prices_', PriceFields & Filter.Prefixed<'price_list_', PriceListFields> & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'product_', ProductFields & Filter.Prefixed<'categories_', CategoryFields> & Filter.Prefixed<'channels_', ChannelFields> & Filter.Prefixed<'collections_', CollectionFields> & Filter.Prefixed<'default_variant_', VariantFields> & Filter.Prefixed<'labels_', TagFields> & Filter.Prefixed<'option_types_', OptionTypeFields> & Filter.Prefixed<'product_categories_', ProductCategoryFields> & Filter.Prefixed<'product_type_', ProductTypeFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields> & Filter.Prefixed<'variants_', VariantFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.Prefixed<'tax_category_', TaxCategoryFields>
  & {
    available_at_stock_location?: string
    product_name_or_sku_cont?: string
    search?: string
    search_by_product_name_or_sku?: string
  }
  & Filter.OrFilters
  & VariantFilterExtensions

export type VariantSort = Filter.SortKey<'carton_package_type_id' | 'carton_weight' | 'cartons_per_pallet' | 'cost_currency' | 'cost_price' | 'country_of_origin' | 'created_at' | 'deleted_at' | 'depth' | 'discontinue_on' | 'height' | 'hs_code' | 'id' | 'minimum_order_quantity' | 'order_multiple' | 'position' | 'product_id' | 'purchase_unit' | 'sku' | 'track_inventory' | 'units_per_carton' | 'updated_at' | 'weight' | 'width' | (keyof VariantSortExtensions & string)>

/**
 * Filters your app adds to WebhookDelivery lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface WebhookDeliveryFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface WebhookDeliveryFilterExtensions {}

/** Sort fields your app adds to WebhookDelivery lists, as keys: `{ erp_id: true }`. */
export interface WebhookDeliverySortExtensions {}

export type WebhookDeliveryFilters = WebhookDeliveryFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & WebhookDeliveryFilterExtensions

export type WebhookDeliverySort = Filter.SortKey<'created_at' | 'delivered_at' | 'event_name' | 'execution_time' | 'id' | 'response_code' | 'success' | 'updated_at' | (keyof WebhookDeliverySortExtensions & string)>

/**
 * Filters your app adds to WebhookEndpoint lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/admin-sdk' {
 *       interface WebhookEndpointFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface WebhookEndpointFilterExtensions {}

/** Sort fields your app adds to WebhookEndpoint lists, as keys: `{ erp_id: true }`. */
export interface WebhookEndpointSortExtensions {}

export type WebhookEndpointFilters = WebhookEndpointFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & WebhookEndpointFilterExtensions

export type WebhookEndpointSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | 'url' | (keyof WebhookEndpointSortExtensions & string)>
