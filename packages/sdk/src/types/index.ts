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
import type {
  AppliedPromotion,
  Cart as CartType,
  ProductFilterAvailability,
  ProductFilterAvailabilityOption,
  ProductFilterCategory,
  ProductFilterCategoryOption,
  ProductFilterOption,
  ProductFilterOptionValue,
  ProductFilterPriceRange,
  ProductFilterSortOption,
  ProductFilters as ProductFiltersResult,
} from './generated'
import type { AddressUpdateParams, CompanyAddressUpdateParams, LineItemInputParams } from './params'

export * from './filters.generated'
// Re-export all generated types (unprefixed: Product, Order, etc.)
export type {
  Address,
  AddressOwner,
  AppliedPromotion,
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
  Delivery,
  DeliveryMethod,
  DeliveryRate,
  DigitalAsset,
  DigitalLink,
  Fee,
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
  SelectableAddress,
  Seller,
  State,
  StockLocation,
  StoreCredit,
  TaxLine,
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

/** @deprecated Renamed to `LineItemInputParams`. Removed in 6.1. */
export type LineItemInput = LineItemInputParams

/** @deprecated Split by action: `AddressCreateParams` and `AddressUpdateParams`. Removed in 6.1. */
export type AddressParams = AddressUpdateParams

/** @deprecated Split by action: `CompanyAddressCreateParams` and `CompanyAddressUpdateParams`. Removed in 6.1. */
export type CompanyAddressParams = CompanyAddressUpdateParams

/** @deprecated Renamed to `AppliedPromotion`, the type of `cart.discounts` and `order.discounts`. Removed in 6.1. */
export type Discount = AppliedPromotion

// Product filters: the names storefronts import, kept as aliases of the generated types
export type FilterOption = ProductFilterAvailabilityOption
export type OptionFilterOption = ProductFilterOptionValue
export type CategoryFilterOption = ProductFilterCategoryOption
export type PriceRangeFilter = ProductFilterPriceRange
export type AvailabilityFilter = ProductFilterAvailability
export type OptionFilter = ProductFilterOption
export type CategoryFilter = ProductFilterCategory
export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | CategoryFilter
export type SortOption = ProductFilterSortOption
export type ProductFiltersResponse = ProductFiltersResult

export interface ProductFiltersParams {
  category_id?: string
  collection_id?: string
  /** The listing's active filters, so the counts describe the products it shows. */
  q?: ProductFilters & Record<string, unknown>
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
