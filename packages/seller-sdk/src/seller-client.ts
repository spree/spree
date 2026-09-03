import type { ListParams, PaginatedResponse, RequestFn, RequestOptions } from '@spree/sdk-core'
import { transformListParams } from '@spree/sdk-core'
import type {
  AuthTokens,
  Claim,
  Delivery,
  DeliveryMethod,
  DeliveryProfile,
  DeliveryZone,
  Exchange,
  Export,
  Fulfillment,
  Import,
  ImportRow,
  Invitation,
  Order,
  Policy,
  Product,
  ProductType,
  Profile,
  Reason,
  RequirementStatus,
  RequirementSubmission,
  Return,
  SellerSummary,
  ShippingLabel,
  StockLocation,
  TaxIdentifier,
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

    /**
     * Asks for a password reset email. Always resolves (202) whether or not the
     * address matches a seller, so this cannot be used to discover which
     * accounts exist. The emailed link opens the seller panel — `redirect_url`
     * when it passes the store's allowed-origin check, otherwise the panel
     * origin the server resolves for itself.
     */
    requestPasswordReset: (
      params: { email: string; redirect_url?: string },
      options?: RequestOptions,
    ): Promise<void> =>
      this.request<void>('POST', '/auth/password_resets', { ...options, body: params }),

    /**
     * Spends a reset token: sets the new password and returns a signed-in
     * seller session, so they land in the panel rather than on a login form.
     * The token is single-use, and resetting revokes every other session the
     * account holds.
     */
    resetPassword: (
      token: string,
      params: { password: string; password_confirmation: string },
      options?: RequestOptions,
    ): Promise<AuthTokens> =>
      this.request<AuthTokens>('PATCH', `/auth/password_resets/${encodeURIComponent(token)}`, {
        ...options,
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

  /**
   * The seller's own tax registrations — the numbers the marketplace's
   * commission invoice is made out to. A collection, like a company's: a
   * business trading in several regimes holds a registration in each.
   */
  readonly taxIdentifiers = {
    list: (options?: RequestOptions): Promise<{ data: TaxIdentifier[] }> =>
      this.request<{ data: TaxIdentifier[] }>('GET', '/tax_identifiers', options),

    create: (params: SellerTaxIdentifierParams, options?: RequestOptions): Promise<TaxIdentifier> =>
      this.request<TaxIdentifier>('POST', '/tax_identifiers', { ...options, body: params }),

    update: (
      id: string,
      params: SellerTaxIdentifierParams,
      options?: RequestOptions,
    ): Promise<TaxIdentifier> =>
      this.request<TaxIdentifier>('PATCH', `/tax_identifiers/${id}`, {
        ...options,
        body: params,
      }),

    remove: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/tax_identifiers/${id}`, options),

    /**
     * Asks the registry whether the number is still registered. A verdict
     * answers "valid now", so a number verified last year may have lapsed.
     */
    validate: (id: string, options?: RequestOptions): Promise<TaxIdentifier> =>
      this.request<TaxIdentifier>('POST', `/tax_identifiers/${id}/validate`, options),
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

    /**
     * A fresh link to wherever the marketplace's payout provider collects
     * what it needs before it will pay this seller.
     *
     * Asked for at the moment the seller acts, never rendered with the
     * checklist: these links are short-lived and single-use, so one made
     * while drawing a page is often dead before it is clicked. Answers
     * `{ url: null }` when the provider hosts no onboarding — a marketplace
     * paying by hand collects those details itself.
     */
    payoutAccount: (
      data: { refresh_url: string; return_url: string },
      options?: RequestOptions,
    ): Promise<PayoutAccountLink> =>
      this.request<PayoutAccountLink>('POST', '/onboarding/payout_account', {
        ...options,
        body: data,
      }),
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
    ): Promise<PaginatedResponse<Product>> =>
      this.request<PaginatedResponse<Product>>('GET', '/products', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    /**
     * @param expand associations to include — the product form asks for
     *   `variants,media,default_variant`, which is everything it edits.
     */
    get: (id: string, expand?: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('GET', `/products/${id}`, {
        ...options,
        params: expand ? { expand } : undefined,
      }),

    create: (params: ProductParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('POST', '/products', { ...options, body: params }),

    update: (id: string, params: ProductParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/products/${id}`, options),

    /**
     * Ask the marketplace to put this product on sale.
     *
     * Status is not an attribute a seller can send: whether a listing goes
     * live is the operator's decision, so it moves through these actions.
     */
    submit: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}/submit`, options),

    /** Take a listing back down. Withdrawing your own needs nobody's approval. */
    draft: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}/draft`, options),

    archive: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}/archive`, options),

    /**
     * Submit a selection for review.
     *
     * Only a draft or a rejected listing can be submitted, so a mixed
     * selection moves what it can: `product_count` is what was submitted and
     * `skipped_count` — present only when something was skipped — is what was
     * already on sale, already in review, or archived.
     */
    bulkSubmit: (params: { ids: string[] }, options?: RequestOptions): Promise<BulkProductResult> =>
      this.request('POST', '/products/bulk_submit', { ...options, body: params }),

    /**
     * Move a selection to `draft` or `archived`.
     *
     * There is no bulk route onto `active`: a listing goes on sale when the
     * marketplace approves it, one at a time.
     */
    bulkStatusUpdate: (
      params: { ids: string[]; status: 'draft' | 'archived' },
      options?: RequestOptions,
    ): Promise<BulkProductResult> =>
      this.request('POST', '/products/bulk_status_update', { ...options, body: params }),

    /** Delete a selection. Ids outside this seller's catalog are ignored. */
    bulkDestroy: (
      params: { ids: string[] },
      options?: RequestOptions,
    ): Promise<BulkProductResult> =>
      this.request('DELETE', '/products/bulk_destroy', { ...options, body: params }),
  }

  /**
   * What this seller has sold. A basket spanning several sellers is split
   * into one order each, so these are the seller's own orders rather than a
   * filtered view of somebody else's.
   */
  readonly orders = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Order>> =>
      this.request<PaginatedResponse<Order>>('GET', '/orders', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('GET', `/orders/${id}`, options),

    /** Withdraws from an order this seller cannot fulfil. */
    cancel: (
      id: string,
      params?: { notify_customer?: boolean },
      options?: RequestOptions,
    ): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/cancel`, { ...options, body: params }),

    /** The parcels owed on one order. */
    fulfillments: {
      list: (orderId: string, options?: RequestOptions): Promise<{ data: Fulfillment[] }> =>
        this.request<{ data: Fulfillment[] }>('GET', `/orders/${orderId}/fulfillments`, options),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Fulfillment> =>
        this.request<Fulfillment>('GET', `/orders/${orderId}/fulfillments/${id}`, options),

      /**
       * Ships the parcel. `items` narrows it to part of what the fulfillment
       * holds, which splits the rest onto a new one.
       */
      fulfill: (
        orderId: string,
        id: string,
        params?: {
          tracking?: string
          tracking_carrier?: string
          notify_customer?: boolean
          items?: Array<{ item_id: string; quantity: number }>
        },
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/fulfill`, {
          ...options,
          body: params,
        }),

      /**
       * The tracked consignments of one of the seller's parcels. A seller
       * ships on manual methods, so tracking numbers are entered here by hand.
       */
      deliveries: {
        list: (
          orderId: string,
          fulfillmentId: string,
          options?: RequestOptions,
        ): Promise<{ data: Delivery[] }> =>
          this.request<{ data: Delivery[] }>(
            'GET',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries`,
            options,
          ),

        get: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'GET',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries/${id}`,
            options,
          ),

        create: (
          orderId: string,
          fulfillmentId: string,
          params: {
            tracking_number: string
            carrier?: string
            service?: string
            tracking_url?: string
          },
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'POST',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries`,
            { ...options, body: params },
          ),

        update: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          params: {
            tracking_number?: string
            carrier?: string
            service?: string
            tracking_url?: string
          },
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'PATCH',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries/${id}`,
            { ...options, body: params },
          ),

        delete: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<void> =>
          this.request<void>(
            'DELETE',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries/${id}`,
            options,
          ),
      },

      /**
       * Labels on the seller's own parcels. Sellers upload postage they bought
       * elsewhere and print it back; buying and refunding need the operator's
       * carrier account, so neither is offered here.
       *
       * Upload the file with `directUploads.create()` and pass the returned
       * `signed_id` as `file`.
       */
      labels: {
        list: (
          orderId: string,
          fulfillmentId: string,
          options?: RequestOptions,
        ): Promise<{ data: ShippingLabel[] }> =>
          this.request<{ data: ShippingLabel[] }>(
            'GET',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels`,
            options,
          ),

        get: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'GET',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels/${id}`,
            options,
          ),

        create: (
          orderId: string,
          fulfillmentId: string,
          params: {
            file: string
            tracking_number: string
            carrier?: string
            service?: string
            cost?: string | number
            currency?: string
            file_format?: string
            tracking_url?: string
          },
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'POST',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels`,
            { ...options, body: params },
          ),

        delete: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<void> =>
          this.request<void>(
            'DELETE',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels/${id}`,
            options,
          ),
      },
    },

    /**
     * Goods coming back. The seller is merchant of record for their own
     * child order, so approving, receiving and refunding are all theirs.
     */
    returns: {
      list: (orderId: string, options?: RequestOptions): Promise<{ data: Return[] }> =>
        this.request<{ data: Return[] }>('GET', `/orders/${orderId}/returns`, {
          ...options,
          // The nested collections are expand-gated server-side, so a bare
          // list answers with the record and none of its contents.
          params: { expand: 'return_line_items,return_line_items.variant,reason' },
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Return> =>
        this.request<Return>('GET', `/orders/${orderId}/returns/${id}`, {
          ...options,
          params: { expand: 'return_line_items,return_line_items.variant,reason' },
        }),

      create: (
        orderId: string,
        params: {
          items: Array<{ fulfillment_item_id: string; quantity: number }>
          memo?: string
          reason_id?: string
          stock_location_id?: string
        },
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('POST', `/orders/${orderId}/returns`, { ...options, body: params }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/approve`, options),

      /** `items` carries what actually arrived; omit it to receive it all. */
      receive: (
        orderId: string,
        id: string,
        params?: {
          items?: Array<{ return_line_item_id: string; quantity: number; resellable?: boolean }>
        },
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/receive`, {
          ...options,
          body: params,
        }),

      /** Bounded by the return, and by this order's share of a split payment. */
      refund: (
        orderId: string,
        id: string,
        params?: { amount?: string; refund_method?: 'original_payment' | 'store_credit' },
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/refund`, {
          ...options,
          body: params,
        }),

      cancel: (
        orderId: string,
        id: string,
        params?: { reason?: string },
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/cancel`, {
          ...options,
          body: params,
        }),
    },

    /** Goods swapped for different ones. */
    exchanges: {
      list: (orderId: string, options?: RequestOptions): Promise<{ data: Exchange[] }> =>
        this.request<{ data: Exchange[] }>('GET', `/orders/${orderId}/exchanges`, {
          ...options,
          // The nested collections are expand-gated server-side, so a bare
          // list answers with the record and none of its contents.
          params: {
            expand:
              'exchange_line_items,exchange_line_items.original_variant,exchange_line_items.new_variant,reason',
          },
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Exchange> =>
        this.request<Exchange>('GET', `/orders/${orderId}/exchanges/${id}`, {
          ...options,
          params: {
            expand:
              'exchange_line_items,exchange_line_items.original_variant,exchange_line_items.new_variant,reason',
          },
        }),

      create: (
        orderId: string,
        params: {
          items: Array<{ fulfillment_item_id: string; new_variant_id: string; quantity: number }>
          memo?: string
          reason_id?: string
          stock_location_id?: string
        },
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('POST', `/orders/${orderId}/exchanges`, {
          ...options,
          body: params,
        }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/approve`, options),

      receive: (
        orderId: string,
        id: string,
        params?: {
          items?: Array<{ exchange_line_item_id: string; quantity: number; resellable?: boolean }>
        },
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/receive`, {
          ...options,
          body: params,
        }),

      /** Sends the replacement, settling any price difference. */
      fulfill: (
        orderId: string,
        id: string,
        params?: { refund_method?: 'original_payment' | 'store_credit' },
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/fulfill`, {
          ...options,
          body: params,
        }),

      cancel: (
        orderId: string,
        id: string,
        params?: { reason?: string },
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/cancel`, {
          ...options,
          body: params,
        }),
    },

    /**
     * Something went wrong with a delivery, put right without necessarily
     * asking for the goods back.
     */
    claims: {
      list: (orderId: string, options?: RequestOptions): Promise<{ data: Claim[] }> =>
        this.request<{ data: Claim[] }>('GET', `/orders/${orderId}/claims`, {
          ...options,
          // The nested collections are expand-gated server-side, so a bare
          // list answers with the record and none of its contents.
          params: { expand: 'claim_line_items,claim_line_items.variant,reason' },
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Claim> =>
        this.request<Claim>('GET', `/orders/${orderId}/claims/${id}`, {
          ...options,
          params: { expand: 'claim_line_items,claim_line_items.variant,reason' },
        }),

      create: (
        orderId: string,
        params: {
          items: Array<{
            line_item_id: string
            quantity: number
            description?: string
            send_replacement?: boolean
            replacement_variant_id?: string
            refund_amount?: string
          }>
          memo?: string
          reason_id?: string
        },
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('POST', `/orders/${orderId}/claims`, { ...options, body: params }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}/approve`, options),

      /** Money back, a replacement shipment, or both. */
      resolve: (
        orderId: string,
        id: string,
        params: {
          resolution: 'refund' | 'replacement' | 'refund_and_replacement'
          refund_method?: 'original_payment' | 'store_credit'
          amount?: string
          replacement_line_item_ids?: string[]
        },
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}/resolve`, {
          ...options,
          body: params,
        }),

      deny: (
        orderId: string,
        id: string,
        params?: { reason?: string },
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}/deny`, {
          ...options,
          body: params,
        }),

      cancel: (
        orderId: string,
        id: string,
        params?: { reason?: string },
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}/cancel`, {
          ...options,
          body: params,
        }),
    },
  }

  /**
   * The marketplace's own vocabularies, and the carrier registry. Read-only:
   * a seller picks from these, the operator decides what is in them.
   */
  readonly returnReasons = {
    list: (options?: RequestOptions): Promise<{ data: Reason[] }> =>
      this.request<{ data: Reason[] }>('GET', '/return_reasons', options),
  }

  readonly claimReasons = {
    list: (options?: RequestOptions): Promise<{ data: Reason[] }> =>
      this.request<{ data: Reason[] }>('GET', '/claim_reasons', options),
  }

  readonly trackingCarriers = {
    list: (options?: RequestOptions): Promise<{ data: Array<{ id: string; name: string }> }> =>
      this.request<{ data: Array<{ id: string; name: string }> }>(
        'GET',
        '/tracking_carriers',
        options,
      ),
  }

  /**
   * Presigning for the documents onboarding asks for. Exchange the blob's
   * metadata for an upload URL, PUT the file to it, then post the returned
   * `signed_id` as a submission's `file`.
   */
  readonly directUploads = {
    create: (
      params: {
        blob: { filename: string; byte_size: number; checksum: string; content_type: string }
      },
      options?: RequestOptions,
    ): Promise<{
      direct_upload: { url: string; headers: Record<string, string> }
      signed_id: string
    }> => this.request('POST', '/direct_uploads', { ...options, body: params }),
  }

  /**
   * CSV of this seller's own records — what they sold, or their catalogue.
   *
   * Created, polled until `done`, then downloaded. There is no list: a seller
   * has no export history page, and no delete: how long a file is kept is the
   * marketplace's business.
   *
   * Scoped server-side to the acting seller, so an export can only ever
   * contain their own rows however the request is filtered.
   */
  readonly exports = {
    create: (params: SellerExportCreateParams, options?: RequestOptions): Promise<Export> =>
      this.request<Export>('POST', '/exports', { ...options, body: params }),

    get: (id: string, options?: RequestOptions): Promise<Export> =>
      this.request<Export>('GET', `/exports/${id}`, options),
  }

  /**
   * The types a seller may list a product against. Read only — defining a
   * type is the operator's. A seller picks one because it is the template
   * that hands their product its option types and delivery profile.
   */
  readonly productTypes = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<ProductType>> =>
      this.request<PaginatedResponse<ProductType>>('GET', '/product_types', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<ProductType> =>
      this.request<ProductType>('GET', `/product_types/${id}`, options),
  }

  /**
   * The marketplace's delivery profiles — what kind of goods a product is
   * (parcel, digital, pallet). Read only: a seller assigns one to their
   * product and never defines one.
   */
  readonly deliveryProfiles = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DeliveryProfile>> =>
      this.request<PaginatedResponse<DeliveryProfile>>('GET', '/delivery_profiles', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),
  }

  /**
   * The marketplace's delivery zones — where its methods may ship to.
   *
   * Read only, like profiles. Pass `delivery_profile_id` to list only the
   * zones under one profile, which is what the method form's picker asks for.
   */
  readonly deliveryZones = {
    list: (
      params?: DeliveryZoneListParams,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DeliveryZone>> => {
      // `delivery_profile_id` is sent alongside the Ransack query rather than
      // through it: the endpoint reads it as a plain parameter, and
      // `transformListParams` would wrap it into `q[...]` where the filter is
      // silently ignored — leaving the picker offering every zone in the store.
      const { delivery_profile_id: deliveryProfileId, ...listParams } = params ?? {}

      return this.request<PaginatedResponse<DeliveryZone>>('GET', '/delivery_zones', {
        ...options,
        params: {
          ...transformListParams(listParams),
          ...(deliveryProfileId ? { delivery_profile_id: deliveryProfileId } : {}),
        },
      })
    },
  }

  /**
   * How this seller ships.
   *
   * `list()` carries the seller's own methods alongside the marketplace ones
   * the operator shares with sellers; a shared row comes back with
   * `editable: false` and every write against it is a 404.
   *
   * Neither the rate provider nor the fulfillment provider is settable — a
   * seller prices their own rates and enters tracking numbers by hand,
   * because carrier accounts belong to the marketplace.
   */
  readonly deliveryMethods = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DeliveryMethod>> =>
      this.request<PaginatedResponse<DeliveryMethod>>('GET', '/delivery_methods', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<DeliveryMethod> =>
      this.request<DeliveryMethod>('GET', `/delivery_methods/${id}`, options),

    create: (params: DeliveryMethodParams, options?: RequestOptions): Promise<DeliveryMethod> =>
      this.request<DeliveryMethod>('POST', '/delivery_methods', { ...options, body: params }),

    update: (
      id: string,
      params: DeliveryMethodParams,
      options?: RequestOptions,
    ): Promise<DeliveryMethod> =>
      this.request<DeliveryMethod>('PATCH', `/delivery_methods/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/delivery_methods/${id}`, options),

    /** The ways a method can be priced, with each one's preference schema. */
    calculators: (options?: RequestOptions): Promise<{ data: DeliveryCalculatorType[] }> =>
      this.request<{ data: DeliveryCalculatorType[] }>(
        'GET',
        '/delivery_methods/calculators',
        options,
      ),

    /** The conditions a seller may put on their own method. */
    ruleTypes: (options?: RequestOptions): Promise<{ data: DeliveryMethodRuleType[] }> =>
      this.request<{ data: DeliveryMethodRuleType[] }>(
        'GET',
        '/delivery_methods/rule_types',
        options,
      ),
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
    ): Promise<PaginatedResponse<StockLocation>> =>
      this.request<PaginatedResponse<StockLocation>>('GET', '/stock_locations', {
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

  /**
   * This seller's own policy documents — their returns policy, shipping
   * policy, whatever the marketplace asks them to publish.
   *
   * Addressable by slug as well as prefixed id, matching the storefront.
   */
  readonly policies = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Policy>> =>
      this.request<PaginatedResponse<Policy>>('GET', '/policies', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (idOrSlug: string, options?: RequestOptions): Promise<Policy> =>
      this.request<Policy>('GET', `/policies/${idOrSlug}`, options),

    create: (params: PolicyCreateParams, options?: RequestOptions): Promise<Policy> =>
      this.request<Policy>('POST', '/policies', { ...options, body: params }),

    update: (
      idOrSlug: string,
      params: PolicyUpdateParams,
      options?: RequestOptions,
    ): Promise<Policy> =>
      this.request<Policy>('PATCH', `/policies/${idOrSlug}`, { ...options, body: params }),

    delete: (idOrSlug: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/policies/${idOrSlug}`, options),
  }

  /**
   * Bulk-listing this seller's catalog from a CSV.
   *
   * The flow is the operator's: upload the file with `directUploads.create()`,
   * `create()` the import from the returned `signed_id`, and the response
   * comes back in the `mapping` state carrying `schema_fields`, `csv_headers`,
   * a `sample_row` and the auto-assigned `mappings`. Adjust those and call
   * `completeMapping(id)` to start processing, then poll `get(id)` while
   * `status` is `completed_mapping`/`processing` (`completed`/`failed` are
   * terminal). Failed rows are listed via
   * `rows.list(id, { status_eq: 'failed' })` and re-run with
   * `retryFailedRows(id)`.
   *
   * Products only, and what an import creates is a draft: a seller reaches
   * `active` through review, never by uploading.
   */
  readonly imports = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Import>> =>
      this.request<PaginatedResponse<Import>>('GET', '/imports', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Import> =>
      this.request<Import>('GET', `/imports/${id}`, options),

    create: (params: ImportCreateParams, options?: RequestOptions): Promise<Import> =>
      this.request<Import>('POST', '/imports', { ...options, body: params }),

    completeMapping: (
      id: string,
      params?: ImportCompleteMappingParams,
      options?: RequestOptions,
    ): Promise<Import> =>
      this.request<Import>('PATCH', `/imports/${id}/complete_mapping`, {
        ...options,
        body: params ?? {},
      }),

    retryFailedRows: (id: string, options?: RequestOptions): Promise<Import> =>
      this.request<Import>('PATCH', `/imports/${id}/retry_failed_rows`, options),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/imports/${id}`, options),

    rows: {
      list: (
        importId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<ImportRow>> =>
        this.request<PaginatedResponse<ImportRow>>('GET', `/imports/${importId}/rows`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),
    },
  }
}

/**
 * What a seller may write when publishing a policy. `name` is required — it is
 * how the marketplace's onboarding check finds the document.
 *
 * `body` takes HTML and is sanitized server-side; `body_html` is the
 * read-only rendering of what was stored.
 */
export interface PolicyCreateParams {
  name: string
  slug?: string
  body?: string | null
}

/** What a seller may change on a policy they already published. */
export interface PolicyUpdateParams {
  name?: string
  slug?: string
  body?: string | null
}

/**
 * API shorthand for an import type, not the Ruby class name.
 *
 * One member today: products are the only dataset a seller owns. Customers
 * belong to the marketplace, and translations of catalog copy are its
 * merchandising — the Seller API refuses both.
 */
export type SellerImportType = 'products'

export interface ImportCreateParams {
  type: SellerImportType
  /**
   * ActiveStorage signed blob id of the uploaded CSV, from
   * `directUploads.create()`.
   */
  attachment: string
  /** CSV column separator. Defaults to a comma on the server. */
  preferred_delimiter?: ',' | ';' | '|' | '\t'
  /**
   * Absolute URL of the panel's imports view; the import-done email links back
   * to it with `?import=<id>` appended. Honored only when it matches one of
   * the store's configured allowed origins.
   */
  results_url?: string
}

export interface ImportMappingParam {
  /** Canonical schema field name (see `Import.schema_fields[].name`). */
  schema_field: string
  /** CSV header to read the field from; `null` unmaps the field. */
  file_column: string | null
}

export interface ImportCompleteMappingParams {
  /** Column assignments to apply before processing starts. */
  mappings?: ImportMappingParam[]
}

/** What a seller may write on one of their stock locations. */
/**
 * One condition on a delivery method as it is written.
 *
 * Omitting `id` marks a rule as new; dropping one from the array deletes it.
 * `type` is a wire shorthand from `deliveryMethods.ruleTypes()` — a kind this
 * branch does not offer is a 404, never a silent drop.
 */
export interface DeliveryMethodRuleParams {
  id?: string
  type: string
  active?: boolean
  preferences?: Record<string, unknown>
}

export interface DeliveryMethodParams {
  name?: string
  admin_name?: string | null
  code?: string | null
  /** One of the marketplace's delivery profiles. */
  delivery_profile_id?: string
  /** Narrows where the method ships; null serves everywhere the profile reaches. */
  delivery_zone_id?: string | null
  storefront_visible?: boolean
  tracking_url?: string | null
  estimated_transit_business_days_min?: number | null
  estimated_transit_business_days_max?: number | null
  calculator_type?: string
  calculator_preferences?: Record<string, unknown>
  /** Replaces the whole set; an empty array clears every condition. */
  rules?: DeliveryMethodRuleParams[]
}

export interface DeliveryZoneListParams extends ListParams {
  /** Only zones under this delivery profile. */
  delivery_profile_id?: string
  [key: string]: unknown
}

/**
 * One field on a calculator's or rule's configuration form, as the server
 * describes it. The same shape the generated `DeliveryMethodRule` type
 * carries, so a schema from either endpoint renders through one form.
 */
export interface DeliveryPreferenceField {
  key: string
  type: string
  default: unknown
}

/** One way a delivery method can be priced. */
export interface DeliveryCalculatorType {
  type: string
  name: string
  preference_schema: DeliveryPreferenceField[]
}

/** One condition a seller may put on their own method. */
export interface DeliveryMethodRuleType {
  type: string
  name: string
  description: string
  preference_schema: DeliveryPreferenceField[]
}

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

/**
 * The datasets a seller may export.
 *
 * Deliberately narrower than the operator's list: only records that can be
 * narrowed to one seller are offered, since that narrowing is what keeps one
 * seller's file free of another's rows.
 */
export type SellerExportType = 'orders' | 'products'

export interface SellerExportCreateParams {
  type: SellerExportType
  /**
   * Ransack query hash, the same predicate shape the list endpoints take
   * (`{ number_cont: 'R12' }`). Ignored when `record_selection` is `'all'`.
   */
  search_params?: Record<string, unknown>
  /**
   * `'filtered'` (default) keeps `search_params`; `'all'` clears them on the
   * server and exports everything this seller owns.
   */
  record_selection?: 'filtered' | 'all'
  /**
   * Absolute URL of the panel view to send the seller back to; the
   * export-done email uses it as the download button's target. Honored only
   * when it matches one of the store's allowed origins.
   *
   * Passed by the panel rather than derived server-side, because only the
   * panel knows where it is mounted — a seller panel is served from a path
   * under the store as often as from a host of its own.
   */
  results_url?: string
}

/** What a seller sends when recording a registration. */
export interface SellerTaxIdentifierParams {
  kind: string
  value: string
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

/** Where to send a seller to set up how they get paid. */
export interface PayoutAccountLink {
  /** Null when the provider hosts no onboarding of its own. */
  url: string | null
}

/** What `/seller/onboarding` answers. */
export interface OnboardingResponse {
  /** The seller's lifecycle status, e.g. `onboarding`, `ready_for_review`. */
  status: string
  /**
   * Optional requirements included — this is how far along, not how close to
   * approval. Just the two counts: a percentage is arithmetic over them, and a
   * copy here would be a second definition of the same fact.
   */
  progress: { done: number; total: number }
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
/**
 * What a bulk product action did. `skipped_count` is present only when the
 * action left something alone — a key on every response would tell a caller
 * that never skips anything that nothing was skipped.
 */
export interface BulkProductResult {
  product_count: number
  skipped_count?: number
}

export interface ProductParams {
  name?: string
  description?: string
  slug?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  metadata?: Record<string, unknown>
  /**
   * The marketplace's type this product is listed against, from
   * `productTypes.list()`. `null` detaches it. Saving with a type seeds its
   * option types onto the product.
   */
  product_type_id?: string | null
  /**
   * Which of the marketplace's delivery profiles the product ships under,
   * from `deliveryProfiles.list()`. A new product sent without one lands on
   * the profile marked `default`.
   */
  delivery_profile_id?: string
  /**
   * The gallery, as a whole. A file absent from the list is removed, so send
   * every image the product should end up with. `signed_id` attaches a fresh
   * upload; `id` patches one already there.
   */
  media?: Array<{
    id?: string
    signed_id?: string
    alt?: string | null
    position?: number
    media_type?: string
    external_video_url?: string | null
    focal_point_x?: number | null
    focal_point_y?: number | null
    variant_ids?: string[]
  }>
  /**
   * The variants, as a whole — one absent from the list is removed. Tax
   * category and delivery profile are deliberately absent: they are
   * marketplace configuration and the API ignores them here.
   */
  variants?: Array<{
    id?: string
    sku?: string
    barcode?: string | null
    cost_price?: string | number | null
    cost_currency?: string | null
    weight?: string | number | null
    height?: string | number | null
    width?: string | number | null
    depth?: string | number | null
    weight_unit?: string | null
    dimensions_unit?: string | null
    hs_code?: string | null
    country_of_origin?: string | null
    customs_description?: string | null
    track_inventory?: boolean
    preorderable?: boolean
    preorder_ships_at?: string | null
    backorder_limit?: number | null
    position?: number
    options?: Array<{ name: string; value: string }>
    prices?: Array<{
      amount: string | number
      compare_at_amount?: string | number
      currency?: string
    }>
    stock_levels?: Array<{
      id?: string
      stock_location_id?: string
      count_on_hand?: number
      backorderable?: boolean
    }>
  }>
  /**
   * Omit `currency` and the price is recorded in the store's, which is the
   * only place that knows it. A seller has no currency of their own to read.
   */
  prices?: Array<{
    amount: string | number
    compare_at_amount?: string | number
    currency?: string
  }>
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
  /** The business a commission invoice is made out to. */
  legal_name?: string | null
  registration_number?: string | null
  /**
   * The seller's tax registration. One per kind — re-sending a kind corrects
   * the number, and an empty value removes it. A changed number drops its
   * validation verdict, since that answer was about the old one.
   */
  billing_address?: SellerAddressParams
  returns_address?: SellerAddressParams
  /**
   * Answers to the custom fields this marketplace's onboarding asks for.
   * Narrowed server-side to those definitions — a field nothing asked for is
   * ignored rather than written.
   */
  custom_fields?: Array<{ custom_field_definition_id: string; value: unknown }>
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
