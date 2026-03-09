// Re-export shared types from sdk-core
export type {
  LocaleDefaults,
  PaginationMeta,
  ListResponse,
  PaginatedResponse,
  ErrorResponse,
  ListParams,
} from '@spree/sdk-core';

// Admin-specific generated types will be re-exported here with unprefixed names
// once Typelizer is configured to generate admin types into this package.
// Example:
// export type { default as Product } from './generated/AdminProduct';
// export type { default as Order } from './generated/AdminOrder';
