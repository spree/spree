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
  from: number;
  to: number;
  in: number;
  previous: number | null;
  next: number | null;
}

export interface ListResponse<T> {
  data: T[];
}

export interface PaginatedResponse<T> extends ListResponse<T> {
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
  limit?: number;
  /** Sort order. Prefix with - for descending, e.g. '-created_at', 'name'. Comma-separated for multiple fields. */
  sort?: string;
  /** Associations to expand. Supports dot notation for nested expand (max 4 levels), e.g. ['variants', 'variants.images'] */
  expand?: string[];
  /** Fields to include in response, e.g. ['name', 'slug', 'price']. Omit to return all fields. 'id' is always included. */
  fields?: string[];
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
  /** When true, relaxes validation requirements (name, phone, zipcode, street) */
  quick_checkout?: boolean;
}
