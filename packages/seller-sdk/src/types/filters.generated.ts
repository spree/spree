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

export type ImportFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id' | 'type'>
  & Filter.TextFilters<'number'>
  & Filter.EnumFilters<'status', 'pending' | 'mapping' | 'completed_mapping' | 'processing' | 'completed' | 'failed'>

export type ImportRowFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.RangeFilters<'row_number', number>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed'>

export type OrderFields = Filter.IdFilters<'channel_id' | 'customer_id' | 'id' | 'order_group_id' | 'seller_id'>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'delivery_total' | 'item_total' | 'total' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'number' | 'po_number'>
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

export type ProductFields = Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'price' | 'updated_at'>
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

export type SellerPayoutFields = Filter.RangeFilters<'amount' | 'created_at' | 'period_end' | 'period_start' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'provider' | 'reference'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed' | 'unresolved'>

export type SellerTransferFields = Filter.RangeFilters<'amount' | 'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'provider' | 'reference'>
  & Filter.IdFilters<'id' | 'order_id' | 'payout_id' | 'seller_id'>
  & Filter.EnumFilters<'kind', 'earning' | 'refund_reversal'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed' | 'unresolved'>

export type ShippingLabelFields = Filter.TextFilters<'carrier' | 'tracking_number'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'source', 'purchased' | 'uploaded'>
  & Filter.EnumFilters<'status', 'purchased' | 'refund_requested' | 'refunded'>

export type StockLocationFields = Filter.BooleanFilters<'active' | 'default' | 'pickup_enabled' | 'returns_enabled'>
  & Filter.TextFilters<'country_code' | 'kind' | 'name' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>

export type TaxIdentifierFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

/**
 * Filters your app adds to Claim lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ClaimFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ClaimFilterExtensions {}

/** Sort fields your app adds to Claim lists, as keys: `{ erp_id: true }`. */
export interface ClaimSortExtensions {}

export type ClaimFilters = ClaimFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & ClaimFilterExtensions

export type ClaimSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at' | (keyof ClaimSortExtensions & string)>

/**
 * Filters your app adds to ClaimReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to Delivery lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 *     declare module '@spree/seller-sdk' {
 *       interface DeliveryMethodFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DeliveryMethodFilterExtensions {}

/** Sort fields your app adds to DeliveryMethod lists, as keys: `{ erp_id: true }`. */
export interface DeliveryMethodSortExtensions {}

export type DeliveryMethodFilters = DeliveryMethodFields
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
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to DeliveryZone lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface DeliveryZoneFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DeliveryZoneFilterExtensions {}

/** Sort fields your app adds to DeliveryZone lists, as keys: `{ erp_id: true }`. */
export interface DeliveryZoneSortExtensions {}

export type DeliveryZoneFilters = DeliveryZoneFields
  & Filter.OrFilters
  & DeliveryZoneFilterExtensions

export type DeliveryZoneSort = Filter.SortKey<'created_at' | 'delivery_profile_id' | 'id' | 'name' | 'updated_at' | (keyof DeliveryZoneSortExtensions & string)>

/**
 * Filters your app adds to Exchange lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ExchangeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ExchangeFilterExtensions {}

/** Sort fields your app adds to Exchange lists, as keys: `{ erp_id: true }`. */
export interface ExchangeSortExtensions {}

export type ExchangeFilters = ExchangeFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & ExchangeFilterExtensions

export type ExchangeSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at' | (keyof ExchangeSortExtensions & string)>

/**
 * Filters your app adds to Fulfillment lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to Import lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ImportFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ImportFilterExtensions {}

/** Sort fields your app adds to Import lists, as keys: `{ erp_id: true }`. */
export interface ImportSortExtensions {}

export type ImportFilters = ImportFields
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
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to Order lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface OrderFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface OrderFilterExtensions {}

/** Sort fields your app adds to Order lists, as keys: `{ erp_id: true }`. */
export interface OrderSortExtensions {}

export type OrderFilters = OrderFields
  & {
    complete?: boolean
    incomplete?: boolean
    partially_refunded?: boolean
    refunded?: boolean
  }
  & Filter.OrFilters
  & OrderFilterExtensions

export type OrderSort = Filter.SortKey<'channel_id' | 'completed_at' | 'created_at' | 'currency' | 'customer_id' | 'delivery_total' | 'fulfillment_status' | 'id' | 'item_total' | 'number' | 'order_group_id' | 'payment_state' | 'payment_status' | 'po_number' | 'seller_id' | 'shipment_state' | 'status' | 'total' | 'total_quantity' | 'updated_at' | (keyof OrderSortExtensions & string)>

/**
 * Filters your app adds to OrderCancellationReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to PackageType lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface PackageTypeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface PackageTypeFilterExtensions {}

/** Sort fields your app adds to PackageType lists, as keys: `{ erp_id: true }`. */
export interface PackageTypeSortExtensions {}

export type PackageTypeFilters = PackageTypeFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & PackageTypeFilterExtensions

export type PackageTypeSort = Filter.SortKey<'created_at' | 'default' | 'id' | 'kind' | 'name' | 'seller_id' | 'updated_at' | (keyof PackageTypeSortExtensions & string)>

/**
 * Filters your app adds to Policy lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to Product lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ProductFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ProductFilterExtensions {}

/** Sort fields your app adds to Product lists, as keys: `{ erp_id: true }`. */
export interface ProductSortExtensions {}

export type ProductFilters = ProductFields
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

/**
 * Filters your app adds to ProductType lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ProductTypeFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ProductTypeFilterExtensions {}

/** Sort fields your app adds to ProductType lists, as keys: `{ erp_id: true }`. */
export interface ProductTypeSortExtensions {}

export type ProductTypeFilters = ProductTypeFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & ProductTypeFilterExtensions

export type ProductTypeSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof ProductTypeSortExtensions & string)>

/**
 * Filters your app adds to Return lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface ReturnFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ReturnFilterExtensions {}

/** Sort fields your app adds to Return lists, as keys: `{ erp_id: true }`. */
export interface ReturnSortExtensions {}

export type ReturnFilters = ReturnFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & ReturnFilterExtensions

export type ReturnSort = Filter.SortKey<'created_at' | 'id' | 'number' | 'status' | 'updated_at' | (keyof ReturnSortExtensions & string)>

/**
 * Filters your app adds to ReturnReason lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to SellerPayout lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface SellerPayoutFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface SellerPayoutFilterExtensions {}

/** Sort fields your app adds to SellerPayout lists, as keys: `{ erp_id: true }`. */
export interface SellerPayoutSortExtensions {}

export type SellerPayoutFilters = SellerPayoutFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & SellerPayoutFilterExtensions

export type SellerPayoutSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'period_end' | 'period_start' | 'provider' | 'reference' | 'seller_id' | 'status' | 'updated_at' | (keyof SellerPayoutSortExtensions & string)>

/**
 * Filters your app adds to SellerTransfer lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface SellerTransferFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface SellerTransferFilterExtensions {}

/** Sort fields your app adds to SellerTransfer lists, as keys: `{ erp_id: true }`. */
export interface SellerTransferSortExtensions {}

export type SellerTransferFilters = SellerTransferFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & SellerTransferFilterExtensions

export type SellerTransferSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'id' | 'kind' | 'order_id' | 'payout_id' | 'provider' | 'reference' | 'seller_id' | 'status' | 'updated_at' | (keyof SellerTransferSortExtensions & string)>

/**
 * Filters your app adds to ShippingLabel lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
 * Filters your app adds to StockLocation lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
 *       interface StockLocationFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StockLocationFilterExtensions {}

/** Sort fields your app adds to StockLocation lists, as keys: `{ erp_id: true }`. */
export interface StockLocationSortExtensions {}

export type StockLocationFilters = StockLocationFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & StockLocationFilterExtensions

export type StockLocationSort = Filter.SortKey<'active' | 'country_code' | 'created_at' | 'default' | 'id' | 'kind' | 'name' | 'pickup_enabled' | 'returns_enabled' | 'seller_id' | 'state_code' | 'updated_at' | (keyof StockLocationSortExtensions & string)>

/**
 * Filters your app adds to TaxIdentifier lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/seller-sdk' {
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
