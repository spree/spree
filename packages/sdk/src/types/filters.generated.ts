// This file is auto-generated from the filter tables in docs/api-reference by `pnpm generate:filters`. Do not edit directly.

import type * as Filter from '@spree/sdk-core'

export type AddressFields = Filter.TextFilters<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'first_name' | 'last_name' | 'phone' | 'postal_code' | 'state_code'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CategoryFields = Filter.TextFilters<'name' | 'permalink' | 'pretty_name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.RangeFilters<'children_count' | 'depth' | 'position' | 'products_count', number>
  & Filter.IdFilters<'id' | 'parent_id'>
  & Filter.BooleanFilters<'automatic'>

export type CollectionFields = Filter.TextFilters<'name' | 'permalink'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.RangeFilters<'position' | 'products_count', number>
  & Filter.IdFilters<'id'>
  & Filter.BooleanFilters<'automatic'>
  & Filter.EnumFilters<'sort_order', 'manual' | 'best_selling' | 'price asc' | 'price desc' | 'available_on desc' | 'available_on asc' | 'name asc' | 'name desc'>

export type CompanyMembershipFields = Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type CreditCardFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type DataRequestFields = Filter.TextFilters<'email' | 'number'>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'requested_at' | 'updated_at'>
  & Filter.IdFilters<'id'>
  & Filter.EnumFilters<'kind', 'access' | 'erasure'>
  & Filter.EnumFilters<'status', 'pending' | 'processing' | 'completed' | 'failed'>

export type DeliveryMethodFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.BooleanFilters<'available_to_sellers' | 'storefront_visible'>

export type GiftCardFields = Filter.TextFilters<'code' | 'currency'>
  & Filter.RangeFilters<'expires_at' | 'created_at' | 'updated_at'>
  & Filter.IdFilters<'created_by_id' | 'customer_id' | 'gift_card_batch_id' | 'id'>
  & Filter.EnumFilters<'status', 'active' | 'partially_redeemed' | 'redeemed' | 'canceled'>

export type OrderFields = Filter.TextFilters<'currency' | 'number' | 'po_number'>
  & Filter.RangeFilters<'delivery_total' | 'item_total' | 'total', string | number>
  & Filter.RangeFilters<'completed_at' | 'created_at' | 'updated_at'>
  & Filter.RangeFilters<'total_quantity', number>
  & Filter.IdFilters<'channel_id' | 'customer_id' | 'id' | 'order_group_id' | 'seller_id'>
  & Filter.EnumFilters<'fulfillment_status', 'backorder' | 'canceled' | 'partial' | 'unfulfilled' | 'fulfilled' | 'delivered' | 'pending' | 'ready' | 'shipped'>
  & Filter.EnumFilters<'payment_status', 'none' | 'authorized' | 'partially_paid' | 'paid' | 'partially_refunded' | 'refunded' | 'overcharged' | 'voided' | 'balance_due' | 'credit_owed' | 'failed' | 'void'>
  & Filter.EnumFilters<'status', 'draft' | 'placed' | 'canceled'>

export type PolicyFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id' | 'owner_id' | 'owner_type'>

export type ProductFields = Filter.TextFilters<'description' | 'name' | 'slug'>
  & Filter.RangeFilters<'available_on' | 'created_at' | 'discontinue_on' | 'updated_at'>
  & Filter.IdFilters<'id' | 'seller_id'>
  & Filter.EnumFilters<'status', 'draft' | 'active' | 'archived' | 'proposed' | 'rejected'>

export type SellerFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type StoreCreditFields = Filter.TextFilters<'currency'>
  & Filter.RangeFilters<'amount', string | number>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'customer_id' | 'id'>

export type TagFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type WishlistFields = Filter.TextFilters<'name'>
  & Filter.RangeFilters<'created_at' | 'updated_at'>
  & Filter.IdFilters<'id'>

export type AddressFilters = AddressFields
  & Filter.OrFilters

export type AddressSort = Filter.SortKey<'address1' | 'address2' | 'city' | 'company' | 'country_code' | 'created_at' | 'first_name' | 'id' | 'last_name' | 'phone' | 'postal_code' | 'state_code' | 'updated_at'>

export type CategoryFilters = CategoryFields
  & Filter.OrFilters

export type CategorySort = Filter.SortKey<'automatic' | 'children_count' | 'created_at' | 'depth' | 'id' | 'name' | 'parent_id' | 'permalink' | 'position' | 'pretty_name' | 'products_count' | 'updated_at'>

export type CollectionFilters = CollectionFields
  & Filter.OrFilters

export type CollectionSort = Filter.SortKey<'automatic' | 'created_at' | 'id' | 'name' | 'permalink' | 'position' | 'products_count' | 'sort_order' | 'updated_at'>

export type CompanyMembershipFilters = CompanyMembershipFields
  & Filter.OrFilters

export type CompanyMembershipSort = Filter.SortKey<'created_at' | 'id' | 'updated_at'>

export type CreditCardFilters = CreditCardFields
  & Filter.OrFilters

export type CreditCardSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export type DataRequestFilters = DataRequestFields
  & Filter.OrFilters
  & {
    access?: boolean
    erasure?: boolean
    in_progress?: boolean
  }

export type DataRequestSort = Filter.SortKey<'completed_at' | 'created_at' | 'email' | 'id' | 'kind' | 'number' | 'requested_at' | 'status' | 'updated_at'>

export type DeliveryMethodFilters = DeliveryMethodFields
  & Filter.OrFilters

export type DeliveryMethodSort = Filter.SortKey<'available_to_sellers' | 'created_at' | 'id' | 'name' | 'seller_id' | 'storefront_visible' | 'updated_at'>

export type GiftCardFilters = GiftCardFields
  & Filter.OrFilters
  & {
    active?: boolean
    expired?: boolean
    partially_redeemed?: boolean
    redeemed?: boolean
  }

export type GiftCardSort = Filter.SortKey<'code' | 'created_at' | 'created_by_id' | 'currency' | 'customer_id' | 'expires_at' | 'gift_card_batch_id' | 'id' | 'status' | 'updated_at'>

export type OrderFilters = OrderFields
  & Filter.OrFilters
  & {
    complete?: boolean
    incomplete?: boolean
    partially_refunded?: boolean
    refunded?: boolean
  }

export type OrderSort = Filter.SortKey<'channel_id' | 'completed_at' | 'created_at' | 'currency' | 'customer_id' | 'delivery_total' | 'fulfillment_status' | 'id' | 'item_total' | 'number' | 'order_group_id' | 'payment_status' | 'po_number' | 'seller_id' | 'status' | 'total' | 'total_quantity' | 'updated_at'>

export type PolicyFilters = PolicyFields
  & Filter.OrFilters

export type PolicySort = Filter.SortKey<'created_at' | 'id' | 'name' | 'owner_id' | 'owner_type' | 'updated_at'>

export type ProductFilters = ProductFields
  & Filter.Prefixed<'categories_', CategoryFields>
  & Filter.Prefixed<'collections_', CollectionFields>
  & Filter.Prefixed<'tags_', TagFields>
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

export type ProductSort = Filter.SortKey<'available_on' | 'best_selling' | 'created_at' | 'description' | 'discontinue_on' | 'id' | 'manual' | 'name' | 'price' | 'seller_id' | 'slug' | 'status' | 'updated_at' | `cf_${string}`>

export type SellerFilters = SellerFields
  & Filter.OrFilters

export type SellerSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>

export type StoreCreditFilters = StoreCreditFields
  & Filter.OrFilters
  & {
    from_gift_card?: boolean
    outstanding?: boolean
  }

export type StoreCreditSort = Filter.SortKey<'amount' | 'created_at' | 'currency' | 'customer_id' | 'id' | 'updated_at'>

export type WishlistFilters = WishlistFields
  & Filter.OrFilters

export type WishlistSort = Filter.SortKey<'created_at' | 'id' | 'name' | 'updated_at'>
