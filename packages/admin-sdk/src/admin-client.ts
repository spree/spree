import type { ListParams, PaginatedResponse, RequestFn, RequestOptions } from '@spree/sdk-core'
import { getParams, transformListParams } from '@spree/sdk-core'

export interface DashboardAnalytics {
  currency: string
  date_from: string
  date_to: string
  summary: {
    sales_total: number
    display_sales_total: string
    sales_growth: number
    orders_count: number
    orders_growth: number
    avg_order_value: number
    display_avg_order_value: string
    avg_order_value_growth: number
  }
  chart_data: Array<{
    date: string
    sales: number
    orders: number
    avg_order_value: number
  }>
  top_products: Array<{
    id: string
    name: string
    slug: string
    image_url: string | null
    price: string | null
    quantity: number
    total: string
  }>
}

export interface AuthTokens {
  /** Short-lived JWT access token. Goes in `Authorization: Bearer`. Keep in memory only. */
  token: string
  user: {
    id: string
    email: string
    first_name: string | null
    last_name: string | null
  }
}

export interface LoginCredentials {
  email: string
  password: string
}

/**
 * Public lookup of a pending invitation. The SPA hits this to render the
 * acceptance page (store name, role, inviter). `invitee_exists` decides
 * between the sign-in form (true) and the signup form (false).
 */
export interface InvitationLookup {
  id: string
  email: string
  role_name: string | null
  inviter_email: string | null
  expires_at: string | null
  invitee_exists: boolean
  store: {
    id: string | null
    name: string | null
  }
}

export interface PermissionRule {
  /** true for `can`, false for `cannot` */
  allow: boolean
  /** Action names, e.g. ["read", "update"] or ["manage"] */
  actions: string[]
  /** Subject class names, e.g. ["Spree::Product"] or ["all"] */
  subjects: string[]
  /** Whether the server rule has per-record conditions. If true, the action may be denied at the record level and the SPA should expect possible 403. */
  has_conditions: boolean
}

export interface MeResponse {
  user: {
    id: string
    email: string
    first_name: string | null
    last_name: string | null
  }
  permissions: PermissionRule[]
}

import type {
  AdminUserUpdateParams,
  ApiKeyCreateParams,
  ApiKeyUpdateParams,
  CustomerAddressParams,
  CustomerCreateParams,
  CustomerStoreCreditCreateParams,
  CustomerStoreCreditUpdateParams,
  CustomerUpdateParams,
  CustomFieldCreateParams,
  CustomFieldDefinitionCreateParams,
  CustomFieldDefinitionUpdateParams,
  CustomFieldOwnerType,
  CustomFieldUpdateParams,
  DirectUploadCreateParams,
  ExportCreateParams,
  FulfillmentUpdateParams,
  GiftCardApplyParams,
  InvitationAcceptParams,
  InvitationCreateParams,
  LineItemCreateParams,
  LineItemUpdateParams,
  MediaCreateParams,
  MediaUpdateParams,
  OptionTypeCreateParams,
  OptionTypeUpdateParams,
  OrderApproveParams,
  OrderCancelParams,
  OrderCompleteParams,
  OrderCreateParams,
  OrderUpdateParams,
  PaymentCreateParams,
  ProductUpdateParams,
  StockLocationCreateParams,
  StockLocationUpdateParams,
  StoreCreditApplyParams,
  StoreUpdateParams,
  VariantCreateParams,
  VariantUpdateParams,
} from './params'
import type {
  Address,
  Adjustment,
  AdminUser,
  ApiKey,
  Category,
  Country,
  CreditCard,
  Customer,
  CustomField,
  CustomFieldDefinition,
  Export,
  Fulfillment,
  Invitation,
  LineItem,
  Media,
  OptionType,
  Order,
  Payment,
  PaymentMethod,
  Product,
  Refund,
  Role,
  StockLocation,
  Store,
  StoreCredit,
  TaxCategory,
  Variant,
} from './types'

/**
 * Maps a built-in CustomField owner type (e.g. `Spree::Product`) to its admin
 * route segment. The generic `client.customFields(ownerType, ownerId)` escape
 * hatch reads this map; plugin owners that aren't registered here hit the
 * runtime "Unknown owner type" error and should use the first-class accessor
 * exposed by their plugin.
 *
 * `satisfies` here keeps the map keys as a subset of the strict-literal arm of
 * `CustomFieldOwnerType`. Adding a built-in owner means updating both this map
 * and the union in `params.ts`; the type system flags the map side.
 */
const CUSTOM_FIELD_OWNER_PATHS = {
  'Spree::Product': '/products',
  'Spree::Variant': '/variants',
  'Spree::Order': '/orders',
  'Spree::User': '/customers',
  'Spree::Category': '/categories',
  'Spree::OptionType': '/option_types',
} as const satisfies Record<Exclude<CustomFieldOwnerType, string & {}>, string>

export class AdminClient {
  /** @internal */
  readonly request: RequestFn

  constructor(request: RequestFn) {
    this.request = request
  }

  /**
   * Builds a `customFields` accessor whose methods expect the parent ID as
   * their first argument. Inlined by each first-class resource (`products`,
   * `orders`, …) so callers can write `client.products.customFields.list(id)`.
   * The generic `customFields(ownerType, ownerId)` escape hatch curries the
   * parent ID up front and returns the same shape minus the leading `parentId`.
   * @internal
   */
  private parentScopedCustomFields(basePath: string) {
    return {
      list: (
        parentId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CustomField>> =>
        this.request<PaginatedResponse<CustomField>>(
          'GET',
          `${basePath}/${parentId}/custom_fields`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (parentId: string, id: string, options?: RequestOptions): Promise<CustomField> =>
        this.request<CustomField>('GET', `${basePath}/${parentId}/custom_fields/${id}`, options),

      create: (
        parentId: string,
        params: CustomFieldCreateParams,
        options?: RequestOptions,
      ): Promise<CustomField> =>
        this.request<CustomField>('POST', `${basePath}/${parentId}/custom_fields`, {
          ...options,
          body: params,
        }),

      update: (
        parentId: string,
        id: string,
        params: CustomFieldUpdateParams,
        options?: RequestOptions,
      ): Promise<CustomField> =>
        this.request<CustomField>('PATCH', `${basePath}/${parentId}/custom_fields/${id}`, {
          ...options,
          body: params,
        }),

      delete: (parentId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `${basePath}/${parentId}/custom_fields/${id}`, options),
    }
  }

  /**
   * Generic accessor for any custom-field-bearing resource. Use the
   * first-class accessors (`client.products.customFields`, etc.) when
   * available — they're more discoverable. Use this when the owner is a
   * plugin-registered resource without a dedicated accessor.
   *
   * ```ts
   * await client.customFields('Spree::Product', 'prod_xxx').list()
   * ```
   */
  customFields(ownerType: CustomFieldOwnerType, ownerId: string) {
    const ownerPath = (CUSTOM_FIELD_OWNER_PATHS as Record<string, string>)[ownerType]
    if (!ownerPath) {
      throw new Error(
        `Unknown custom-field owner type: ${ownerType}. Add it to CUSTOM_FIELD_OWNER_PATHS.`,
      )
    }
    const scoped = this.parentScopedCustomFields(ownerPath)
    return {
      list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions) =>
        scoped.list(ownerId, params, options),
      get: (id: string, options?: RequestOptions) => scoped.get(ownerId, id, options),
      create: (params: CustomFieldCreateParams, options?: RequestOptions) =>
        scoped.create(ownerId, params, options),
      update: (id: string, params: CustomFieldUpdateParams, options?: RequestOptions) =>
        scoped.update(ownerId, id, params, options),
      delete: (id: string, options?: RequestOptions) => scoped.delete(ownerId, id, options),
    }
  }

  // ============================================
  // Custom Field Definitions (per resource type)
  // ============================================

  readonly customFieldDefinitions = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<CustomFieldDefinition>> =>
      this.request<PaginatedResponse<CustomFieldDefinition>>('GET', '/custom_field_definitions', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<CustomFieldDefinition> =>
      this.request<CustomFieldDefinition>('GET', `/custom_field_definitions/${id}`, options),

    create: (
      params: CustomFieldDefinitionCreateParams,
      options?: RequestOptions,
    ): Promise<CustomFieldDefinition> =>
      this.request<CustomFieldDefinition>('POST', '/custom_field_definitions', {
        ...options,
        body: params,
      }),

    update: (
      id: string,
      params: CustomFieldDefinitionUpdateParams,
      options?: RequestOptions,
    ): Promise<CustomFieldDefinition> =>
      this.request<CustomFieldDefinition>('PATCH', `/custom_field_definitions/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/custom_field_definitions/${id}`, options),
  }

  // ============================================
  // Authentication
  // ============================================

  readonly auth = {
    /**
     * Exchange credentials for an access token. The refresh token is delivered as an
     * HttpOnly cookie scoped to `/api/v3/admin/auth` — never returned in the response body.
     */
    login: (credentials: LoginCredentials, options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/login', { ...options, body: credentials }),

    /**
     * Rotate the refresh cookie and obtain a new access token. Driven entirely by the
     * `spree_admin_refresh_token` HttpOnly cookie + `X-CSRF-Token` header (set by the SDK).
     */
    refresh: (options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/refresh', options),

    /**
     * Revoke the current refresh token server-side and clear auth cookies.
     * Idempotent: succeeds even when no session exists.
     */
    logout: (options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', '/auth/logout', options),

    /**
     * Public (unauthenticated) lookup of a pending invitation by prefixed ID + token.
     * Returns just the safe-to-render context (store, role, inviter, invitee_exists)
     * so the SPA acceptance page can decide between sign-in and signup forms.
     */
    lookupInvitation: (
      id: string,
      token: string,
      options?: RequestOptions,
    ): Promise<InvitationLookup> =>
      this.request<InvitationLookup>('GET', `/auth/invitations/${id}/lookup`, {
        ...options,
        params: { token },
      }),

    /**
     * Public (unauthenticated) accept of an invitation. For existing accounts the
     * caller passes their password; for new accounts they pass password +
     * confirmation + names. Either path issues a JWT + refresh-token cookie
     * identical to `login`.
     */
    acceptInvitation: (
      id: string,
      token: string,
      params: InvitationAcceptParams,
      options?: RequestOptions,
    ): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', `/auth/invitations/${id}/accept`, {
        ...options,
        params: { token },
        body: params,
      }),
  }

  // ============================================
  // Current admin user + permissions
  // ============================================

  readonly me = {
    /** Get the current admin user profile and their serialized permissions. */
    get: (options?: RequestOptions): Promise<MeResponse> =>
      this.request<MeResponse>('GET', '/me', options),
  }

  // ============================================
  // Dashboard
  // ============================================

  readonly dashboard = {
    analytics: (
      params?: { date_from?: string; date_to?: string; currency?: string },
      options?: RequestOptions,
    ): Promise<DashboardAnalytics> =>
      this.request<DashboardAnalytics>('GET', '/dashboard/analytics', {
        ...options,
        params: params as Record<string, string>,
      }),
  }

  // ============================================
  // Store Settings
  // ============================================

  readonly store = {
    get: (options?: RequestOptions): Promise<Store> =>
      this.request<Store>('GET', '/store', options),

    update: (params: StoreUpdateParams, options?: RequestOptions): Promise<Store> =>
      this.request<Store>('PATCH', '/store', { ...options, body: params }),
  }

  // ============================================
  // Products
  // ============================================

  readonly products = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Product>> =>
      this.request<PaginatedResponse<Product>>('GET', '/products', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('GET', `/products/${id}`, {
        ...options,
        params: getParams(params),
      }),

    update: (id: string, params: ProductUpdateParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/products/${id}`, options),

    media: {
      list: (
        productId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Media>> =>
        this.request<PaginatedResponse<Media>>('GET', `/products/${productId}/media`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      create: (
        productId: string,
        params: MediaCreateParams,
        options?: RequestOptions,
      ): Promise<Media> =>
        this.request<Media>('POST', `/products/${productId}/media`, { ...options, body: params }),

      update: (
        productId: string,
        id: string,
        params: MediaUpdateParams,
        options?: RequestOptions,
      ): Promise<Media> =>
        this.request<Media>('PATCH', `/products/${productId}/media/${id}`, {
          ...options,
          body: params,
        }),

      delete: (productId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/products/${productId}/media/${id}`, options),
    },

    variants: {
      list: (
        productId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Variant>> =>
        this.request<PaginatedResponse<Variant>>('GET', `/products/${productId}/variants`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        productId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Variant> =>
        this.request<Variant>('GET', `/products/${productId}/variants/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        productId: string,
        params: VariantCreateParams,
        options?: RequestOptions,
      ): Promise<Variant> =>
        this.request<Variant>('POST', `/products/${productId}/variants`, {
          ...options,
          body: params,
        }),

      update: (
        productId: string,
        id: string,
        params: VariantUpdateParams,
        options?: RequestOptions,
      ): Promise<Variant> =>
        this.request<Variant>('PATCH', `/products/${productId}/variants/${id}`, {
          ...options,
          body: params,
        }),

      delete: (productId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/products/${productId}/variants/${id}`, options),

      media: {
        list: (
          productId: string,
          variantId: string,
          params?: ListParams & Record<string, unknown>,
          options?: RequestOptions,
        ): Promise<PaginatedResponse<Media>> =>
          this.request<PaginatedResponse<Media>>(
            'GET',
            `/products/${productId}/variants/${variantId}/media`,
            {
              ...options,
              params: params ? transformListParams(params) : undefined,
            },
          ),

        create: (
          productId: string,
          variantId: string,
          params: MediaCreateParams,
          options?: RequestOptions,
        ): Promise<Media> =>
          this.request<Media>('POST', `/products/${productId}/variants/${variantId}/media`, {
            ...options,
            body: params,
          }),

        update: (
          productId: string,
          variantId: string,
          id: string,
          params: MediaUpdateParams,
          options?: RequestOptions,
        ): Promise<Media> =>
          this.request<Media>('PATCH', `/products/${productId}/variants/${variantId}/media/${id}`, {
            ...options,
            body: params,
          }),

        delete: (
          productId: string,
          variantId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<void> =>
          this.request<void>(
            'DELETE',
            `/products/${productId}/variants/${variantId}/media/${id}`,
            options,
          ),
      },
    },

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Product']),
  }

  // ============================================
  // Orders
  // ============================================

  readonly orders = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Order>> =>
      this.request<PaginatedResponse<Order>>('GET', '/orders', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('GET', `/orders/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: OrderCreateParams, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('POST', '/orders', { ...options, body: params }),

    update: (
      id: string,
      params: OrderUpdateParams | Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/orders/${id}`, options),

    complete: (
      id: string,
      params?: OrderCompleteParams,
      options?: RequestOptions,
    ): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/complete`, { ...options, body: params }),

    cancel: (id: string, params?: OrderCancelParams, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/cancel`, { ...options, body: params }),

    approve: (id: string, params?: OrderApproveParams, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/approve`, { ...options, body: params }),

    resume: (id: string, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/resume`, options),

    resendConfirmation: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', `/orders/${id}/resend_confirmation`, options),

    giftCards: {
      apply: (
        orderId: string,
        params: GiftCardApplyParams,
        options?: RequestOptions,
      ): Promise<unknown> =>
        this.request('POST', `/orders/${orderId}/gift_cards`, { ...options, body: params }),

      remove: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/gift_cards/${id}`, options),
    },

    storeCredits: {
      apply: (
        orderId: string,
        params?: StoreCreditApplyParams,
        options?: RequestOptions,
      ): Promise<Order> =>
        this.request<Order>('POST', `/orders/${orderId}/store_credits`, {
          ...options,
          body: params,
        }),

      remove: (orderId: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/store_credits`, options),
    },

    items: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<LineItem>> =>
        this.request<PaginatedResponse<LineItem>>('GET', `/orders/${orderId}/items`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<LineItem> =>
        this.request<LineItem>('GET', `/orders/${orderId}/items/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        orderId: string,
        params: LineItemCreateParams,
        options?: RequestOptions,
      ): Promise<LineItem> =>
        this.request<LineItem>('POST', `/orders/${orderId}/items`, { ...options, body: params }),

      update: (
        orderId: string,
        id: string,
        params: LineItemUpdateParams,
        options?: RequestOptions,
      ): Promise<LineItem> =>
        this.request<LineItem>('PATCH', `/orders/${orderId}/items/${id}`, {
          ...options,
          body: params,
        }),

      delete: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/items/${id}`, options),
    },

    fulfillments: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Fulfillment>> =>
        this.request<PaginatedResponse<Fulfillment>>('GET', `/orders/${orderId}/fulfillments`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('GET', `/orders/${orderId}/fulfillments/${id}`, {
          ...options,
          params: getParams(params),
        }),

      update: (
        orderId: string,
        id: string,
        params: FulfillmentUpdateParams,
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}`, {
          ...options,
          body: params,
        }),

      fulfill: (orderId: string, id: string, options?: RequestOptions): Promise<Fulfillment> =>
        this.request<Fulfillment>(
          'PATCH',
          `/orders/${orderId}/fulfillments/${id}/fulfill`,
          options,
        ),

      cancel: (orderId: string, id: string, options?: RequestOptions): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/cancel`, options),

      resume: (orderId: string, id: string, options?: RequestOptions): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/resume`, options),

      split: (
        orderId: string,
        id: string,
        params: { quantity: number; line_item_id?: string },
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/split`, {
          ...options,
          body: params,
        }),
    },

    payments: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Payment>> =>
        this.request<PaginatedResponse<Payment>>('GET', `/orders/${orderId}/payments`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Payment> =>
        this.request<Payment>('GET', `/orders/${orderId}/payments/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        orderId: string,
        params: PaymentCreateParams,
        options?: RequestOptions,
      ): Promise<Payment> =>
        this.request<Payment>('POST', `/orders/${orderId}/payments`, { ...options, body: params }),

      capture: (orderId: string, id: string, options?: RequestOptions): Promise<Payment> =>
        this.request<Payment>('PATCH', `/orders/${orderId}/payments/${id}/capture`, options),

      void: (orderId: string, id: string, options?: RequestOptions): Promise<Payment> =>
        this.request<Payment>('PATCH', `/orders/${orderId}/payments/${id}/void`, options),
    },

    refunds: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Refund>> =>
        this.request<PaginatedResponse<Refund>>('GET', `/orders/${orderId}/refunds`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      create: (
        orderId: string,
        params: {
          payment_id: string
          amount: number
          reason_id?: string
          refund_reason_id?: string
        },
        options?: RequestOptions,
      ): Promise<Refund> =>
        this.request<Refund>('POST', `/orders/${orderId}/refunds`, { ...options, body: params }),
    },

    adjustments: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Adjustment>> =>
        this.request<PaginatedResponse<Adjustment>>('GET', `/orders/${orderId}/adjustments`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Adjustment> =>
        this.request<Adjustment>('GET', `/orders/${orderId}/adjustments/${id}`, options),
    },

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Order']),
  }

  // ============================================
  // Option Types
  // ============================================

  readonly optionTypes = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<OptionType>> =>
      this.request<PaginatedResponse<OptionType>>('GET', '/option_types', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<OptionType> =>
      this.request<OptionType>('GET', `/option_types/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: OptionTypeCreateParams, options?: RequestOptions): Promise<OptionType> =>
      this.request<OptionType>('POST', '/option_types', { ...options, body: params }),

    update: (
      id: string,
      params: OptionTypeUpdateParams,
      options?: RequestOptions,
    ): Promise<OptionType> =>
      this.request<OptionType>('PATCH', `/option_types/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/option_types/${id}`, options),

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::OptionType']),
  }

  // ============================================
  // Payment Methods
  // ============================================

  readonly paymentMethods = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<PaymentMethod>> =>
      this.request<PaginatedResponse<PaymentMethod>>('GET', '/payment_methods', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<PaymentMethod> =>
      this.request<PaymentMethod>('GET', `/payment_methods/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  // ============================================
  // Tags
  // ============================================

  readonly tags = {
    list: (
      params: { taggable_type: string; q?: string },
      options?: RequestOptions,
    ): Promise<{ data: Array<{ name: string }> }> =>
      this.request<{ data: Array<{ name: string }> }>('GET', '/tags', {
        ...options,
        params,
      }),
  }

  // ============================================
  // Exports (CSV: products, orders, customers, …)
  // ============================================

  /**
   * Queues asynchronous CSV exports and reports their progress. After
   * `create()`, poll `get(id)` until `done === true`, then fetch
   * `download_url` (with `Authorization: Bearer …`) and drive the browser
   * download via a Blob — top-level navigation cannot carry an in-memory
   * JWT, so `window.location.href = download_url` does not work.
   */
  readonly exports = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Export>> =>
      this.request<PaginatedResponse<Export>>('GET', '/exports', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Export> =>
      this.request<Export>('GET', `/exports/${id}`, options),

    create: (params: ExportCreateParams, options?: RequestOptions): Promise<Export> =>
      this.request<Export>('POST', '/exports', { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/exports/${id}`, options),
  }

  // ============================================
  // Customers
  // ============================================

  readonly customers = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Customer>> =>
      this.request<PaginatedResponse<Customer>>('GET', '/customers', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Customer> =>
      this.request<Customer>('GET', `/customers/${id}`, {
        ...options,
        params: getParams(params),
      }),

    creditCards: {
      list: (
        customerId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CreditCard>> =>
        this.request<PaginatedResponse<CreditCard>>(
          'GET',
          `/customers/${customerId}/credit_cards`,
          {
            ...options,
            params: params ? transformListParams(params) : undefined,
          },
        ),

      get: (
        customerId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<CreditCard> =>
        this.request<CreditCard>('GET', `/customers/${customerId}/credit_cards/${id}`, {
          ...options,
          params: getParams(params),
        }),

      delete: (customerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customers/${customerId}/credit_cards/${id}`, options),
    },

    create: (params: CustomerCreateParams, options?: RequestOptions): Promise<Customer> =>
      this.request<Customer>('POST', '/customers', { ...options, body: params }),

    update: (
      id: string,
      params: CustomerUpdateParams,
      options?: RequestOptions,
    ): Promise<Customer> =>
      this.request<Customer>('PATCH', `/customers/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/customers/${id}`, options),

    addresses: {
      list: (
        customerId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Address>> =>
        this.request<PaginatedResponse<Address>>('GET', `/customers/${customerId}/addresses`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        customerId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Address> =>
        this.request<Address>('GET', `/customers/${customerId}/addresses/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        customerId: string,
        params: CustomerAddressParams,
        options?: RequestOptions,
      ): Promise<Address> =>
        this.request<Address>('POST', `/customers/${customerId}/addresses`, {
          ...options,
          body: params,
        }),

      update: (
        customerId: string,
        id: string,
        params: CustomerAddressParams,
        options?: RequestOptions,
      ): Promise<Address> =>
        this.request<Address>('PATCH', `/customers/${customerId}/addresses/${id}`, {
          ...options,
          body: params,
        }),

      delete: (customerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customers/${customerId}/addresses/${id}`, options),
    },

    storeCredits: {
      list: (
        customerId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<StoreCredit>> =>
        this.request<PaginatedResponse<StoreCredit>>(
          'GET',
          `/customers/${customerId}/store_credits`,
          {
            ...options,
            params: params ? transformListParams(params) : undefined,
          },
        ),

      get: (
        customerId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<StoreCredit> =>
        this.request<StoreCredit>('GET', `/customers/${customerId}/store_credits/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        customerId: string,
        params: CustomerStoreCreditCreateParams,
        options?: RequestOptions,
      ): Promise<StoreCredit> =>
        this.request<StoreCredit>('POST', `/customers/${customerId}/store_credits`, {
          ...options,
          body: params,
        }),

      update: (
        customerId: string,
        id: string,
        params: CustomerStoreCreditUpdateParams,
        options?: RequestOptions,
      ): Promise<StoreCredit> =>
        this.request<StoreCredit>('PATCH', `/customers/${customerId}/store_credits/${id}`, {
          ...options,
          body: params,
        }),

      delete: (customerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customers/${customerId}/store_credits/${id}`, options),
    },

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::User']),
  }

  // ============================================
  // Categories
  // ============================================

  readonly categories = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Category>> =>
      this.request<PaginatedResponse<Category>>('GET', '/categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Category']),
  }

  // ============================================
  // Variants (top-level, for search/autocomplete)
  // ============================================

  readonly variants = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Variant>> =>
      this.request<PaginatedResponse<Variant>>('GET', '/variants', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Variant> =>
      this.request<Variant>('GET', `/variants/${id}`, {
        ...options,
        params: getParams(params),
      }),

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Variant']),
  }

  // ============================================
  // Tax Categories
  // ============================================

  readonly taxCategories = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<TaxCategory>> =>
      this.request<PaginatedResponse<TaxCategory>>('GET', '/tax_categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),
  }

  // ============================================
  // Stock Locations
  // ============================================

  readonly stockLocations = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StockLocation>> =>
      this.request<PaginatedResponse<StockLocation>>('GET', '/stock_locations', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StockLocation> =>
      this.request<StockLocation>('GET', `/stock_locations/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: StockLocationCreateParams, options?: RequestOptions): Promise<StockLocation> =>
      this.request<StockLocation>('POST', '/stock_locations', { ...options, body: params }),

    update: (
      id: string,
      params: StockLocationUpdateParams,
      options?: RequestOptions,
    ): Promise<StockLocation> =>
      this.request<StockLocation>('PATCH', `/stock_locations/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/stock_locations/${id}`, options),
  }

  // ============================================
  // Countries
  // ============================================

  readonly countries = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Country>> =>
      this.request<PaginatedResponse<Country>>('GET', '/countries', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      iso: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Country> =>
      this.request<Country>('GET', `/countries/${iso}`, {
        ...options,
        params: getParams(params),
      }),
  }

  // ============================================
  // Direct Uploads (Active Storage)
  // ============================================

  readonly directUploads = {
    create: (
      params: DirectUploadCreateParams,
      options?: RequestOptions,
    ): Promise<{
      direct_upload: { url: string; headers: Record<string, string> }
      signed_id: string
    }> => this.request('POST', '/direct_uploads', { ...options, body: params }),
  }

  // ============================================
  // Staff (admin users with role assignment on the current store)
  // ============================================

  readonly adminUsers = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<AdminUser>> =>
      this.request<PaginatedResponse<AdminUser>>('GET', '/admin_users', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<AdminUser> =>
      this.request<AdminUser>('GET', `/admin_users/${id}`, {
        ...options,
        params: getParams(params),
      }),

    update: (
      id: string,
      params: AdminUserUpdateParams,
      options?: RequestOptions,
    ): Promise<AdminUser> =>
      this.request<AdminUser>('PATCH', `/admin_users/${id}`, { ...options, body: params }),

    /**
     * Removes the user's role assignments on the current store. The account is
     * preserved — the user keeps access to any other stores. Mirrors the
     * legacy "remove from staff" behaviour rather than the legacy controller's
     * hard delete.
     */
    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/admin_users/${id}`, options),
  }

  // ============================================
  // Invitations (pending staff invitations)
  // ============================================

  readonly invitations = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Invitation>> =>
      this.request<PaginatedResponse<Invitation>>('GET', '/invitations', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Invitation> =>
      this.request<Invitation>('GET', `/invitations/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: InvitationCreateParams, options?: RequestOptions): Promise<Invitation> =>
      this.request<Invitation>('POST', '/invitations', { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/invitations/${id}`, options),

    /** Issues a fresh token + email for a pending invitation. */
    resend: (id: string, options?: RequestOptions): Promise<Invitation> =>
      this.request<Invitation>('PATCH', `/invitations/${id}/resend`, options),
  }

  // ============================================
  // API Keys (publishable + secret)
  // ============================================

  readonly apiKeys = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<ApiKey>> =>
      this.request<PaginatedResponse<ApiKey>>('GET', '/api_keys', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('GET', `/api_keys/${id}`, {
        ...options,
        params: getParams(params),
      }),

    /**
     * Creates a publishable or secret API key. For secret keys the response
     * carries `plaintext_token` exactly once — store it client-side immediately
     * because subsequent reads will return `null`.
     */
    create: (params: ApiKeyCreateParams, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('POST', '/api_keys', { ...options, body: params }),

    update: (id: string, params: ApiKeyUpdateParams, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('PATCH', `/api_keys/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/api_keys/${id}`, options),

    /** Marks a key revoked without deleting the row (preserves audit history). */
    revoke: (id: string, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('PATCH', `/api_keys/${id}/revoke`, options),
  }

  // ============================================
  // Roles (read-only — for staff role pickers)
  // ============================================

  readonly roles = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Role>> =>
      this.request<PaginatedResponse<Role>>('GET', '/roles', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Role> =>
      this.request<Role>('GET', `/roles/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }
}

// Re-export for type convenience
export type { ListParams, PaginatedResponse, RequestOptions }
