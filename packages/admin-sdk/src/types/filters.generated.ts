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

export type CommissionLineFields = Filter.RangeFilters<'amount' | 'rate' | 'tax_amount' | 'total', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency'>
  & Filter.IdFilters<'id' | 'order_id'>
  & Filter.EnumFilters<'kind', 'percentage' | 'fixed'>

export type CommissionRateFields = Filter.TextFilters<'code' | 'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.BooleanFilters<'enabled' | 'include_shipping' | 'tax_inclusive'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'position', number>
  & Filter.RangeFilters<'value', string | number>
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

export type LineItemFields = Filter.RangeFilters<'additional_tax_total' | 'adjustment_total' | 'cost_price' | 'discount_total' | 'included_tax_total' | 'non_taxable_adjustment_total' | 'pre_tax_amount' | 'price' | 'taxable_adjustment_total', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
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
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'updated_at'>
  & Filter.BooleanFilters<'considered_risky'>
  & Filter.TextFilters<'coupon_code' | 'currency' | 'email' | 'number' | 'po_number'>
  & Filter.RangeFilters<'delivery_total' | 'item_total' | 'total', string | number>
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

export type PaymentFields = Filter.RangeFilters<'amount', string | number>
  & Filter.TextFilters<'avs_response' | 'cvv_response_code' | 'cvv_response_message' | 'response_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
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

export type PriceFields = Filter.RangeFilters<'amount' | 'compare_at_amount', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency'>
  & Filter.IdFilters<'id' | 'price_list_id' | 'variant_id'>
  & Filter.RangeFilters<'min_quantity', number>

export type PriceListFields = Filter.IdFilters<'catalog_id' | 'id'>
  & Filter.RangeFilters<'created_at' | 'ends_at' | 'starts_at' | 'updated_at'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>
  & Filter.EnumFilters<'match_policy', 'all' | 'any'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'inactive' | 'scheduled'>

export type ProductFields = Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'updated_at'>
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

export type PurchaseOrderItemFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'variant_id'>
  & Filter.RangeFilters<'quantity_ordered' | 'quantity_received' | 'quantity_rejected', number>
  & Filter.RangeFilters<'unit_cost', string | number>

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

export type StockMovementFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'exchange_id' | 'fulfillment_id' | 'id' | 'order_id' | 'purchase_order_id' | 'return_id' | 'stock_item_id' | 'stock_level_id' | 'stock_receipt_id' | 'stock_transfer_id'>
  & Filter.RangeFilters<'quantity', number>
  & Filter.TextFilters<'reason'>
  & Filter.RangeFilters<'unit_cost', string | number>
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

export type StoreCreditFields = Filter.RangeFilters<'amount', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
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

export type TaxRateFields = Filter.RangeFilters<'amount', string | number>
  & Filter.TextFilters<'country_code' | 'name' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'tax_category_id'>
  & Filter.BooleanFilters<'included_in_price'>

export type VariantFields = Filter.IdFilters<'carton_package_type_id' | 'id' | 'product_id'>
  & Filter.RangeFilters<'carton_weight' | 'cost_price' | 'depth' | 'height' | 'weight' | 'width', string | number>
  & Filter.RangeFilters<'cartons_per_pallet' | 'minimum_order_quantity' | 'order_multiple' | 'position' | 'units_per_carton', number>
  & Filter.TextFilters<'cost_currency' | 'country_of_origin' | 'hs_code' | 'sku'>
  & Filter.RangeFilters<'created_at' | 'deleted_at' | 'discontinue_on' | 'updated_at'>
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

export interface AddressFilterExtensions {}

export type AddressFilters = AddressFields
  & Filter.OrFilters
  & AddressFilterExtensions

export type AddressSort = Filter.SortKey<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'created_at' | 'first_name' | 'id' | 'last_name' | 'phone' | 'postal_code' | 'state_code' | 'updated_at'>

export interface AdminUserFilterExtensions {}

export type AdminUserFilters = AdminUserFields
  & Filter.Prefixed<'spree_roles_', RoleFields>
  & Filter.OrFilters
  & AdminUserFilterExtensions

export type AdminUserSort = Filter.SortKey<'created_at' | 'email' | 'first_name' | 'id' | 'last_name' | 'updated_at'>

export interface AllowedOriginFilterExtensions {}

export type AllowedOriginFilters = AllowedOriginFields
  & Filter.OrFilters
  & AllowedOriginFilterExtensions

export type AllowedOriginSort = Filter.SortKey<'created_at' | 'id' | 'origin' | 'updated_at'>

export interface ApiKeyFilterExtensions {}

export type ApiKeyFilters = ApiKeyFields
  & Filter.OrFilters
  & ApiKeyFilterExtensions

export type ApiKeySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface CatalogFilterExtensions {}

export type CatalogFilters = CatalogFields
  & Filter.OrFilters
  & CatalogFilterExtensions

export type CatalogSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'position' | 'updated_at'>

export interface CatalogOrderMinimumFilterExtensions {}

export type CatalogOrderMinimumFilters = CatalogOrderMinimumFields
  & Filter.OrFilters
  & CatalogOrderMinimumFilterExtensions

export type CatalogOrderMinimumSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface CategoryFilterExtensions {}

export type CategoryFilters = CategoryFields
  & Filter.Prefixed<'parent_', CategoryFields & Filter.Prefixed<'parent_', CategoryFields>>
  & Filter.OrFilters
  & CategoryFilterExtensions

export type CategorySort = Filter.SortKey<'automatic' | 'children_count' | 'created_at' | 'depth' | 'id' | 'name' | 'parent_id' | 'permalink' | 'position' | 'pretty_name' | 'products_count' | 'updated_at'>

export interface ChannelFilterExtensions {}

export type ChannelFilters = ChannelFields
  & Filter.OrFilters
  & ChannelFilterExtensions

export type ChannelSort = Filter.SortKey<'active' | 'code' | 'created_at' | 'default' | 'id' | 'name' | 'store_id' | 'updated_at'>

export interface ClaimReasonFilterExtensions {}

export type ClaimReasonFilters = ClaimReasonFields
  & Filter.OrFilters
  & ClaimReasonFilterExtensions

export type ClaimReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface CollectionFilterExtensions {}

export type CollectionFilters = CollectionFields
  & Filter.OrFilters
  & CollectionFilterExtensions

export type CollectionSort = Filter.SortKey<'automatic' | 'created_at' | 'id' | 'name' | 'permalink' | 'position' | 'products_count' | 'sort_order' | 'updated_at'>

export interface CommissionLineFilterExtensions {}

export type CommissionLineFilters = CommissionLineFields
  & Filter.Prefixed<'commission_rate_', CommissionRateFields & Filter.Prefixed<'commission_rules_', CommissionRuleFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & CommissionLineFilterExtensions

export type CommissionLineSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'kind' | 'order_id' | 'rate' | 'tax_amount' | 'total' | 'updated_at'>

export interface CommissionRateFilterExtensions {}

export type CommissionRateFilters = CommissionRateFields
  & Filter.Prefixed<'commission_rules_', CommissionRuleFields>
  & Filter.OrFilters
  & CommissionRateFilterExtensions

export type CommissionRateSort = Filter.SortKey<'code' | 'created_at' | 'enabled' | 'id' | 'include_shipping' | 'kind' | 'name' | 'position' | 'tax_inclusive' | 'updated_at' | 'value'>

export interface CompanyFilterExtensions {}

export type CompanyFilters = CompanyFields
  & Filter.Prefixed<'children_', CompanyFields & Filter.Prefixed<'children_', CompanyFields> & Filter.Prefixed<'external_references_', ExternalReferenceFields> & Filter.Prefixed<'memberships_', CompanyMembershipFields> & Filter.Prefixed<'parent_', CompanyFields>>
  & Filter.Prefixed<'external_references_', ExternalReferenceFields>
  & Filter.Prefixed<'memberships_', CompanyMembershipFields>
  & Filter.Prefixed<'parent_', CompanyFields & Filter.Prefixed<'children_', CompanyFields> & Filter.Prefixed<'external_references_', ExternalReferenceFields> & Filter.Prefixed<'memberships_', CompanyMembershipFields> & Filter.Prefixed<'parent_', CompanyFields>>
  & Filter.OrFilters
  & CompanyFilterExtensions

export type CompanySort = Filter.SortKey<'created_at' | 'id' | 'kind' | 'name' | 'parent_id' | 'po_number_required' | 'updated_at'>

export interface CompanyMembershipFilterExtensions {}

export type CompanyMembershipFilters = CompanyMembershipFields
  & Filter.OrFilters
  & CompanyMembershipFilterExtensions

export type CompanyMembershipSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface CouponCodeFilterExtensions {}

export type CouponCodeFilters = CouponCodeFields
  & Filter.Prefixed<'promotion_', PromotionFields & Filter.Prefixed<'coupon_codes_', CouponCodeFields>>
  & Filter.OrFilters
  & CouponCodeFilterExtensions

export type CouponCodeSort = Filter.SortKey<'code' | 'created_at' | 'id' | 'promotion_id' | 'state' | 'updated_at'>

export interface CreditCardFilterExtensions {}

export type CreditCardFilters = CreditCardFields
  & Filter.OrFilters
  & CreditCardFilterExtensions

export type CreditCardSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface CustomerFilterExtensions {}

export type CustomerFilters = CustomerFields
  & Filter.Prefixed<'addresses_', AddressFields>
  & Filter.Prefixed<'bill_address_', AddressFields>
  & Filter.Prefixed<'customer_groups_', CustomerGroupFields>
  & Filter.Prefixed<'orders_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'ship_address_', AddressFields>
  & Filter.Prefixed<'spree_roles_', RoleFields>
  & Filter.Prefixed<'tags_', TagFields>
  & Filter.OrFilters
  & {
    anonymized?: boolean
    search?: string
    with_min_total_spent?: string | number
    with_standing_for_company?: string | string[]
  }
  & CustomerFilterExtensions

export type CustomerSort = Filter.SortKey<'accepts_email_marketing' | 'created_at' | 'email' | 'first_name' | 'id' | 'last_name' | 'phone' | 'updated_at'>

export interface CustomerGroupFilterExtensions {}

export type CustomerGroupFilters = CustomerGroupFields
  & Filter.OrFilters
  & CustomerGroupFilterExtensions

export type CustomerGroupSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface CustomFieldFilterExtensions {}

export type CustomFieldFilters = CustomFieldFields
  & Filter.OrFilters
  & CustomFieldFilterExtensions

export type CustomFieldSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface CustomFieldDefinitionFilterExtensions {}

export type CustomFieldDefinitionFilters = CustomFieldDefinitionFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & CustomFieldDefinitionFilterExtensions

export type CustomFieldDefinitionSort = Filter.SortKey<'created_at' | 'field_type' | 'id' | 'key' | 'label' | 'namespace' | 'resource_type' | 'searchable' | 'sortable' | 'storefront_visible' | 'updated_at'>

export interface DeliveryFilterExtensions {}

export type DeliveryFilters = DeliveryFields
  & Filter.OrFilters
  & DeliveryFilterExtensions

export type DeliverySort = Filter.SortKey<'carrier' | 'created_at' | 'id' | 'status' | 'tracking_number' | 'updated_at'>

export interface DeliveryMethodFilterExtensions {}

export type DeliveryMethodFilters = DeliveryMethodFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & DeliveryMethodFilterExtensions

export type DeliveryMethodSort = Filter.SortKey<'available_to_sellers' | 'created_at' | 'id' | 'name' | 'seller_id' | 'storefront_visible' | 'updated_at'>

export interface DeliveryProfileFilterExtensions {}

export type DeliveryProfileFilters = DeliveryProfileFields
  & Filter.OrFilters
  & DeliveryProfileFilterExtensions

export type DeliveryProfileSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'position' | 'updated_at'>

export interface DiscountFilterExtensions {}

export type DiscountFilters = DiscountFields
  & Filter.OrFilters
  & DiscountFilterExtensions

export type DiscountSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface EmailTemplateRevisionFilterExtensions {}

export type EmailTemplateRevisionFilters = EmailTemplateRevisionFields
  & Filter.OrFilters
  & EmailTemplateRevisionFilterExtensions

export type EmailTemplateRevisionSort = Filter.SortKey<'created_at' | 'id'>

export interface ExportFilterExtensions {}

export type ExportFilters = ExportFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & ExportFilterExtensions

export type ExportSort = Filter.SortKey<'created_at' | 'format' | 'id' | 'number' | 'seller_id' | 'type' | 'updated_at'>

export interface FulfillmentFilterExtensions {}

export type FulfillmentFilters = FulfillmentFields
  & Filter.OrFilters
  & FulfillmentFilterExtensions

export type FulfillmentSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'updated_at'>

export interface GiftCardFilterExtensions {}

export type GiftCardFilters = GiftCardFields
  & Filter.Prefixed<'batch_', GiftCardBatchFields>
  & Filter.Prefixed<'customers_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'orders_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'users_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.OrFilters
  & {
    active?: boolean
    expired?: boolean
    partially_redeemed?: boolean
    redeemed?: boolean
  }
  & GiftCardFilterExtensions

export type GiftCardSort = Filter.SortKey<'code' | 'created_at' | 'created_by_id' | 'currency' | 'customer_id' | 'expires_at' | 'gift_card_batch_id' | 'id' | 'state' | 'status' | 'updated_at'>

export interface GiftCardBatchFilterExtensions {}

export type GiftCardBatchFilters = GiftCardBatchFields
  & Filter.OrFilters
  & GiftCardBatchFilterExtensions

export type GiftCardBatchSort = Filter.SortKey<'created_at' | 'id' | 'prefix' | 'updated_at'>

export interface ImportFilterExtensions {}

export type ImportFilters = ImportFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & ImportFilterExtensions

export type ImportSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'seller_id' | 'status' | 'type' | 'updated_at'>

export interface ImportRowFilterExtensions {}

export type ImportRowFilters = ImportRowFields
  & Filter.OrFilters
  & ImportRowFilterExtensions

export type ImportRowSort = Filter.SortKey<'created_at' | 'id' | 'row_number' | 'status' | 'updated_at'>

export interface IntegrationFilterExtensions {}

export type IntegrationFilters = IntegrationFields
  & Filter.OrFilters
  & IntegrationFilterExtensions

export type IntegrationSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface InvitationFilterExtensions {}

export type InvitationFilters = InvitationFields
  & Filter.OrFilters
  & InvitationFilterExtensions

export type InvitationSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface LineItemFilterExtensions {}

export type LineItemFilters = LineItemFields
  & Filter.Prefixed<'order_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'tax_category_', TaxCategoryFields>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.OrFilters
  & LineItemFilterExtensions

export type LineItemSort = Filter.SortKey<'additional_tax_total' | 'adjustment_total' | 'cost_price' | 'created_at' | 'discount_total' | 'id' | 'included_tax_total' | 'non_taxable_adjustment_total' | 'order_id' | 'pre_tax_amount' | 'price' | 'quantity' | 'tax_category_id' | 'taxable_adjustment_total' | 'updated_at' | 'variant_id'>

export interface MarketFilterExtensions {}

export type MarketFilters = MarketFields
  & Filter.OrFilters
  & MarketFilterExtensions

export type MarketSort = Filter.SortKey<'created_at' | 'currency' | 'default_locale' | 'id' | 'name' | 'position' | 'updated_at'>

export interface MediaFilterExtensions {}

export type MediaFilters = MediaFields
  & Filter.OrFilters
  & {
    attached?: boolean
    filename_cont?: string
    unattached?: boolean
  }
  & MediaFilterExtensions

export type MediaSort = Filter.SortKey<'alt' | 'created_at' | 'id' | 'media_type' | 'position' | 'updated_at'>

export interface OptionTypeFilterExtensions {}

export type OptionTypeFilters = OptionTypeFields
  & Filter.OrFilters
  & {
    search_by_name?: string
  }
  & OptionTypeFilterExtensions

export type OptionTypeSort = Filter.SortKey<'created_at' | 'id' | 'kind' | 'label' | 'name' | 'position' | 'updated_at'>

export interface OrderFilterExtensions {}

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
  & Filter.OrFilters
  & {
    complete?: boolean
    incomplete?: boolean
    partially_refunded?: boolean
    refunded?: boolean
    search?: string
  }
  & OrderFilterExtensions

export type OrderSort = Filter.SortKey<'channel_id' | 'completed_at' | 'considered_risky' | 'coupon_code' | 'created_at' | 'currency' | 'customer_id' | 'delivery_total' | 'email' | 'fulfillment_status' | 'id' | 'item_total' | 'number' | 'order_group_id' | 'payment_state' | 'payment_status' | 'po_number' | 'seller_id' | 'shipment_state' | 'status' | 'total' | 'total_quantity' | 'updated_at'>

export interface OrderCancellationReasonFilterExtensions {}

export type OrderCancellationReasonFilters = OrderCancellationReasonFields
  & Filter.OrFilters
  & OrderCancellationReasonFilterExtensions

export type OrderCancellationReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface OrderRoutingRuleFilterExtensions {}

export type OrderRoutingRuleFilters = OrderRoutingRuleFields
  & Filter.OrFilters
  & OrderRoutingRuleFilterExtensions

export type OrderRoutingRuleSort = Filter.SortKey<'active' | 'channel_id' | 'created_at' | 'id' | 'position' | 'store_id' | 'type' | 'updated_at'>

export interface PackageTypeFilterExtensions {}

export type PackageTypeFilters = PackageTypeFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & PackageTypeFilterExtensions

export type PackageTypeSort = Filter.SortKey<'created_at' | 'default' | 'id' | 'kind' | 'name' | 'seller_id' | 'updated_at'>

export interface PaymentFilterExtensions {}

export type PaymentFilters = PaymentFields
  & Filter.Prefixed<'order_', OrderFields & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'channel_', ChannelFields> & Filter.Prefixed<'customer_', CustomerFields> & Filter.Prefixed<'fulfillments_', FulfillmentFields> & Filter.Prefixed<'line_items_', LineItemFields> & Filter.Prefixed<'order_group_', OrderGroupFields> & Filter.Prefixed<'promotions_', PromotionFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'shipments_', FulfillmentFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.Prefixed<'payment_method_', PaymentMethodFields>
  & Filter.OrFilters
  & PaymentFilterExtensions

export type PaymentSort = Filter.SortKey<'amount' | 'avs_response' | 'created_at' | 'cvv_response_code' | 'cvv_response_message' | 'id' | 'response_code' | 'state' | 'status' | 'updated_at'>

export interface PaymentMethodFilterExtensions {}

export type PaymentMethodFilters = PaymentMethodFields
  & Filter.OrFilters
  & PaymentMethodFilterExtensions

export type PaymentMethodSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'position' | 'storefront_visible' | 'type' | 'updated_at'>

export interface PolicyFilterExtensions {}

export type PolicyFilters = PolicyFields
  & Filter.OrFilters
  & PolicyFilterExtensions

export type PolicySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'owner_id' | 'owner_type' | 'updated_at'>

export interface PriceFilterExtensions {}

export type PriceFilters = PriceFields
  & Filter.Prefixed<'price_list_', PriceListFields>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.OrFilters
  & {
    search?: string
  }
  & PriceFilterExtensions

export type PriceSort = Filter.SortKey<'amount' | 'compare_at_amount' | 'created_at' | 'currency' | 'id' | 'min_quantity' | 'price_list_id' | 'updated_at' | 'variant_id'>

export interface PriceListFilterExtensions {}

export type PriceListFilters = PriceListFields
  & Filter.OrFilters
  & PriceListFilterExtensions

export type PriceListSort = Filter.SortKey<'catalog_id' | 'created_at' | 'ends_at' | 'id' | 'match_policy' | 'name' | 'position' | 'starts_at' | 'status' | 'updated_at'>

export interface ProductFilterExtensions {}

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
  & Filter.OrFilters
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
    price_between?: [string | number, string | number]
    price_gte?: string | number
    price_lte?: string | number
    search?: string
    search_by_name?: string
    with_option_value_ids?: string | string[]
  }
  & Filter.CustomFieldFilters
  & ProductFilterExtensions

export type ProductSort = Filter.SortKey<'available_on' | 'best_selling' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'manual' | 'name' | 'price' | 'seller_id' | 'slug' | 'status' | 'updated_at' | `cf_${string}`>

export interface ProductTypeFilterExtensions {}

export type ProductTypeFilters = ProductTypeFields
  & Filter.Prefixed<'option_types_', OptionTypeFields>
  & Filter.OrFilters
  & ProductTypeFilterExtensions

export type ProductTypeSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface PromotionFilterExtensions {}

export type PromotionFilters = PromotionFields
  & Filter.Prefixed<'coupon_codes_', CouponCodeFields & Filter.Prefixed<'promotion_', PromotionFields>>
  & Filter.OrFilters
  & PromotionFilterExtensions

export type PromotionSort = Filter.SortKey<'code' | 'created_at' | 'expires_at' | 'id' | 'kind' | 'name' | 'path' | 'promotion_category_id' | 'starts_at' | 'updated_at'>

export interface PromotionActionFilterExtensions {}

export type PromotionActionFilters = PromotionActionFields
  & Filter.OrFilters
  & PromotionActionFilterExtensions

export type PromotionActionSort = Filter.SortKey<'created_at' | 'id' | 'position' | 'updated_at'>

export interface PromotionRuleFilterExtensions {}

export type PromotionRuleFilters = PromotionRuleFields
  & Filter.OrFilters
  & PromotionRuleFilterExtensions

export type PromotionRuleSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface PurchaseOrderFilterExtensions {}

export type PurchaseOrderFilters = PurchaseOrderFields
  & Filter.Prefixed<'destination_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'items_', PurchaseOrderItemFields & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'supplier_', SupplierFields>
  & Filter.OrFilters
  & {
    closed?: boolean
    open?: boolean
    overdue?: boolean
    past_cancel_by?: boolean
  }
  & PurchaseOrderFilterExtensions

export type PurchaseOrderSort = Filter.SortKey<'cancel_by' | 'closed_short_at' | 'created_at' | 'currency' | 'destination_location_id' | 'expected_at' | 'id' | 'number' | 'ordered_at' | 'received_at' | 'reference' | 'status' | 'supplier_id' | 'updated_at'>

export interface RefundFilterExtensions {}

export type RefundFilters = RefundFields
  & Filter.OrFilters
  & RefundFilterExtensions

export type RefundSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface RefundReasonFilterExtensions {}

export type RefundReasonFilters = RefundReasonFields
  & Filter.OrFilters
  & RefundReasonFilterExtensions

export type RefundReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface ReturnReasonFilterExtensions {}

export type ReturnReasonFilters = ReturnReasonFields
  & Filter.OrFilters
  & ReturnReasonFilterExtensions

export type ReturnReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface RoleFilterExtensions {}

export type RoleFilters = RoleFields
  & Filter.OrFilters
  & RoleFilterExtensions

export type RoleSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface SellerFilterExtensions {}

export type SellerFilters = SellerFields
  & Filter.OrFilters
  & SellerFilterExtensions

export type SellerSort = Filter.SortKey<'contact_email' | 'created_at' | 'id' | 'name' | 'status' | 'updated_at'>

export interface SellerRequirementFilterExtensions {}

export type SellerRequirementFilters = SellerRequirementFields
  & Filter.OrFilters
  & SellerRequirementFilterExtensions

export type SellerRequirementSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'position' | 'updated_at'>

export interface ShippingLabelFilterExtensions {}

export type ShippingLabelFilters = ShippingLabelFields
  & Filter.OrFilters
  & ShippingLabelFilterExtensions

export type ShippingLabelSort = Filter.SortKey<'carrier' | 'created_at' | 'id' | 'source' | 'status' | 'tracking_number' | 'updated_at'>

export interface StockLevelFilterExtensions {}

export type StockLevelFilters = StockLevelFields
  & Filter.Prefixed<'stock_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'variant_', VariantFields & Filter.Prefixed<'option_values_', OptionValueFields> & Filter.Prefixed<'prices_', PriceFields> & Filter.Prefixed<'product_', ProductFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'tax_category_', TaxCategoryFields>>
  & Filter.OrFilters
  & {
    with_stock_status?: string | string[]
  }
  & StockLevelFilterExtensions

export type StockLevelSort = Filter.SortKey<'allocated_count' | 'count_on_hand' | 'created_at' | 'id' | 'incoming_count' | 'reserved_count' | 'stock_location_id' | 'updated_at' | 'variant_id'>

export interface StockLocationFilterExtensions {}

export type StockLocationFilters = StockLocationFields
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.OrFilters
  & StockLocationFilterExtensions

export type StockLocationSort = Filter.SortKey<'active' | 'country_code' | 'created_at' | 'default' | 'id' | 'kind' | 'name' | 'pickup_enabled' | 'returns_enabled' | 'seller_id' | 'state_code' | 'updated_at'>

export interface StockMovementFilterExtensions {}

export type StockMovementFilters = StockMovementFields
  & Filter.Prefixed<'stock_level_', StockLevelFields & Filter.Prefixed<'stock_location_', StockLocationFields> & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.OrFilters
  & StockMovementFilterExtensions

export type StockMovementSort = Filter.SortKey<'created_at' | 'exchange_id' | 'fulfillment_id' | 'id' | 'kind' | 'order_id' | 'purchase_order_id' | 'quantity' | 'reason' | 'return_id' | 'stock_item_id' | 'stock_level_id' | 'stock_receipt_id' | 'stock_transfer_id' | 'unit_cost' | 'updated_at'>

export interface StockReceiptFilterExtensions {}

export type StockReceiptFilters = StockReceiptFields
  & Filter.OrFilters
  & StockReceiptFilterExtensions

export type StockReceiptSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'receivable_id' | 'receivable_type' | 'received_at' | 'received_by_id' | 'received_by_type' | 'reference' | 'updated_at'>

export interface StockTransferFilterExtensions {}

export type StockTransferFilters = StockTransferFields
  & Filter.Prefixed<'destination_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.Prefixed<'items_', StockTransferItemFields & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'source_location_', StockLocationFields & Filter.Prefixed<'seller_', SellerFields>>
  & Filter.OrFilters
  & {
    closed?: boolean
    open?: boolean
  }
  & StockTransferFilterExtensions

export type StockTransferSort = Filter.SortKey<'closed_short_at' | 'created_at' | 'destination_location_id' | 'id' | 'number' | 'received_at' | 'reference' | 'shipped_at' | 'source_location_id' | 'status' | 'updated_at'>

export interface StoreCreditFilterExtensions {}

export type StoreCreditFilters = StoreCreditFields
  & Filter.Prefixed<'created_by_', AdminUserFields & Filter.Prefixed<'spree_roles_', RoleFields>>
  & Filter.Prefixed<'customer_', CustomerFields & Filter.Prefixed<'addresses_', AddressFields> & Filter.Prefixed<'bill_address_', AddressFields> & Filter.Prefixed<'customer_groups_', CustomerGroupFields> & Filter.Prefixed<'orders_', OrderFields> & Filter.Prefixed<'ship_address_', AddressFields> & Filter.Prefixed<'spree_roles_', RoleFields> & Filter.Prefixed<'tags_', TagFields>>
  & Filter.OrFilters
  & {
    from_gift_card?: boolean
    outstanding?: boolean
  }
  & StoreCreditFilterExtensions

export type StoreCreditSort = Filter.SortKey<'amount' | 'created_at' | 'created_by_id' | 'currency' | 'customer_id' | 'id' | 'memo' | 'updated_at'>

export interface StoreCreditEventFilterExtensions {}

export type StoreCreditEventFilters = StoreCreditEventFields
  & Filter.OrFilters
  & StoreCreditEventFilterExtensions

export type StoreCreditEventSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface SupplierFilterExtensions {}

export type SupplierFilters = SupplierFields
  & Filter.OrFilters
  & SupplierFilterExtensions

export type SupplierSort = Filter.SortKey<'city' | 'contact_name' | 'country_code' | 'created_at' | 'email' | 'id' | 'name' | 'phone' | 'updated_at'>

export interface TaxExemptionCertificateFilterExtensions {}

export type TaxExemptionCertificateFilters = TaxExemptionCertificateFields
  & Filter.OrFilters
  & TaxExemptionCertificateFilterExtensions

export type TaxExemptionCertificateSort = Filter.SortKey<'certificate_number' | 'created_at' | 'expires_at' | 'id' | 'reason_code' | 'status' | 'updated_at'>

export interface TaxIdentifierFilterExtensions {}

export type TaxIdentifierFilters = TaxIdentifierFields
  & Filter.OrFilters
  & TaxIdentifierFilterExtensions

export type TaxIdentifierSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export interface TaxLineFilterExtensions {}

export type TaxLineFilters = TaxLineFields
  & Filter.OrFilters
  & TaxLineFilterExtensions

export type TaxLineSort = Filter.SortKey<'country_code' | 'created_at' | 'id' | 'included' | 'provider_id' | 'state_code' | 'taxability_reason' | 'updated_at'>

export interface TaxRateFilterExtensions {}

export type TaxRateFilters = TaxRateFields
  & Filter.OrFilters
  & TaxRateFilterExtensions

export type TaxRateSort = Filter.SortKey<'amount' | 'country_code' | 'created_at' | 'id' | 'included_in_price' | 'name' | 'state_code' | 'tax_category_id' | 'updated_at'>

export interface VariantFilterExtensions {}

export type VariantFilters = VariantFields
  & Filter.Prefixed<'option_values_', OptionValueFields>
  & Filter.Prefixed<'prices_', PriceFields & Filter.Prefixed<'price_list_', PriceListFields> & Filter.Prefixed<'variant_', VariantFields>>
  & Filter.Prefixed<'product_', ProductFields & Filter.Prefixed<'categories_', CategoryFields> & Filter.Prefixed<'channels_', ChannelFields> & Filter.Prefixed<'collections_', CollectionFields> & Filter.Prefixed<'default_variant_', VariantFields> & Filter.Prefixed<'labels_', TagFields> & Filter.Prefixed<'option_types_', OptionTypeFields> & Filter.Prefixed<'product_categories_', ProductCategoryFields> & Filter.Prefixed<'product_type_', ProductTypeFields> & Filter.Prefixed<'seller_', SellerFields> & Filter.Prefixed<'store_', StoreFields> & Filter.Prefixed<'tags_', TagFields> & Filter.Prefixed<'variants_', VariantFields>>
  & Filter.Prefixed<'seller_', SellerFields>
  & Filter.Prefixed<'tax_category_', TaxCategoryFields>
  & Filter.OrFilters
  & {
    available_at_stock_location?: string
    product_name_or_sku_cont?: string
    search?: string
    search_by_product_name_or_sku?: string
  }
  & VariantFilterExtensions

export type VariantSort = Filter.SortKey<'carton_package_type_id' | 'carton_weight' | 'cartons_per_pallet' | 'cost_currency' | 'cost_price' | 'country_of_origin' | 'created_at' | 'deleted_at' | 'depth' | 'discontinue_on' | 'height' | 'hs_code' | 'id' | 'minimum_order_quantity' | 'order_multiple' | 'position' | 'product_id' | 'purchase_unit' | 'sku' | 'track_inventory' | 'units_per_carton' | 'updated_at' | 'weight' | 'width'>

export interface WebhookDeliveryFilterExtensions {}

export type WebhookDeliveryFilters = WebhookDeliveryFields
  & Filter.OrFilters
  & WebhookDeliveryFilterExtensions

export type WebhookDeliverySort = Filter.SortKey<'created_at' | 'delivered_at' | 'event_name' | 'execution_time' | 'id' | 'response_code' | 'success' | 'updated_at'>

export interface WebhookEndpointFilterExtensions {}

export type WebhookEndpointFilters = WebhookEndpointFields
  & Filter.OrFilters
  & WebhookEndpointFilterExtensions

export type WebhookEndpointSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at' | 'url'>
