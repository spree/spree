import type { ListParams, AddressParams } from '@spree/sdk-core';
import type { Cart as CartType } from './generated';

// Re-export all generated types (unprefixed: Product, Order, etc.)
export type {
  Address,
  Base,
  Cart,
  Category,
  Country,
  CreditCard,
  Currency,
  Customer,
  DigitalLink,
  Digital,
  Discount,
  GiftCardBatch,
  GiftCard,
  Media,
  Invitation,
  LineItem,
  Locale,
  Market,
  CustomField,
  NewsletterSubscriber,
  OptionType,
  OptionValue,
  Order,
  PaymentMethod,
  Payment,
  PaymentSession,
  PaymentSetupSession,
  PaymentSource,
  Policy,
  Price,
  Product,
  Promotion,
  Refund,
  ReturnAuthorization,
  ReturnItem,
  DeliveryMethod,
  DeliveryRate,
  Fulfillment,
  State,
  StockLocation,
  StoreCredit,
  Variant,
  WishlistItem,
  Wishlist,
} from './generated';

// Checkout requirement — a single unsatisfied checkout prerequisite
export interface CheckoutRequirement {
  /** Checkout step this requirement belongs to (e.g. "address", "payment") */
  step: string;
  /** Field that needs to be satisfied (e.g. "email", "shipping_address") */
  field: string;
  /** Human-readable message describing what's needed */
  message: string;
}

// Cart warning type — convenience alias for the inline type from the generated Cart
export type CartWarning = CartType['warnings'][number];

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
  refresh_token: string;
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

export interface RequestPasswordResetParams {
  email: string;
  redirect_url?: string;
}

export interface ResetPasswordParams {
  password: string;
  password_confirmation: string;
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
  search?: string;
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
  /** Filter: products in category (includes descendants) */
  in_category?: string;
  /** Filter: products in any of the given categories (includes descendants, OR logic) */
  in_categories?: string[];
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
  search?: string;
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
  /** Items to add to the cart on creation */
  items?: LineItemInput[];
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

export interface UpdateCartParams {
  email?: string;
  currency?: string;
  locale?: string;
  customer_note?: string;
  /** Arbitrary key-value metadata (merged with existing) */
  metadata?: Record<string, unknown>;
  /** Existing address ID to use as billing address */
  billing_address_id?: string;
  /** Existing address ID to use as shipping address */
  shipping_address_id?: string;
  /** New billing address */
  billing_address?: AddressParams;
  /** New shipping address */
  shipping_address?: AddressParams;
  /** When true, copies shipping address to billing address */
  use_shipping?: boolean;
  /** Items to upsert (sets quantity for existing, creates new) */
  items?: LineItemInput[];
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
  label: string;
  position: number;
  color_code: string | null;
  image_url: string | null;
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
  label: string;
  kind: string;
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
