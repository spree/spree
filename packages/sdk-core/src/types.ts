// Locale defaults for client-level configuration
export interface LocaleDefaults {
  locale?: string
  currency?: string
  country?: string
  /** Channel code (e.g., 'pos', 'wholesale') sent as X-Spree-Channel */
  channel?: string
}

// API Response types
export interface PaginationMeta {
  page: number
  limit: number
  count: number
  pages: number
  from: number
  to: number
  in: number
  previous: number | null
  next: number | null
}

export interface ListResponse<T> {
  data: T[]
}

export interface PaginatedResponse<T> extends ListResponse<T> {
  meta: PaginationMeta
}

/**
 * One validation failure. The Admin API reports the Rails error `code`
 * alongside the resolved `message` and whatever values the validation
 * interpolates (`count`, `value`, …), so a client can render its own copy
 * and fall back to `message` when it has no translation for the code. `code`
 * is null for a message added as a bare string, which has no code to render.
 */
export interface ValidationErrorDetail {
  code: string | null
  message: string
  /**
   * True when the model gave this code its own wording rather than using the
   * code's default — a webhook URL reports `invalid` but answers "must be a
   * valid http or https URL". A client holding its own translation of `code`
   * should render `message` instead when this is set, or it loses what the
   * override was for. The server decides it, since the comparison is against
   * the code's default in the locale the message was resolved in.
   */
  specific?: boolean
  [interpolation: string]: unknown
}

export interface ErrorResponse {
  error: {
    code: string
    message: string
    /**
     * Per-attribute failures. The Store API reports plain message strings;
     * the Admin API reports {@link ValidationErrorDetail} objects.
     */
    details?: Record<string, string[] | ValidationErrorDetail[]>
  }
}

// Query params
export interface ListParams {
  page?: number
  limit?: number
  /** Sort order. Prefix with - for descending, e.g. '-created_at', 'name'. Comma-separated for multiple fields. */
  sort?: string
  /** Associations to expand. Supports dot notation for nested expand (max 4 levels), e.g. ['variants', 'variants.media'] */
  expand?: string[]
  /** Fields to include in response, e.g. ['name', 'slug', 'price']. Omit to return all fields. 'id' is always included. */
  fields?: string[]
}

// Address params
export interface AddressParams {
  first_name: string
  last_name: string
  address1: string
  address2?: string
  city: string
  postal_code: string
  phone?: string
  company?: string
  /** ISO 3166-1 alpha-2 country code (e.g., "US", "DE") */
  country_code: string
  /** ISO 3166-2 subdivision code without country prefix (e.g., "CA", "NY") */
  state_abbr?: string
  /** State name - used for countries without predefined states */
  state_name?: string
  /** When true, relaxes validation requirements (name, phone, postal_code, street) */
  quick_checkout?: boolean
  /** Set as default billing address */
  is_default_billing?: boolean
  /** Set as default shipping address */
  is_default_shipping?: boolean
}

// Authentication

/**
 * Built-in email/password login. The default when `provider` is omitted.
 */
export interface EmailPasswordLogin {
  provider?: 'email'
  email: string
  password: string
}

/**
 * Provider-dispatched login. The `provider` field selects a strategy registered
 * server-side in `Spree.store_authentication_strategies` (or `admin_authentication_strategies`).
 * Additional fields are forwarded to the strategy's `authenticate` method — consult its
 * documentation for the required shape (e.g. `{ provider: 'auth0', token: '<jwt>' }`).
 */
export interface ProviderLogin {
  provider: string
  [key: string]: unknown
}

export type LoginCredentials = EmailPasswordLogin | ProviderLogin
