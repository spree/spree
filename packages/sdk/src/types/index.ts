import type { ListParams } from '@spree/sdk-core'
import type {
  CategoryFilters,
  CategorySort,
  CollectionFilters,
  CollectionSort,
  OrderFilters,
  OrderSort,
  ProductFilters,
  ProductSort,
} from './filters.generated'
import type { Cart as CartType } from './generated'
import type { AddressUpdateParams, CompanyAddressUpdateParams, LineItemInputParams } from './params'

export * from './filters.generated'
// Re-export all generated types (unprefixed: Product, Order, etc.)
export type {
  Address,
  Base,
  Cart,
  Category,
  Channel,
  Claim,
  ClaimLineItem,
  Collection,
  Company,
  CompanyInvitation,
  CompanyMembership,
  Country,
  CreditCard,
  Currency,
  Customer,
  CustomerGroup,
  CustomField,
  DeliveryMethod,
  DeliveryRate,
  DigitalAsset,
  DigitalLink,
  Discount,
  FreightSummary,
  Fulfillment,
  GiftCard,
  GiftCardBatch,
  Invitation,
  LineItem,
  Locale,
  Market,
  Media,
  NewsletterSubscriber,
  OptionType,
  OptionValue,
  Order,
  OrderGroup,
  Payment,
  PaymentMethod,
  PaymentSession,
  PaymentSetupSession,
  PaymentSource,
  Policy,
  Price,
  Product,
  Promotion,
  Refund,
  Return,
  ReturnLineItem,
  Seller,
  State,
  StockLocation,
  StoreCredit,
  Variant,
  Wishlist,
  WishlistItem,
} from './generated'
export type * from './params'

// Checkout requirement — a single unsatisfied checkout prerequisite
export interface CheckoutRequirement {
  /** Checkout step this requirement belongs to (e.g. "address", "payment") */
  step: string
  /** Field that needs to be satisfied (e.g. "email", "shipping_address") */
  field: string
  /** Human-readable message describing what's needed */
  message: string
}

// Cart warning type — convenience alias for the inline type from the generated Cart
export type CartWarning = CartType['warnings'][number]

// Hand-written domain types
export type {
  ErrorResponse,
  ListParams,
  ListResponse,
  LocaleDefaults,
  PaginatedResponse,
  PaginationMeta,
} from '@spree/sdk-core'

// Store auth types
export interface AuthTokens {
  token: string
  refresh_token: string
  user: {
    id: string
    email: string
    first_name: string | null
    last_name: string | null
  }
}

export type { EmailPasswordLogin, LoginCredentials, ProviderLogin } from '@spree/sdk-core'

export type ProductListParams = ListParams<ProductFilters, ProductSort>

export type CategoryListParams = ListParams<CategoryFilters, CategorySort>

export type CollectionListParams = ListParams<CollectionFilters, CollectionSort>

export type OrderListParams = ListParams<OrderFilters, OrderSort>

// Line item input for bulk cart/order operations
/** @deprecated Renamed to `LineItemInputParams`. */
export type LineItemInput = LineItemInputParams

/** @deprecated Split by action: `AddressCreateParams` and `AddressUpdateParams`. Removed in 6.1. */
export type AddressParams = AddressUpdateParams

/** @deprecated Split by action: `CompanyAddressCreateParams` and `CompanyAddressUpdateParams`. Removed in 6.1. */
export type CompanyAddressParams = CompanyAddressUpdateParams

// Cart operations
// Payments
// Payment Sessions
// Payment Setup Sessions
// Product Filters types
export interface FilterOption {
  id: string
  count: number
}

export interface OptionFilterOption extends FilterOption {
  name: string
  label: string
  position: number
  color_code: string | null
  image_url: string | null
}

export interface CategoryFilterOption {
  id: string
  name: string
  permalink: string
  count: number
}

export interface PriceRangeFilter {
  id: 'price'
  type: 'price_range'
  min: number
  max: number
  currency: string
}

export interface AvailabilityFilter {
  id: 'availability'
  type: 'availability'
  options: FilterOption[]
}

export interface OptionFilter {
  id: string
  type: 'option'
  name: string
  label: string
  kind: string
  options: OptionFilterOption[]
}

export interface CategoryFilter {
  id: 'categories'
  type: 'category'
  options: CategoryFilterOption[]
}

export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | CategoryFilter

export interface SortOption {
  id: string
}

export interface ProductFiltersResponse {
  filters: ProductFilter[]
  sort_options: SortOption[]
  default_sort: string
  total_count: number
}

export interface ProductFiltersParams {
  category_id?: string
  q?: Record<string, unknown>
}

// The building blocks of the generated filter types, for a declaration file
// that extends them (see `spree filters types`).
export type {
  BooleanFilters,
  CustomFieldValueFilters,
  EnumFilters,
  IdFilters,
  OrFilters,
  Prefixed,
  RangeFilters,
  SortKey,
  TextFilters,
} from '@spree/sdk-core'
// Named enums — open string unions for lists an extension may extend (statuses, fee kinds)
export type * from './generated/Enums'
