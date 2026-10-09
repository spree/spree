// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.

import type * as Filter from '@spree/sdk-core'

export type ClaimFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'status', 'open' | 'approved' | 'resolved' | 'denied' | 'canceled'>

export type ClaimReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type DeliveryMethodFields = Filter.BooleanFilters<'available_to_sellers' | 'storefront_visible'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.TextFilters<'name'>

export type DeliveryProfileFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>
  & Filter.RangeFilters<'position', number>

export type DeliveryZoneFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'delivery_profile_id' | 'id'>
  & Filter.TextFilters<'name'>

export type ExchangeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'status', 'requested' | 'approved' | 'received' | 'fulfilled' | 'canceled'>

export type FulfillmentFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'number'>

export type OrderFields = Filter.IdFilters<'channel_id' | 'customer_id' | 'id' | 'order_group_id' | 'seller_id'>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'number' | 'po_number'>
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

export type PackageTypeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.BooleanFilters<'default'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.TextFilters<'name'>
  & Filter.EnumFilters<'kind', 'box' | 'envelope' | 'carton' | 'pallet' | 'container'>

export type PolicyFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'owner_id' | 'owner_type'>
  & Filter.TextFilters<'name'>

export type ProductFields = Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'updated_at'>
  & Filter.TextFilters<'description' | 'name' | 'slug'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'archived' | 'proposed' | 'rejected'>

export type ProductTypeFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type ReturnFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'status', 'requested' | 'approved' | 'received' | 'refunded' | 'canceled'>

export type ReturnReasonFields = Filter.BooleanFilters<'active'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type SellerPayoutFields = Filter.RangeFilters<'amount', string | number>
  & Filter.RangeFilters<'created_at' | 'period_end' | 'period_start' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'provider' | 'reference'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed' | 'unresolved'>

export type SellerTransferFields = Filter.RangeFilters<'amount', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'provider' | 'reference'>
  & Filter.IdFilters<'id' | 'order_id' | 'payout_id' | 'seller_id'>
  & Filter.EnumFilters<'kind', 'earning' | 'refund_reversal'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed' | 'unresolved'>

export type StockLocationFields = Filter.BooleanFilters<'active' | 'default' | 'pickup_enabled' | 'returns_enabled'>
  & Filter.TextFilters<'country_code' | 'kind' | 'name' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>

export type TaxIdentifierFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export interface ClaimFilterExtensions {}

export type ClaimFilters = ClaimFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & ClaimFilterExtensions

export type ClaimSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at'>

export interface ClaimReasonFilterExtensions {}

export type ClaimReasonFilters = ClaimReasonFields
  & Filter.OrFilters
  & ClaimReasonFilterExtensions

export type ClaimReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface DeliveryMethodFilterExtensions {}

export type DeliveryMethodFilters = DeliveryMethodFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & DeliveryMethodFilterExtensions

export type DeliveryMethodSort = Filter.SortKey<'available_to_sellers' | 'created_at' | 'id' | 'name' | 'seller_id' | 'storefront_visible' | 'updated_at'>

export interface DeliveryProfileFilterExtensions {}

export type DeliveryProfileFilters = DeliveryProfileFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & DeliveryProfileFilterExtensions

export type DeliveryProfileSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'position' | 'updated_at'>

export interface DeliveryZoneFilterExtensions {}

export type DeliveryZoneFilters = DeliveryZoneFields
  & Filter.OrFilters
  & DeliveryZoneFilterExtensions

export type DeliveryZoneSort = Filter.SortKey<'created_at' | 'delivery_profile_id' | 'id' | 'name' | 'updated_at'>

export interface ExchangeFilterExtensions {}

export type ExchangeFilters = ExchangeFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & ExchangeFilterExtensions

export type ExchangeSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at'>

export interface FulfillmentFilterExtensions {}

export type FulfillmentFilters = FulfillmentFields
  & Filter.OrFilters
  & FulfillmentFilterExtensions

export type FulfillmentSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'updated_at'>

export interface OrderFilterExtensions {}

export type OrderFilters = OrderFields
  & Filter.OrFilters
  & {
    complete?: boolean
    incomplete?: boolean
    partially_refunded?: boolean
    refunded?: boolean
  }
  & OrderFilterExtensions

export type OrderSort = Filter.SortKey<'channel_id' | 'completed_at' | 'created_at' | 'currency' | 'customer_id' | 'delivery_total' | 'fulfillment_status' | 'id' | 'item_total' | 'number' | 'order_group_id' | 'payment_state' | 'payment_status' | 'po_number' | 'seller_id' | 'shipment_state' | 'status' | 'total' | 'total_quantity' | 'updated_at'>

export interface OrderCancellationReasonFilterExtensions {}

export type OrderCancellationReasonFilters = OrderCancellationReasonFields
  & Filter.OrFilters
  & OrderCancellationReasonFilterExtensions

export type OrderCancellationReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface PackageTypeFilterExtensions {}

export type PackageTypeFilters = PackageTypeFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & PackageTypeFilterExtensions

export type PackageTypeSort = Filter.SortKey<'created_at' | 'default' | 'id' | 'kind' | 'name' | 'seller_id' | 'updated_at'>

export interface PolicyFilterExtensions {}

export type PolicyFilters = PolicyFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & PolicyFilterExtensions

export type PolicySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'owner_id' | 'owner_type' | 'updated_at'>

export interface ProductFilterExtensions {}

export type ProductFilters = ProductFields
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
  & ProductFilterExtensions

export type ProductSort = Filter.SortKey<'available_on' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'name' | 'seller_id' | 'slug' | 'status' | 'updated_at'>

export interface ProductTypeFilterExtensions {}

export type ProductTypeFilters = ProductTypeFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & ProductTypeFilterExtensions

export type ProductTypeSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export interface ReturnFilterExtensions {}

export type ReturnFilters = ReturnFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & ReturnFilterExtensions

export type ReturnSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at'>

export interface ReturnReasonFilterExtensions {}

export type ReturnReasonFilters = ReturnReasonFields
  & Filter.OrFilters
  & ReturnReasonFilterExtensions

export type ReturnReasonSort = Filter.SortKey<'active' | 'created_at' | 'id' | 'name' | 'updated_at'>

export interface SellerPayoutFilterExtensions {}

export type SellerPayoutFilters = SellerPayoutFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & SellerPayoutFilterExtensions

export type SellerPayoutSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'period_end' | 'period_start' | 'provider' | 'reference' | 'seller_id' | 'status' | 'updated_at'>

export interface SellerTransferFilterExtensions {}

export type SellerTransferFilters = SellerTransferFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & SellerTransferFilterExtensions

export type SellerTransferSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'kind' | 'order_id' | 'payout_id' | 'provider' | 'reference' | 'seller_id' | 'status' | 'updated_at'>

export interface StockLocationFilterExtensions {}

export type StockLocationFilters = StockLocationFields
  & Filter.OrFilters
  & {
    search?: string
  }
  & StockLocationFilterExtensions

export type StockLocationSort = Filter.SortKey<'active' | 'country_code' | 'created_at' | 'default' | 'id' | 'kind' | 'name' | 'pickup_enabled' | 'returns_enabled' | 'seller_id' | 'state_code' | 'updated_at'>

export interface TaxIdentifierFilterExtensions {}

export type TaxIdentifierFilters = TaxIdentifierFields
  & Filter.OrFilters
  & TaxIdentifierFilterExtensions

export type TaxIdentifierSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>
