// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.

import type * as Filter from '@spree/sdk-core'

export type AddressFields = Filter.TextFilters<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'first_name' | 'last_name' | 'phone' | 'postal_code' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CategoryFields = Filter.BooleanFilters<'automatic'>
  & Filter.RangeFilters<'children_count' | 'depth' | 'position' | 'products_count', number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'parent_id'>
  & Filter.TextFilters<'name' | 'permalink' | 'pretty_name'>

export type CollectionFields = Filter.BooleanFilters<'automatic'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name' | 'permalink'>
  & Filter.RangeFilters<'position' | 'products_count', number>
  & Filter.EnumFilters<'sort_order', 'manual' | 'best_selling' | 'price asc' | 'price desc' | 'available_on desc' | 'available_on asc' | 'name asc' | 'name desc'>

export type CompanyMembershipFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CreditCardFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type DataRequestFields = Filter.RangeFilters<'completed_at' | 'created_at' | 'requested_at' | 'updated_at'>
  & Filter.TextFilters<'email' | 'number'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'kind', 'access' | 'erasure'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed'>

export type DeliveryMethodFields = Filter.BooleanFilters<'available_to_sellers' | 'storefront_visible'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.TextFilters<'name'>

export type GiftCardFields = Filter.TextFilters<'code' | 'currency'>
  & Filter.RangeFilters<'created_at' | 'expires_at' | 'updated_at'>
  & Filter.IdFilters<'created_by_id' | 'customer_id' | 'gift_card_batch_id' | 'id'>
  & Filter.EnumFilters<'state', 'active' | 'partially_redeemed' | 'redeemed' | 'canceled'>
  & Filter.EnumFilters<'status', 'active' | 'partially_redeemed' | 'redeemed' | 'canceled'>

export type OrderFields = Filter.IdFilters<'channel_id' | 'customer_id' | 'id' | 'order_group_id' | 'seller_id'>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'delivery_total' | 'item_total' | 'total' | 'updated_at'>
  & Filter.TextFilters<'currency' | 'number' | 'po_number'>
  & Filter.RangeFilters<'total_quantity', number>
  & Filter.EnumFilters<'fulfillment_status', 'backorder' | 'canceled' | 'partial' | 'unfulfilled' | 'fulfilled' | 'delivered' | 'pending' | 'ready' | 'shipped'>
  & Filter.EnumFilters<'payment_state', 'none' | 'authorized' | 'partially_paid' | 'paid' | 'partially_refunded' | 'refunded' | 'overcharged' | 'voided' | 'balance_due' | 'credit_owed' | 'failed' | 'void'>
  & Filter.EnumFilters<'payment_status', 'none' | 'authorized' | 'partially_paid' | 'paid' | 'partially_refunded' | 'refunded' | 'overcharged' | 'voided' | 'balance_due' | 'credit_owed' | 'failed' | 'void'>
  & Filter.EnumFilters<'shipment_state', 'backorder' | 'canceled' | 'partial' | 'unfulfilled' | 'fulfilled' | 'delivered' | 'pending' | 'ready' | 'shipped'>
  & Filter.EnumFilters<'status', 'draft' | 'placed' | 'canceled'>

export type PolicyFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'owner_id' | 'owner_type'>
  & Filter.TextFilters<'name'>

export type ProductFields = Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'price' | 'updated_at'>
  & Filter.TextFilters<'description' | 'name' | 'slug'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'archived' | 'proposed' | 'rejected'>

export type SellerFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type StoreCreditFields = Filter.RangeFilters<'amount' | 'created_at' | 'updated_at'>
  & Filter.TextFilters<'currency'>
  & Filter.IdFilters<'customer_id' | 'id'>

export type TagFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

export type WishlistFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.TextFilters<'name'>

/**
 * Filters your app adds to Address lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to Category lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
 *       interface CategoryFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface CategoryFilterExtensions {}

/** Sort fields your app adds to Category lists, as keys: `{ erp_id: true }`. */
export interface CategorySortExtensions {}

export type CategoryFilters = CategoryFields
  & {
    search?: string
  }
  & Filter.OrFilters
  & CategoryFilterExtensions

export type CategorySort = Filter.SortKey<'automatic' | 'children_count' | 'created_at' | 'depth' | 'id' | 'name' | 'parent_id' | 'permalink' | 'position' | 'pretty_name' | 'products_count' | 'updated_at' | (keyof CategorySortExtensions & string)>

/**
 * Filters your app adds to Collection lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to CompanyMembership lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to CreditCard lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to DataRequest lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
 *       interface DataRequestFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface DataRequestFilterExtensions {}

/** Sort fields your app adds to DataRequest lists, as keys: `{ erp_id: true }`. */
export interface DataRequestSortExtensions {}

export type DataRequestFilters = DataRequestFields
  & {
    access?: boolean
    erasure?: boolean
    in_progress?: boolean
  }
  & Filter.OrFilters
  & DataRequestFilterExtensions

export type DataRequestSort = Filter.SortKey<'completed_at' | 'created_at' | 'email' | 'id' | 'kind' | 'number' | 'requested_at' | 'status' | 'updated_at' | (keyof DataRequestSortExtensions & string)>

/**
 * Filters your app adds to DeliveryMethod lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to GiftCard lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
 *       interface GiftCardFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface GiftCardFilterExtensions {}

/** Sort fields your app adds to GiftCard lists, as keys: `{ erp_id: true }`. */
export interface GiftCardSortExtensions {}

export type GiftCardFilters = GiftCardFields
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
 * Filters your app adds to Order lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 * Filters your app adds to Policy lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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
 *     declare module '@spree/sdk' {
 *       interface ProductFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface ProductFilterExtensions {}

/** Sort fields your app adds to Product lists, as keys: `{ erp_id: true }`. */
export interface ProductSortExtensions {}

export type ProductFilters = ProductFields
  & Filter.Prefixed<'categories_', CategoryFields>
  & Filter.Prefixed<'collections_', CollectionFields>
  & Filter.Prefixed<'tags_', TagFields>
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

export type ProductSort = Filter.SortKey<'available_on' | 'best_selling' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'manual' | 'name' | 'price' | 'seller_id' | 'slug' | 'status' | 'updated_at' | (keyof ProductSortExtensions & string) | `cf_${string}`>

/**
 * Filters your app adds to Seller lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
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

export type SellerSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof SellerSortExtensions & string)>

/**
 * Filters your app adds to StoreCredit lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
 *       interface StoreCreditFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface StoreCreditFilterExtensions {}

/** Sort fields your app adds to StoreCredit lists, as keys: `{ erp_id: true }`. */
export interface StoreCreditSortExtensions {}

export type StoreCreditFilters = StoreCreditFields
  & {
    from_gift_card?: boolean
    outstanding?: boolean
  }
  & Filter.OrFilters
  & StoreCreditFilterExtensions

export type StoreCreditSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'customer_id' | 'id' | 'updated_at' | (keyof StoreCreditSortExtensions & string)>

/**
 * Filters your app adds to Wishlist lists. Generate them with `spree filters types`,
 * or declare them by hand in a file that has an `export`:
 *
 *     export {}
 *     declare module '@spree/sdk' {
 *       interface WishlistFilterExtensions { erp_id_eq?: string }
 *     }
 */
export interface WishlistFilterExtensions {}

/** Sort fields your app adds to Wishlist lists, as keys: `{ erp_id: true }`. */
export interface WishlistSortExtensions {}

export type WishlistFilters = WishlistFields
  & Filter.OrFilters
  & WishlistFilterExtensions

export type WishlistSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at' | (keyof WishlistSortExtensions & string)>
