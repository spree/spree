import type { ListParams, ListResponse, RequestFn, RequestOptions } from '@spree/sdk-core'
import { transformListParams } from '@spree/sdk-core'
import type {
  AuthTokens,
  Invitation,
  Product,
  Profile,
  RequirementStatus,
  RequirementSubmission,
  SellerSummary,
  StockLocation,
  TeamMember,
} from './types'

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
   * Countries for the panel's address forms — public reference data, the same
   * list the storefront serves.
   */
  readonly countries = {
    list: (options?: RequestOptions): Promise<{ data: SellerCountry[] }> =>
      this.request<{ data: SellerCountry[] }>('GET', '/countries', options),
  }

  /**
   * What the marketplace asks of this seller before it will admit them.
   *
   * Singular: the checklist is always the acting seller's. Every answer is
   * computed server-side by the one evaluator the operator's view also uses,
   * so the panel and the operator cannot show different progress.
   */
  readonly onboarding = {
    get: (options?: RequestOptions): Promise<OnboardingResponse> =>
      this.request<OnboardingResponse>('GET', '/onboarding', options),

    /**
     * Says the seller is ready. Refused with the blocking requirements named
     * when something required is still outstanding.
     */
    submitForReview: (options?: RequestOptions): Promise<OnboardingResponse> =>
      this.request<OnboardingResponse>('POST', '/onboarding/submit_for_review', options),
  }

  /**
   * What the seller submits about one requirement: an attestation they tick,
   * a document they upload, a reference they paste.
   *
   * Create only — a submission records what was said and when, so the seller
   * submits again rather than editing, and the latest one counts.
   */
  readonly requirementSubmissions = {
    create: (
      requirementId: string,
      params: RequirementSubmissionParams,
      options?: RequestOptions,
    ): Promise<RequirementSubmission> =>
      this.request<RequirementSubmission>('POST', `/requirements/${requirementId}/submissions`, {
        ...options,
        body: params,
      }),
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

  /**
   * The seller's own catalog — products they own outright. Every call is
   * rooted in the seller server-side, so an id belonging to another seller
   * is a 404. Variants listed against shared master-catalog products are a
   * separate surface.
   */
  readonly products = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<ListResponse<Product>> =>
      this.request<ListResponse<Product>>('GET', '/products', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('GET', `/products/${id}`, options),

    create: (params: ProductParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('POST', '/products', { ...options, body: params }),

    update: (id: string, params: ProductParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/products/${id}`, options),
  }

  /**
   * Where this seller keeps stock, and so where their returns are sent.
   *
   * No delete: a location holds stock levels and is named on historical
   * fulfillments, so a seller retires one by setting `active` to false.
   */
  readonly stockLocations = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<ListResponse<StockLocation>> =>
      this.request<ListResponse<StockLocation>>('GET', '/stock_locations', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<StockLocation> =>
      this.request<StockLocation>('GET', `/stock_locations/${id}`, options),

    create: (params: StockLocationParams, options?: RequestOptions): Promise<StockLocation> =>
      this.request<StockLocation>('POST', '/stock_locations', { ...options, body: params }),

    update: (
      id: string,
      params: StockLocationParams,
      options?: RequestOptions,
    ): Promise<StockLocation> =>
      this.request<StockLocation>('PATCH', `/stock_locations/${id}`, {
        ...options,
        body: params,
      }),
  }
}

/** What a seller may write on one of their stock locations. */
export interface StockLocationParams {
  name?: string
  company?: string | null
  address1?: string | null
  address2?: string | null
  city?: string | null
  zipcode?: string | null
  country_code?: string | null
  state_code?: string | null
  state_name?: string | null
  phone?: string | null
  active?: boolean
  default?: boolean
  kind?: string
}

/** A country as the address form needs it. */
export interface SellerCountry {
  iso: string
  iso3: string
  name: string
  states_required?: boolean
  zipcode_required?: boolean
  states?: Array<{ abbr: string; name: string }>
}

/** What `/seller/onboarding` answers. */
export interface OnboardingResponse {
  /** The seller's lifecycle status, e.g. `onboarding`, `ready_for_review`. */
  status: string
  /** Optional requirements included — this is how far along, not how close to approval. */
  progress: { done: number; total: number; percentage: number }
  requirements: RequirementStatus[]
}

/** What a seller says about one requirement. */
export interface RequirementSubmissionParams {
  note?: string
  reference?: string
  /** A direct-upload signed blob id, for kinds that ask for a document. */
  file?: string
}

/** The fields a seller may set on their own product. */
export interface ProductParams {
  name?: string
  description?: string
  slug?: string
  status?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  product_type_id?: string
  tags?: string[]
  category_ids?: string[]
  metadata?: Record<string, unknown>
  prices?: Array<{ amount: string | number; compare_at_amount?: string | number; currency: string }>
}

/** What `/seller/me` answers. */
/**
 * One CanCanCan rule, in the shape the panels' `<Can>` reads. Identical to
 * the Admin API's, on purpose: the framework's permission model is one
 * implementation, so its input has to be too.
 */
export interface PermissionRule {
  /** true for `can`, false for `cannot` */
  allow: boolean
  /** Action names, e.g. ["read", "update"] or ["manage"] */
  actions: string[]
  /** Subject class names, e.g. ["Spree::Product"] or ["all"] */
  subjects: string[]
  /** The rule carries per-record conditions the API will still enforce. */
  has_conditions: boolean
}

export interface MeResponse {
  user: TeamMember
  sellers: SellerSummary[]
  /** Empty until a seller is named — capability is per seller. */
  permissions: PermissionRule[]
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
  /**
   * Accepts the marketplace's terms, stamping the moment. One-way: the stamp
   * records that it happened, so sending `false` does not unmake it.
   */
  accept_terms?: boolean
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
