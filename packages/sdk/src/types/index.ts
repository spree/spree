import type { ListParams, AddressParams } from '@spree/sdk-core';

// Re-export generated Store types with unprefixed names
export type { default as Address } from './generated/StoreAddress';
export type { default as Asset } from './generated/StoreAsset';
export type { default as Country } from './generated/StoreCountry';
export type { default as CreditCard } from './generated/StoreCreditCard';
export type { default as Currency } from './generated/StoreCurrency';
export type { default as CustomerReturn } from './generated/StoreCustomerReturn';
export type { default as Customer } from './generated/StoreCustomer';
export type { default as DigitalLink } from './generated/StoreDigitalLink';
export type { default as Digital } from './generated/StoreDigital';
export type { default as GiftCardBatch } from './generated/StoreGiftCardBatch';
export type { default as GiftCard } from './generated/StoreGiftCard';
export type { default as Image } from './generated/StoreImage';
export type { default as LineItem } from './generated/StoreLineItem';
export type { default as Locale } from './generated/StoreLocale';
export type { default as Market } from './generated/StoreMarket';
export type { default as Metafield } from './generated/StoreMetafield';
export type { default as OptionType } from './generated/StoreOptionType';
export type { default as OptionValue } from './generated/StoreOptionValue';
export type { default as OrderPromotion } from './generated/StoreOrderPromotion';
export type { default as Order } from './generated/StoreOrder';
export type { default as PaymentMethod } from './generated/StorePaymentMethod';
export type { default as Payment } from './generated/StorePayment';
export type { default as PaymentSession } from './generated/StorePaymentSession';
export type { default as PaymentSetupSession } from './generated/StorePaymentSetupSession';
export type { default as PaymentSource } from './generated/StorePaymentSource';
export type { default as Price } from './generated/StorePrice';
export type { default as Product } from './generated/StoreProduct';
export type { default as Promotion } from './generated/StorePromotion';
export type { default as Refund } from './generated/StoreRefund';
export type { default as Reimbursement } from './generated/StoreReimbursement';
export type { default as ReturnAuthorization } from './generated/StoreReturnAuthorization';
export type { default as ReturnItem } from './generated/StoreReturnItem';
export type { default as Shipment } from './generated/StoreShipment';
export type { default as ShippingCategory } from './generated/StoreShippingCategory';
export type { default as ShippingMethod } from './generated/StoreShippingMethod';
export type { default as ShippingRate } from './generated/StoreShippingRate';
export type { default as State } from './generated/StoreState';
export type { default as StockItem } from './generated/StoreStockItem';
export type { default as StockLocation } from './generated/StoreStockLocation';
export type { default as StoreCredit } from './generated/StoreStoreCredit';
export type { default as TaxCategory } from './generated/StoreTaxCategory';
export type { default as Taxon } from './generated/StoreTaxon';
export type { default as Taxonomy } from './generated/StoreTaxonomy';
export type { default as Variant } from './generated/StoreVariant';
export type { default as WishedItem } from './generated/StoreWishedItem';
export type { default as Wishlist } from './generated/StoreWishlist';

// Also re-export with Store* prefix for backward compatibility
export type { default as StoreAddress } from './generated/StoreAddress';
export type { default as StoreAsset } from './generated/StoreAsset';
export type { default as StoreCountry } from './generated/StoreCountry';
export type { default as StoreCreditCard } from './generated/StoreCreditCard';
export type { default as StoreCurrency } from './generated/StoreCurrency';
export type { default as StoreCustomerReturn } from './generated/StoreCustomerReturn';
export type { default as StoreCustomer } from './generated/StoreCustomer';
export type { default as StoreDigitalLink } from './generated/StoreDigitalLink';
export type { default as StoreDigital } from './generated/StoreDigital';
export type { default as StoreGiftCardBatch } from './generated/StoreGiftCardBatch';
export type { default as StoreGiftCard } from './generated/StoreGiftCard';
export type { default as StoreImage } from './generated/StoreImage';
export type { default as StoreLineItem } from './generated/StoreLineItem';
export type { default as StoreLocale } from './generated/StoreLocale';
export type { default as StoreMarket } from './generated/StoreMarket';
export type { default as StoreMetafield } from './generated/StoreMetafield';
export type { default as StoreOptionType } from './generated/StoreOptionType';
export type { default as StoreOptionValue } from './generated/StoreOptionValue';
export type { default as StoreOrderPromotion } from './generated/StoreOrderPromotion';
export type { default as StoreOrder } from './generated/StoreOrder';
export type { default as StorePaymentMethod } from './generated/StorePaymentMethod';
export type { default as StorePayment } from './generated/StorePayment';
export type { default as StorePaymentSession } from './generated/StorePaymentSession';
export type { default as StorePaymentSetupSession } from './generated/StorePaymentSetupSession';
export type { default as StorePaymentSource } from './generated/StorePaymentSource';
export type { default as StorePrice } from './generated/StorePrice';
export type { default as StoreProduct } from './generated/StoreProduct';
export type { default as StorePromotion } from './generated/StorePromotion';
export type { default as StoreRefund } from './generated/StoreRefund';
export type { default as StoreReimbursement } from './generated/StoreReimbursement';
export type { default as StoreReturnAuthorization } from './generated/StoreReturnAuthorization';
export type { default as StoreReturnItem } from './generated/StoreReturnItem';
export type { default as StoreShipment } from './generated/StoreShipment';
export type { default as StoreShippingCategory } from './generated/StoreShippingCategory';
export type { default as StoreShippingMethod } from './generated/StoreShippingMethod';
export type { default as StoreShippingRate } from './generated/StoreShippingRate';
export type { default as StoreState } from './generated/StoreState';
export type { default as StoreStockItem } from './generated/StoreStockItem';
export type { default as StoreStockLocation } from './generated/StoreStockLocation';
export type { default as StoreStoreCredit } from './generated/StoreStoreCredit';
export type { default as StoreTaxCategory } from './generated/StoreTaxCategory';
export type { default as StoreTaxon } from './generated/StoreTaxon';
export type { default as StoreTaxonomy } from './generated/StoreTaxonomy';
export type { default as StoreVariant } from './generated/StoreVariant';
export type { default as StoreWishedItem } from './generated/StoreWishedItem';
export type { default as StoreWishlist } from './generated/StoreWishlist';

// Hand-written domain types
export type {
  LocaleDefaults,
  PaginationMeta,
  ListResponse,
  PaginatedResponse,
  ErrorResponse,
  AuthTokens,
  LoginCredentials,
  RegisterParams,
  ListParams,
  AddressParams,
} from '@spree/sdk-core';

export interface ProductListParams extends ListParams {
  /** Sort: 'price', '-price', 'best_selling', 'name', '-name', '-available_on', 'available_on' */
  sort?: string;
  /** Full-text search across name and SKU */
  multi_search?: string;
  /** Filter: name contains */
  name_cont?: string;
  /** Filter: price >= value */
  price_gte?: number;
  /** Filter: price <= value */
  price_lte?: number;
  /** Filter by option value prefix IDs */
  with_option_value_ids?: string[];
  /** Filter: only in-stock products */
  in_stock?: boolean;
  /** Filter: only out-of-stock products */
  out_of_stock?: boolean;
  /** Filter: products in taxon */
  taxons_id_eq?: string;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined;
}

export interface TaxonListParams extends ListParams {
  /** Sort order, e.g. 'name', '-created_at' */
  sort?: string;
  /** Filter: name contains */
  name_cont?: string;
  taxonomy_id_eq?: string | number;
  parent_id_eq?: string | number;
  depth_eq?: number;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined;
}

export interface OrderListParams extends ListParams {
  /** Sort order, e.g. 'completed_at desc' */
  sort?: string;
  /** Full-text search across number, email, customer name */
  multi_search?: string;
  state_eq?: string;
  completed_at_gte?: string;
  completed_at_lte?: string;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined;
}

// Line item input for bulk cart/order operations
export interface LineItemInput {
  /** Prefixed variant ID (e.g., "variant_k5nR8xLq") */
  variant_id: string;
  /** Quantity to set (defaults to 1 if omitted) */
  quantity?: number;
  /** Arbitrary key-value metadata (merged with existing on upsert) */
  metadata?: Record<string, unknown>;
}

// Cart operations
export interface CreateCartParams {
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>;
  /** Line items to add to the cart on creation */
  line_items?: LineItemInput[];
}

export interface AddLineItemParams {
  variant_id: string;
  quantity: number;
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>;
}

export interface UpdateLineItemParams {
  quantity?: number;
  /** Arbitrary key-value metadata (merged with existing) */
  metadata?: Record<string, unknown>;
}

export interface UpdateOrderParams {
  email?: string;
  currency?: string;
  locale?: string;
  special_instructions?: string;
  /** Arbitrary key-value metadata (merged with existing) */
  metadata?: Record<string, unknown>;
  /** Existing address ID to use */
  bill_address_id?: string;
  /** Existing address ID to use */
  ship_address_id?: string;
  /** New billing address */
  bill_address?: AddressParams;
  /** New shipping address */
  ship_address?: AddressParams;
  /** Line items to upsert (sets quantity for existing, creates new) */
  line_items?: LineItemInput[];
}

// Payment Sessions
export interface CreatePaymentSessionParams {
  payment_method_id: string;
  amount?: string;
  external_data?: Record<string, unknown>;
}

export interface UpdatePaymentSessionParams {
  amount?: string;
  external_data?: Record<string, unknown>;
}

export interface CompletePaymentSessionParams {
  session_result?: string;
  external_data?: Record<string, unknown>;
}

// Payment Setup Sessions
export interface CreatePaymentSetupSessionParams {
  payment_method_id: string;
  external_data?: Record<string, unknown>;
}

export interface CompletePaymentSetupSessionParams {
  external_data?: Record<string, unknown>;
}

// Product Filters types
export interface FilterOption {
  id: string;
  count: number;
}

export interface OptionFilterOption extends FilterOption {
  name: string;
  presentation: string;
  position: number;
}

export interface TaxonFilterOption {
  id: string;
  name: string;
  permalink: string;
  count: number;
}

export interface PriceRangeFilter {
  id: 'price';
  type: 'price_range';
  min: number;
  max: number;
  currency: string;
}

export interface AvailabilityFilter {
  id: 'availability';
  type: 'availability';
  options: FilterOption[];
}

export interface OptionFilter {
  id: string;
  type: 'option';
  name: string;
  presentation: string;
  options: OptionFilterOption[];
}

export interface TaxonFilter {
  id: 'taxons';
  type: 'taxon';
  options: TaxonFilterOption[];
}

export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | TaxonFilter;

export interface SortOption {
  id: string;
}

export interface ProductFiltersResponse {
  filters: ProductFilter[];
  sort_options: SortOption[];
  default_sort: string;
  total_count: number;
}

export interface ProductFiltersParams {
  taxon_id?: string;
  q?: Record<string, unknown>;
}
