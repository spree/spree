// Main client

export type { RequestOptions, RetryConfig } from '@spree/sdk-core'
// Request infrastructure (re-export from sdk-core)
export { SpreeError } from '@spree/sdk-core'
export type {
  AuthTokens,
  DashboardOperations,
  LoginCredentials,
  MeResponse,
  PermissionRule,
  ReportingDimensionValue,
  ReportingMetricValue,
  ReportingQuery,
  ReportingResult,
  ReportingRow,
  ReportingSchema,
} from './admin-client'
// Admin client class (for advanced use / subclassing)
export { AdminClient } from './admin-client'
export type { AdminClientConfig, Client } from './client'
export { createAdminClient } from './client'

// Param types (request bodies)
export type * from './params'
// Runtime helpers exported from params.ts alongside their related types.
export { isMaskedSecret, PREFERENCE_MASK_TOKEN } from './params'

// All entity types
export * from './types'
