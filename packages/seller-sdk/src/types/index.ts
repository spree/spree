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

import type { default as Account } from './generated/Account'

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
  /**
   * `Account`, not `TeamMember`: the panel adopts the signed-in person's saved
   * language from this payload at sign-in, which is what carries the choice to
   * a second browser. Serialized only for the person signing in, so it does
   * not publish a colleague's preference the way widening the team shape would.
   */
  user: Account
  sellers: SellerSummary[]
}

export type { default as Delivery } from './generated/Delivery'
// Named enums — open string unions for lists an extension may extend (statuses, fee kinds)
export type * from './generated/Enums'
export type { default as ShippingLabel } from './generated/ShippingLabel'
