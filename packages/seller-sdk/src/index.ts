export type { RequestOptions, RetryConfig } from '@spree/sdk-core'
// Request infrastructure (re-exported from sdk-core)
export { SpreeError } from '@spree/sdk-core'
// `Client` is the whole configured client (auth + resources + token/seller
// setters); `SellerClient` below is just the resource group. Exported under
// both names so hosts can say what they mean.
export type { Client, Client as SellerApiClient, SellerClientConfig } from './client'
export { createSellerClient } from './client'
export type {
  MeResponse,
  OnboardingResponse,
  PermissionRule,
  ProductParams,
  ProfileUpdateParams,
  RequirementSubmissionParams,
  SellerAddressParams,
} from './seller-client'
// Client class, for advanced use and subclassing
export { SellerClient } from './seller-client'
export type * from './types'
