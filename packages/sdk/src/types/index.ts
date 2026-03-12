import type { ListParams, AddressParams } from '@spree/sdk-core';

// Re-export all generated types (unprefixed: Product, Order, etc.)
export type {
  Address,
  Asset,
  Base,
  Cart,
  CartPromotion,
  Category,
  Country,
  CreditCard,
  Currency,
  CustomerReturn,
  Customer,
  DigitalLink,
  Digital,
  Export,
  GiftCardBatch,
  GiftCard,
  Image,
  ImportRow,
  Import,
  Invitation,
  LineItem,
  Locale,
  Market,
  Metafield,
  NewsletterSubscriber,
  OptionType,
  OptionValue,
  OrderPromotion,
  Order,
  PaymentMethod,
  Payment,
  PaymentSession,
  PaymentSetupSession,
  PaymentSource,
  Price,
  Product,
  Promotion,
  Refund,
  Reimbursement,
  Report,
  ReturnAuthorization,
  ReturnItem,
  Shipment,
  ShippingCategory,
  ShippingMethod,
  ShippingRate,
  State,
  StockItem,
  StockLocation,
  StockMovement,
  StockTransfer,
  StoreCredit,
  TaxCategory,
  Variant,
  WishedItem,
  Wishlist,
} from './generated';

// Backward compatibility aliases (Store* prefix)
export type { Address as StoreAddress } from './generated';
export type { Asset as StoreAsset } from './generated';
export type { Cart as StoreCart } from './generated';
export type { Category as StoreCategory } from './generated';
export type { Country as StoreCountry } from './generated';
export type { CreditCard as StoreCreditCard } from './generated';
export type { Currency as StoreCurrency } from './generated';
export type { CustomerReturn as StoreCustomerReturn } from './generated';
export type { Customer as StoreCustomer } from './generated';
export type { DigitalLink as StoreDigitalLink } from './generated';
export type { Digital as StoreDigital } from './generated';
export type { GiftCardBatch as StoreGiftCardBatch } from './generated';
export type { GiftCard as StoreGiftCard } from './generated';
export type { Image as StoreImage } from './generated';
export type { LineItem as StoreLineItem } from './generated';
export type { Locale as StoreLocale } from './generated';
export type { Market as StoreMarket } from './generated';
export type { Metafield as StoreMetafield } from './generated';
export type { OptionType as StoreOptionType } from './generated';
export type { OptionValue as StoreOptionValue } from './generated';
export type { CartPromotion as StoreCartPromotion } from './generated';
export type { OrderPromotion as StoreOrderPromotion } from './generated';
export type { Order as StoreOrder } from './generated';
export type { PaymentMethod as StorePaymentMethod } from './generated';
export type { Payment as StorePayment } from './generated';
export type { PaymentSession as StorePaymentSession } from './generated';
export type { PaymentSetupSession as StorePaymentSetupSession } from './generated';
export type { PaymentSource as StorePaymentSource } from './generated';
export type { Price as StorePrice } from './generated';
export type { Product as StoreProduct } from './generated';
export type { Promotion as StorePromotion } from './generated';
export type { Refund as StoreRefund } from './generated';
export type { Reimbursement as StoreReimbursement } from './generated';
export type { ReturnAuthorization as StoreReturnAuthorization } from './generated';
export type { ReturnItem as StoreReturnItem } from './generated';
export type { Shipment as StoreShipment } from './generated';
export type { ShippingCategory as StoreShippingCategory } from './generated';
export type { ShippingMethod as StoreShippingMethod } from './generated';
export type { ShippingRate as StoreShippingRate } from './generated';
export type { State as StoreState } from './generated';
export type { StockItem as StoreStockItem } from './generated';
export type { StockLocation as StoreStockLocation } from './generated';
export type { StoreCredit as StoreStoreCredit } from './generated';
export type { TaxCategory as StoreTaxCategory } from './generated';
export type { Variant as StoreVariant } from './generated';
export type { WishedItem as StoreWishedItem } from './generated';
export type { Wishlist as StoreWishlist } from './generated';

// Checkout requirement — a single unsatisfied checkout prerequisite
export interface CheckoutRequirement {
  /** Checkout step this requirement belongs to (e.g. "address", "payment") */
  step: string;
  /** Field that needs to be satisfied (e.g. "email", "ship_address") */
  field: string;
  /** Human-readable message describing what's needed */
  message: string;
}

// Hand-written domain types
export type {
  LocaleDefaults,
  PaginationMeta,
  ListResponse,
  PaginatedResponse,
  ErrorResponse,
  ListParams,
  AddressParams,
} from '@spree/sdk-core';

// Store auth types
export interface AuthTokens {
  token: string;
  user: {
    id: string;
    email: string;
    first_name: string | null;
    last_name: string | null;
  };
}

export interface LoginCredentials {
  email: string;
  password: string;
}

export interface RegisterParams {
  email: string;
  password: string;
  password_confirmation: string;
  first_name?: string;
  last_name?: string;
  phone?: string;
  accepts_email_marketing?: boolean;
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>;
}

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
  /** Filter: products in category */
  categories_id_eq?: string;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | (string | number)[] | undefined;
}

export interface CategoryListParams extends ListParams {
  /** Sort order, e.g. 'name', '-created_at' */
  sort?: string;
  /** Filter: name contains */
  name_cont?: string;
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

export interface UpdateCheckoutParams {
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

// Payments
export interface CreatePaymentParams {
  payment_method_id: string;
  amount?: string;
  metadata?: Record<string, unknown>;
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

export interface CategoryFilterOption {
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

export interface CategoryFilter {
  id: 'categories';
  type: 'category';
  options: CategoryFilterOption[];
}

export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | CategoryFilter;

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
  category_id?: string;
  q?: Record<string, unknown>;
}
