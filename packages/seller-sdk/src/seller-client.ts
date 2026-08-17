import type { RequestFn, RequestOptions } from '@spree/sdk-core'
import type { AuthTokens, Invitation, Profile, SellerSummary, TeamMember } from './types'

/**
 * Resource methods for the Spree Seller API — the marketplace seller panel.
 *
 * Every path is relative to `/api/v3/seller` and is scoped server-side to the
 * seller named in `X-Spree-Seller-Id`, so nothing here takes a seller id: a
 * seller acts as one seller at a time, chosen from the list `me()` returns.
 */
export class SellerClient {
  constructor(private readonly request: RequestFn) {}

  readonly auth = {
    /**
     * Signs a seller in. Fails for a store staff member who runs no seller —
     * authenticating is not enough, since staff share the same user class.
     */
    login: (
      params: { email: string; password: string },
      options?: RequestOptions,
    ): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/login', { ...options, body: params }),

    /** Exchanges the refresh cookie for a fresh access token. */
    refresh: (options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/refresh', options),

    /** Clears the session server-side and drops the refresh cookie. */
    logout: (options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', '/auth/logout', options),

    /** Sign-in methods this marketplace offers sellers, for the login page. */
    providers: (options?: RequestOptions): Promise<{ providers: unknown[] }> =>
      this.request<{ providers: unknown[] }>('GET', '/auth/providers', options),

    /**
     * Reads an invitation from the emailed link, before anyone signs in — the
     * page needs the invited address to decide whether it is asking someone to
     * set a password or to confirm the one they already have.
     */
    lookupInvitation: (
      invitationId: string,
      token: string,
      options?: RequestOptions,
    ): Promise<Invitation> =>
      this.request<Invitation>('GET', `/auth/invitations/${invitationId}/lookup`, {
        ...options,
        params: { token },
      }),

    /**
     * Accepts the invitation and returns a signed-in seller session, so the
     * new member lands in the panel rather than on a login form.
     */
    acceptInvitation: (
      invitationId: string,
      token: string,
      params: {
        password?: string
        password_confirmation?: string
        first_name?: string
        last_name?: string
      },
      options?: RequestOptions,
    ): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', `/auth/invitations/${invitationId}/accept`, {
        ...options,
        params: { token },
        body: params,
      }),
  }

  /**
   * The signed-in seller: who they are, which sellers they may act for, and
   * what they may do on the selected one.
   *
   * `permission_keys` is empty until a seller is named — capability is per
   * seller, so there is no answer spanning all of them.
   */
  me = (options?: RequestOptions): Promise<MeResponse> =>
    this.request<MeResponse>('GET', '/me', options)

  /** The seller's own record, as they maintain it. */
  readonly profile = {
    get: (options?: RequestOptions): Promise<Profile> =>
      this.request<Profile>('GET', '/profile', options),

    /**
     * Edits presentation, contact details and addresses. `status`, the
     * settlement terms and `slug` are readable but not writable — the
     * lifecycle belongs to the marketplace operator.
     */
    update: (params: ProfileUpdateParams, options?: RequestOptions): Promise<Profile> =>
      this.request<Profile>('PATCH', '/profile', { ...options, body: params }),
  }

  /** Who runs this seller. */
  readonly team = {
    list: (options?: RequestOptions): Promise<{ data: TeamMember[] }> =>
      this.request<{ data: TeamMember[] }>('GET', '/team', options),

    /**
     * Invites a colleague. They join when they accept; the seller's own
     * lifecycle is untouched, since hiring is not a transition.
     */
    invite: (params: { email: string }, options?: RequestOptions): Promise<unknown> =>
      this.request<unknown>('POST', '/team', { ...options, body: params }),

    /** Revokes a member's access. The last remaining member cannot be removed. */
    remove: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/team/${id}`, options),
  }

  /**
   * Offers nobody has accepted yet.
   *
   * Sending one lives on `team` — that is hiring — while chasing or
   * withdrawing one is bookkeeping on the offer itself.
   */
  readonly invitations = {
    /** Pending only; an accepted invitation is a team member. */
    list: (options?: RequestOptions): Promise<{ data: Invitation[] }> =>
      this.request<{ data: Invitation[] }>('GET', '/invitations', options),

    /** Sends the email again, for a colleague who never got the first one. */
    resend: (id: string, options?: RequestOptions): Promise<Invitation> =>
      this.request<Invitation>('PATCH', `/invitations/${id}/resend`, options),

    /** Withdraws an offer that has not been accepted. */
    revoke: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/invitations/${id}`, options),
  }
}

/** What `/seller/me` answers. */
export interface MeResponse {
  user: TeamMember
  sellers: SellerSummary[]
  permission_keys: string[]
}

/** The fields a seller may change on their own record. */
export interface ProfileUpdateParams {
  name?: string
  contact_email?: string | null
  billing_email?: string | null
  /** Sanitized HTML — the seller's public description. */
  about?: string | null
  /** ActiveStorage signed ids; `null` removes the attachment. */
  logo?: string | null
  square_logo?: string | null
  cover_photo?: string | null
  billing_address?: SellerAddressParams
  returns_address?: SellerAddressParams
}

export interface SellerAddressParams {
  first_name?: string
  last_name?: string
  company?: string
  address1?: string
  address2?: string
  city?: string
  postal_code?: string
  zipcode?: string
  phone?: string
  country_code?: string
  state_code?: string
  state_name?: string
  label?: string
}
