// Re-export shared types from sdk-core
export type {
  ErrorResponse,
  ListParams,
  ListResponse,
  PaginatedResponse,
  PaginationMeta,
} from '@spree/sdk-core'

// Generated from the Seller API's serializers (`Spree::Api::V3::Seller::*`).
// `TeamMember`, `Invitation`, `Profile` and `Address` come from here — the
// serializers are the contract, so hand-writing them again would let the two
// drift apart silently.
export * from './generated'

import type { default as TeamMember } from './generated/TeamMember'

/**
 * A seller as the login and `/me` responses summarise it — enough for the
 * panel to let a seller choose which seller to act as.
 */
export interface SellerSummary {
  id: string
  name: string
  slug?: string
  status: string
}

/** What the login and refresh endpoints answer. */
export interface AuthTokens {
  token: string
  user: TeamMember
  sellers: SellerSummary[]
}

export type { default as Delivery } from './generated/Delivery'
export type { default as ShippingLabel } from './generated/ShippingLabel'
