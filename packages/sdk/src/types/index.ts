// Re-export all generated types
export * from './generated';

// Locale defaults for client-level configuration
export interface LocaleDefaults {
  locale?: string;
  currency?: string;
  country?: string;
}

// API Response types
export interface PaginationMeta {
  page: number;
  limit: number;
  count: number;
  pages: number;
}

export interface PaginatedResponse<T> {
  data: T[];
  meta: PaginationMeta;
}

export interface ErrorResponse {
  error: {
    code: string;
    message: string;
    details?: Record<string, string[]>;
  };
}

// Auth types
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
}

// Query params
export interface ListParams {
  page?: number;
  per_page?: number;
  includes?: string;
}

export interface ProductListParams extends ListParams {
  /** Sort order, e.g. 'price asc', 'created_at desc' */
  sort?: string;
  /** Full-text search across name and SKU */
  multi_search?: string;
  /** Filter: name contains */
  name_cont?: string;
  /** Filter: price >= value */
  price_gte?: number;
  /** Filter: price <= value */
  price_lte?: number;
  /** Filter: products in taxon */
  taxons_id_eq?: string;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | undefined;
}

export interface TaxonListParams extends ListParams {
  /** Sort order, e.g. 'name asc', 'created_at desc' */
  sort?: string;
  /** Filter: name contains */
  name_cont?: string;
  taxonomy_id_eq?: string | number;
  parent_id_eq?: string | number;
  depth_eq?: number;
  /** Any additional Ransack predicate */
  [key: string]: string | number | boolean | undefined;
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
  [key: string]: string | number | boolean | undefined;
}

// Cart operations
export interface CreateCartParams {
  /** Arbitrary key-value metadata (stored, not returned in responses) */
  metadata?: Record<string, unknown>;
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

// Address params
export interface AddressParams {
  firstname: string;
  lastname: string;
  address1: string;
  address2?: string;
  city: string;
  zipcode: string;
  phone?: string;
  company?: string;
  /** ISO 3166-1 alpha-2 country code (e.g., "US", "DE") */
  country_iso: string;
  /** ISO 3166-2 subdivision code without country prefix (e.g., "CA", "NY") */
  state_abbr?: string;
  /** State name - used for countries without predefined states */
  state_name?: string;
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
  label: string;
  count: number;
}

export interface OptionFilterOption extends FilterOption {
  name: string;
  position: number;
}

export interface TaxonFilterOption extends FilterOption {
  permalink: string;
}

export interface PriceRangeFilter {
  id: 'price';
  type: 'price_range';
  label: string;
  min: number;
  max: number;
  currency: string;
}

export interface AvailabilityFilter {
  id: 'availability';
  type: 'availability';
  label: string;
  options: FilterOption[];
}

export interface OptionFilter {
  id: string;
  type: 'option';
  label: string;
  name: string;
  options: OptionFilterOption[];
}

export interface TaxonFilter {
  id: 'taxons';
  type: 'taxon';
  label: string;
  options: TaxonFilterOption[];
}

export type ProductFilter = PriceRangeFilter | AvailabilityFilter | OptionFilter | TaxonFilter;

export interface SortOption {
  id: string;
  label: string;
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
