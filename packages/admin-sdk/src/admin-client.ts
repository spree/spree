import type {
  EmailPasswordLogin,
  ListParams,
  LoginCredentials,
  PaginatedResponse,
  ProviderLogin,
  RequestFn,
  RequestOptions,
} from '@spree/sdk-core'
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
  user: AdminUser
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
    selected_locale: string | null
  }
  permissions: PermissionRule[]
}

import type {
  AdminUserUpdateParams,
  AllowedOriginCreateParams,
  AllowedOriginUpdateParams,
  ApiKeyCreateParams,
  ApiKeyUpdateParams,
  ChannelCreateParams,
  ChannelUpdateParams,
  CustomerAddressParams,
  CustomerCreateParams,
  CustomerGroupCreateParams,
  CustomerGroupUpdateParams,
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
  GiftCardBatchCreateParams,
  GiftCardCreateParams,
  GiftCardUpdateParams,
  InvitationAcceptParams,
  InvitationCreateParams,
  LineItemCreateParams,
  LineItemUpdateParams,
  MarketCreateParams,
  MarketUpdateParams,
  MediaCreateParams,
  MediaUpdateParams,
  MeUpdateParams,
  OptionTypeCreateParams,
  OptionTypeUpdateParams,
  OrderApproveParams,
  OrderCancelParams,
  OrderCompleteParams,
  OrderCreateParams,
  OrderUpdateParams,
  PaymentCreateParams,
  PaymentMethodCreateParams,
  PaymentMethodType,
  PaymentMethodUpdateParams,
  PriceBulkUpsertRow,
  PriceCreateParams,
  PriceListCreateParams,
  PriceListUpdateParams,
  PriceUpdateParams,
  ProductCreateParams,
  ProductUpdateParams,
  PromotionActionCalculator,
  PromotionActionCreateParams,
  PromotionActionUpdateParams,
  PromotionCreateParams,
  PromotionRuleCreateParams,
  PromotionRuleUpdateParams,
  PromotionUpdateParams,
  ResourceTypeDefinition,
  StockItemUpdateParams,
  StockLocationCreateParams,
  StockLocationUpdateParams,
  StockTransferCreateParams,
  StoreCreditApplyParams,
  StoreUpdateParams,
  TaxCategoryCreateParams,
  TaxCategoryUpdateParams,
  VariantCreateParams,
  VariantUpdateParams,
  WebhookEndpointCreateParams,
  WebhookEndpointDisableParams,
  WebhookEndpointUpdateParams,
} from './params'
import type {
  Address,
  Adjustment,
  AdminUser,
  AllowedOrigin,
  ApiKey,
  Category,
  Channel,
  Country,
  CouponCode,
  CreditCard,
  Customer,
  CustomerGroup,
  CustomField,
  CustomFieldDefinition,
  Export,
  Fulfillment,
  GiftCard,
  GiftCardBatch,
  Invitation,
  LineItem,
  Market,
  Media,
  OptionType,
  Order,
  Payment,
  PaymentMethod,
  Price,
  PriceList,
  Product,
  Promotion,
  PromotionAction,
  PromotionRule,
  Refund,
  Role,
  StockItem,
  StockLocation,
  StockTransfer,
  Store,
  StoreCredit,
  StoreCreditCategory,
  TaxCategory,
  Variant,
  WebhookDelivery,
  WebhookEndpoint,
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
    lookupInvitation: (id: string, token: string, options?: RequestOptions): Promise<Invitation> =>
      this.request<Invitation>('GET', `/auth/invitations/${id}/lookup`, {
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

    /** Update the current admin's own profile (e.g. their UI language). */
    update: (params: MeUpdateParams, options?: RequestOptions): Promise<MeResponse> =>
      this.request<MeResponse>('PATCH', '/me', { ...options, body: params }),
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

    create: (params: ProductCreateParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('POST', '/products', { ...options, body: params }),

    update: (id: string, params: ProductUpdateParams, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/products/${id}`, options),

    /**
     * Duplicate a product. Returns the freshly-created clone (status `draft`,
     * name prefixed "COPY OF"). Media is duplicated by default server-side.
     */
    clone: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('POST', `/products/${id}/clone`, options),

    /**
     * Bulk-set `status` on a list of products. The server validates `status`
     * against the product status enum and reindexes affected products.
     */
    bulkStatusUpdate: (
      params: { ids: string[]; status: 'draft' | 'active' | 'archived' },
      options?: RequestOptions,
    ): Promise<{ product_count: number; status: string }> =>
      this.request('POST', '/products/bulk_status_update', { ...options, body: params }),

    /** Attach every product in `ids` to every category in `category_ids`. */
    bulkAddToCategories: (
      params: { ids: string[]; category_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; category_count: number }> =>
      this.request('POST', '/products/bulk_add_to_categories', { ...options, body: params }),

    /** Detach every product in `ids` from every category in `category_ids`. */
    bulkRemoveFromCategories: (
      params: { ids: string[]; category_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; category_count: number }> =>
      this.request('POST', '/products/bulk_remove_from_categories', { ...options, body: params }),

    /** Publish every product in `ids` on every channel in `channel_ids`. */
    bulkAddToChannels: (
      params: { ids: string[]; channel_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; channel_count: number }> =>
      this.request('POST', '/products/bulk_add_to_channels', { ...options, body: params }),

    /** Unpublish every product in `ids` from every channel in `channel_ids`. */
    bulkRemoveFromChannels: (
      params: { ids: string[]; channel_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; channel_count: number; removed: number }> =>
      this.request('POST', '/products/bulk_remove_from_channels', { ...options, body: params }),

    /** Add each tag name to every product. Tags are upserted by name. */
    bulkAddTags: (
      params: { ids: string[]; tags: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; tag_count: number }> =>
      this.request('POST', '/products/bulk_add_tags', { ...options, body: params }),

    /** Remove each tag name from every product. No-op for non-tagged. */
    bulkRemoveTags: (
      params: { ids: string[]; tags: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; tag_count: number }> =>
      this.request('POST', '/products/bulk_remove_tags', { ...options, body: params }),

    /** Soft-delete a list of products. */
    bulkDestroy: (
      params: { ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number }> =>
      this.request('DELETE', '/products/bulk_destroy', { ...options, body: params }),

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
          /** Decimal amount; see `PaymentCreateParams.amount` for the string rationale. */
          amount: string | number
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

    create: (params: PaymentMethodCreateParams, options?: RequestOptions): Promise<PaymentMethod> =>
      this.request<PaymentMethod>('POST', '/payment_methods', { ...options, body: params }),

    update: (
      id: string,
      params: PaymentMethodUpdateParams,
      options?: RequestOptions,
    ): Promise<PaymentMethod> =>
      this.request<PaymentMethod>('PATCH', `/payment_methods/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/payment_methods/${id}`, options),

    types: (options?: RequestOptions): Promise<{ data: PaymentMethodType[] }> =>
      this.request<{ data: PaymentMethodType[] }>('GET', '/payment_methods/types', options),
  }

  // ============================================
  // Price Lists (admin-only — wholesale, regional, volume pricing)
  // ============================================

  /**
   * CRUD plus lifecycle (`activate` / `deactivate`) for `Spree::PriceList`.
   * Membership (`product_ids: [...]`), rules (`rules: [...]`), and per-row
   * price overrides (`prices: [...]`) all ride along on the normal
   * `update` payload — one PATCH saves the entire editor. The
   * spreadsheet's initial render data is fetched via
   * `prices.list({ price_list_id_eq: …, currency_eq: … })`. Price lists
   * are admin-only; the storefront only ever sees the resolved price
   * (see `PriceSerializer#price_list_id`).
   */
  readonly priceLists = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<PriceList>> =>
      this.request<PaginatedResponse<PriceList>>('GET', '/price_lists', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<PriceList> =>
      this.request<PriceList>('GET', `/price_lists/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: PriceListCreateParams, options?: RequestOptions): Promise<PriceList> =>
      this.request<PriceList>('POST', '/price_lists', { ...options, body: params }),

    update: (
      id: string,
      params: PriceListUpdateParams,
      options?: RequestOptions,
    ): Promise<PriceList> =>
      this.request<PriceList>('PATCH', `/price_lists/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/price_lists/${id}`, options),

    /** draft|inactive → active (or → scheduled if `starts_at` is in the future). */
    activate: (id: string, options?: RequestOptions): Promise<PriceList> =>
      this.request<PriceList>('PATCH', `/price_lists/${id}/activate`, options),

    /** active|scheduled → inactive. */
    deactivate: (id: string, options?: RequestOptions): Promise<PriceList> =>
      this.request<PriceList>('PATCH', `/price_lists/${id}/deactivate`, options),

    /**
     * Returns `[{ type, label, description, preference_schema }]` for
     * every registered subclass in `Spree.pricing.rules`. Used to build
     * the "Add rule" picker + render a generic preferences form per
     * subclass. Rules themselves are not a separate REST resource —
     * the SPA ships them inline on the list's `update` payload.
     */
    ruleTypes: (options?: RequestOptions): Promise<{ data: ResourceTypeDefinition[] }> =>
      this.request<{ data: ResourceTypeDefinition[] }>(
        'GET',
        '/price_lists/price_rule_types',
        options,
      ),
  }

  // ============================================
  // Prices (generic — base prices AND price-list overrides)
  // ============================================

  /**
   * CRUD + bulk endpoints for `Spree::Price`. One resource covers both
   * base prices (`price_list_id: null`) and price-list overrides
   * (`price_list_id: pl_…`). The spreadsheet UI for a price list uses
   * `list({ price_list_id_eq, currency_eq, page, limit })` for the
   * paginated read and `bulkUpsert(...)` for the save.
   */
  readonly prices = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Price>> =>
      this.request<PaginatedResponse<Price>>('GET', '/prices', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Price> =>
      this.request<Price>('GET', `/prices/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: PriceCreateParams, options?: RequestOptions): Promise<Price> =>
      this.request<Price>('POST', '/prices', { ...options, body: params }),

    update: (id: string, params: PriceUpdateParams, options?: RequestOptions): Promise<Price> =>
      this.request<Price>('PATCH', `/prices/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/prices/${id}`, options),

    /**
     * One SQL round trip via `upsert_all` — model callbacks (PriceHistory,
     * after_save hooks) are bypassed for speed. Caller is responsible
     * for shipping sane values. Response is just `{ price_count }`: the
     * number of rows the DB touched.
     */
    bulkUpsert: (
      params: { prices: PriceBulkUpsertRow[] },
      options?: RequestOptions,
    ): Promise<{ price_count: number }> =>
      this.request('POST', '/prices/bulk_upsert', { ...options, body: params }),

    bulkDestroy: (
      params: { ids: string[] },
      options?: RequestOptions,
    ): Promise<{ price_count: number }> =>
      this.request('DELETE', '/prices/bulk_destroy', { ...options, body: params }),
  }

  // ============================================
  // Promotions (with nested actions, rules, coupon codes)
  // ============================================

  readonly promotions = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Promotion>> =>
      this.request<PaginatedResponse<Promotion>>('GET', '/promotions', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Promotion> =>
      this.request<Promotion>('GET', `/promotions/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: PromotionCreateParams, options?: RequestOptions): Promise<Promotion> =>
      this.request<Promotion>('POST', '/promotions', { ...options, body: params }),

    update: (
      id: string,
      params: PromotionUpdateParams,
      options?: RequestOptions,
    ): Promise<Promotion> =>
      this.request<Promotion>('PATCH', `/promotions/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/promotions/${id}`, options),

    actions: {
      list: (
        promotionId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<PromotionAction>> =>
        this.request<PaginatedResponse<PromotionAction>>(
          'GET',
          `/promotions/${promotionId}/promotion_actions`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (promotionId: string, id: string, options?: RequestOptions): Promise<PromotionAction> =>
        this.request<PromotionAction>(
          'GET',
          `/promotions/${promotionId}/promotion_actions/${id}`,
          options,
        ),

      create: (
        promotionId: string,
        params: PromotionActionCreateParams,
        options?: RequestOptions,
      ): Promise<PromotionAction> =>
        this.request<PromotionAction>('POST', `/promotions/${promotionId}/promotion_actions`, {
          ...options,
          body: params,
        }),

      update: (
        promotionId: string,
        id: string,
        params: PromotionActionUpdateParams,
        options?: RequestOptions,
      ): Promise<PromotionAction> =>
        this.request<PromotionAction>(
          'PATCH',
          `/promotions/${promotionId}/promotion_actions/${id}`,
          { ...options, body: params },
        ),

      delete: (promotionId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/promotions/${promotionId}/promotion_actions/${id}`, options),
    },

    rules: {
      list: (
        promotionId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<PromotionRule>> =>
        this.request<PaginatedResponse<PromotionRule>>(
          'GET',
          `/promotions/${promotionId}/promotion_rules`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (promotionId: string, id: string, options?: RequestOptions): Promise<PromotionRule> =>
        this.request<PromotionRule>(
          'GET',
          `/promotions/${promotionId}/promotion_rules/${id}`,
          options,
        ),

      create: (
        promotionId: string,
        params: PromotionRuleCreateParams,
        options?: RequestOptions,
      ): Promise<PromotionRule> =>
        this.request<PromotionRule>('POST', `/promotions/${promotionId}/promotion_rules`, {
          ...options,
          body: params,
        }),

      update: (
        promotionId: string,
        id: string,
        params: PromotionRuleUpdateParams,
        options?: RequestOptions,
      ): Promise<PromotionRule> =>
        this.request<PromotionRule>('PATCH', `/promotions/${promotionId}/promotion_rules/${id}`, {
          ...options,
          body: params,
        }),

      delete: (promotionId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/promotions/${promotionId}/promotion_rules/${id}`, options),
    },

    couponCodes: {
      list: (
        promotionId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CouponCode>> =>
        this.request<PaginatedResponse<CouponCode>>(
          'GET',
          `/promotions/${promotionId}/coupon_codes`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (promotionId: string, id: string, options?: RequestOptions): Promise<CouponCode> =>
        this.request<CouponCode>('GET', `/promotions/${promotionId}/coupon_codes/${id}`, options),
    },
  }

  readonly promotionActions = {
    types: (options?: RequestOptions): Promise<{ data: ResourceTypeDefinition[] }> =>
      this.request<{ data: ResourceTypeDefinition[] }>('GET', '/promotion_actions/types', options),

    calculators: (
      type: string,
      options?: RequestOptions,
    ): Promise<{ data: PromotionActionCalculator[] }> =>
      this.request<{ data: PromotionActionCalculator[] }>('GET', '/promotion_actions/calculators', {
        ...options,
        params: { type },
      }),
  }

  readonly promotionRules = {
    types: (options?: RequestOptions): Promise<{ data: ResourceTypeDefinition[] }> =>
      this.request<{ data: ResourceTypeDefinition[] }>('GET', '/promotion_rules/types', options),
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
  // Customer groups
  // ============================================

  readonly customerGroups = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<CustomerGroup>> =>
      this.request<PaginatedResponse<CustomerGroup>>('GET', '/customer_groups', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<CustomerGroup> =>
      this.request<CustomerGroup>('GET', `/customer_groups/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: CustomerGroupCreateParams, options?: RequestOptions): Promise<CustomerGroup> =>
      this.request<CustomerGroup>('POST', '/customer_groups', { ...options, body: params }),

    update: (
      id: string,
      params: CustomerGroupUpdateParams,
      options?: RequestOptions,
    ): Promise<CustomerGroup> =>
      this.request<CustomerGroup>('PATCH', `/customer_groups/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/customer_groups/${id}`, options),
  }

  // ============================================
  // Gift cards (admin-issued)
  // ============================================

  /**
   * CRUD for `Spree::GiftCard`. The list endpoint never embeds `customer`,
   * `created_by`, or `orders` by default — pass `expand=customer,created_by`
   * to populate row chips, or `expand=orders` on a detail read to surface
   * the consuming orders.
   */
  readonly giftCards = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<GiftCard>> =>
      this.request<PaginatedResponse<GiftCard>>('GET', '/gift_cards', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<GiftCard> =>
      this.request<GiftCard>('GET', `/gift_cards/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: GiftCardCreateParams, options?: RequestOptions): Promise<GiftCard> =>
      this.request<GiftCard>('POST', '/gift_cards', { ...options, body: params }),

    update: (
      id: string,
      params: GiftCardUpdateParams,
      options?: RequestOptions,
    ): Promise<GiftCard> =>
      this.request<GiftCard>('PATCH', `/gift_cards/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/gift_cards/${id}`, options),
  }

  // ============================================
  // Gift card batches (bulk issuance)
  // ============================================

  /**
   * Bulk-issue gift cards in groups of `codes_count`. The server generates
   * codes inline for batches up to `Spree.config.gift_card_batch_web_limit`
   * (default 500); larger batches enqueue a background job. The
   * SPA-facing list view filters cards by batch through
   * `/gift_cards?q[gift_card_batch_id_eq]=…`.
   */
  readonly giftCardBatches = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<GiftCardBatch>> =>
      this.request<PaginatedResponse<GiftCardBatch>>('GET', '/gift_card_batches', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<GiftCardBatch> =>
      this.request<GiftCardBatch>('GET', `/gift_card_batches/${id}`, options),

    create: (params: GiftCardBatchCreateParams, options?: RequestOptions): Promise<GiftCardBatch> =>
      this.request<GiftCardBatch>('POST', '/gift_card_batches', { ...options, body: params }),
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

    /**
     * Bulk-attach a set of customers to a set of groups. Both arrays carry
     * prefixed IDs; the server decodes them. Idempotent.
     */
    bulkAddToGroups: (
      params: { ids: string[]; customer_group_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ customer_count: number; customer_group_count: number }> =>
      this.request('POST', '/customers/bulk_add_to_groups', { ...options, body: params }),

    /**
     * Bulk-detach a set of customers from a set of groups. No-op for
     * non-members. Same shape as `bulkAddToGroups`.
     */
    bulkRemoveFromGroups: (
      params: { ids: string[]; customer_group_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ customer_count: number; customer_group_count: number }> =>
      this.request('POST', '/customers/bulk_remove_from_groups', { ...options, body: params }),

    /** Add each tag name to every customer. Tags are upserted by name. */
    bulkAddTags: (
      params: { ids: string[]; tags: string[] },
      options?: RequestOptions,
    ): Promise<{ customer_count: number; tag_count: number }> =>
      this.request('POST', '/customers/bulk_add_tags', { ...options, body: params }),

    /** Remove each tag name from every customer. No-op for non-tagged. */
    bulkRemoveTags: (
      params: { ids: string[]; tags: string[] },
      options?: RequestOptions,
    ): Promise<{ customer_count: number; tag_count: number }> =>
      this.request('POST', '/customers/bulk_remove_tags', { ...options, body: params }),

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

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<TaxCategory> =>
      this.request<TaxCategory>('GET', `/tax_categories/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: TaxCategoryCreateParams, options?: RequestOptions): Promise<TaxCategory> =>
      this.request<TaxCategory>('POST', '/tax_categories', { ...options, body: params }),

    update: (
      id: string,
      params: TaxCategoryUpdateParams,
      options?: RequestOptions,
    ): Promise<TaxCategory> =>
      this.request<TaxCategory>('PATCH', `/tax_categories/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/tax_categories/${id}`, options),
  }

  // ============================================
  // Channels (per-store distribution surfaces — online, POS, wholesale)
  // ============================================

  readonly channels = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Channel>> =>
      this.request<PaginatedResponse<Channel>>('GET', '/channels', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Channel> =>
      this.request<Channel>('GET', `/channels/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: ChannelCreateParams, options?: RequestOptions): Promise<Channel> =>
      this.request<Channel>('POST', '/channels', { ...options, body: params }),

    update: (id: string, params: ChannelUpdateParams, options?: RequestOptions): Promise<Channel> =>
      this.request<Channel>('PATCH', `/channels/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/channels/${id}`, options),

    /**
     * Publishes the listed products on this channel. Idempotent — re-publishing
     * an already-published product is a no-op for its existing publication
     * window unless +published_at+ / +unpublished_at+ are explicitly passed.
     * Cross-store onboarding is allowed: if the caller's API key has update
     * permission on a product owned by a sibling store, that product is
     * co-published onto this channel. Products the caller can't update are
     * silently dropped.
     */
    addProducts: (
      id: string,
      params: {
        product_ids: string[]
        published_at?: string | null
        unpublished_at?: string | null
      },
      options?: RequestOptions,
    ): Promise<{ product_count: number }> =>
      this.request<{ product_count: number }>('POST', `/channels/${id}/add_products`, {
        ...options,
        body: params,
      }),

    /** Unpublishes the listed products from this channel. */
    removeProducts: (
      id: string,
      params: { product_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number }> =>
      this.request<{ product_count: number }>('POST', `/channels/${id}/remove_products`, {
        ...options,
        body: params,
      }),
  }

  // ============================================
  // Store Credit Categories (read-only — for category dropdowns)
  // ============================================

  /**
   * Markets — store-scoped pricing regions. Each market binds one or more
   * countries to a currency, a default locale, and a tax-display policy.
   * Drives label resolution for `Spree::PriceRules::MarketRule` and is the
   * unit that price lists target.
   */
  readonly markets = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Market>> =>
      this.request<PaginatedResponse<Market>>('GET', '/markets', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Market> =>
      this.request<Market>('GET', `/markets/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: MarketCreateParams, options?: RequestOptions): Promise<Market> =>
      this.request<Market>('POST', '/markets', { ...options, body: params }),

    update: (id: string, params: MarketUpdateParams, options?: RequestOptions): Promise<Market> =>
      this.request<Market>('PATCH', `/markets/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/markets/${id}`, options),
  }

  // ============================================
  // Store Credit Categories
  // ============================================

  readonly storeCreditCategories = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StoreCreditCategory>> =>
      this.request<PaginatedResponse<StoreCreditCategory>>('GET', '/store_credit_categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StoreCreditCategory> =>
      this.request<StoreCreditCategory>('GET', `/store_credit_categories/${id}`, {
        ...options,
        params: getParams(params),
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
  // Stock Items
  // ============================================

  readonly stockItems = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StockItem>> =>
      this.request<PaginatedResponse<StockItem>>('GET', '/stock_items', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StockItem> =>
      this.request<StockItem>('GET', `/stock_items/${id}`, {
        ...options,
        params: getParams(params),
      }),

    update: (
      id: string,
      params: StockItemUpdateParams,
      options?: RequestOptions,
    ): Promise<StockItem> =>
      this.request<StockItem>('PATCH', `/stock_items/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/stock_items/${id}`, options),
  }

  // ============================================
  // Stock Transfers
  // ============================================

  /**
   * Inventory movement between stock locations, or external → location for
   * receives. Pass `source_location_id` for transfers; omit it to record a
   * vendor receive (external stock arriving at the destination).
   */
  readonly stockTransfers = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StockTransfer>> =>
      this.request<PaginatedResponse<StockTransfer>>('GET', '/stock_transfers', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StockTransfer> =>
      this.request<StockTransfer>('GET', `/stock_transfers/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: StockTransferCreateParams, options?: RequestOptions): Promise<StockTransfer> =>
      this.request<StockTransfer>('POST', '/stock_transfers', { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/stock_transfers/${id}`, options),
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
     * Describes the key that authenticated this request, including its live
     * scopes — useful to show the real, current authority of a secret key
     * (e.g. after a scope change) rather than a cached snapshot. Only available
     * to secret-key principals; a JWT admin has no single key to describe.
     */
    current: (options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('GET', '/api_keys/current', options ?? {}),

    /**
     * Creates a publishable or secret API key. For secret keys the response
     * carries `plaintext_token` exactly once — store it client-side immediately
     * because subsequent reads will return `null`.
     */
    create: (params: ApiKeyCreateParams, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('POST', '/api_keys', { ...options, body: params }),

    /**
     * Updates a key's `name`. `key_type` and `scopes` are fixed at creation —
     * to change authority, create a new key and revoke the old one (`revoke`).
     */
    update: (id: string, params: ApiKeyUpdateParams, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('PATCH', `/api_keys/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/api_keys/${id}`, options),

    /** Marks a key revoked without deleting the row (preserves audit history). */
    revoke: (id: string, options?: RequestOptions): Promise<ApiKey> =>
      this.request<ApiKey>('PATCH', `/api_keys/${id}/revoke`, options),
  }

  // ============================================
  // Allowed Origins (CORS allowlist for admin cookie auth)
  // ============================================

  /**
   * Origins permitted to call the admin API from a browser. Backs the
   * `Rack::Cors` allowlist and the CSRF boundary of the admin cookie session
   * (see `docs/plans/5.5-admin-auth-cookie-refresh.md`). Each entry is a
   * bare `scheme://host[:port]` — no paths, queries, or fragments.
   */
  readonly allowedOrigins = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<AllowedOrigin>> =>
      this.request<PaginatedResponse<AllowedOrigin>>('GET', '/allowed_origins', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<AllowedOrigin> =>
      this.request<AllowedOrigin>('GET', `/allowed_origins/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: AllowedOriginCreateParams, options?: RequestOptions): Promise<AllowedOrigin> =>
      this.request<AllowedOrigin>('POST', '/allowed_origins', { ...options, body: params }),

    update: (
      id: string,
      params: AllowedOriginUpdateParams,
      options?: RequestOptions,
    ): Promise<AllowedOrigin> =>
      this.request<AllowedOrigin>('PATCH', `/allowed_origins/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/allowed_origins/${id}`, options),
  }

  // ============================================
  // Webhook Endpoints + Deliveries
  // ============================================

  /**
   * Outbound webhook subscriptions: each endpoint receives a signed POST when
   * any subscribed event fires (`subscriptions` is a list of event names or
   * `*` patterns). The plaintext `secret_key` is returned **once** on create —
   * persist it client-side immediately because later reads serialize `null`.
   * Each endpoint exposes a nested `deliveries` log for auditing and retry.
   */
  readonly webhookEndpoints = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<WebhookEndpoint>> =>
      this.request<PaginatedResponse<WebhookEndpoint>>('GET', '/webhook_endpoints', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<WebhookEndpoint> =>
      this.request<WebhookEndpoint>('GET', `/webhook_endpoints/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (
      params: WebhookEndpointCreateParams,
      options?: RequestOptions,
    ): Promise<WebhookEndpoint> =>
      this.request<WebhookEndpoint>('POST', '/webhook_endpoints', { ...options, body: params }),

    update: (
      id: string,
      params: WebhookEndpointUpdateParams,
      options?: RequestOptions,
    ): Promise<WebhookEndpoint> =>
      this.request<WebhookEndpoint>('PATCH', `/webhook_endpoints/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/webhook_endpoints/${id}`, options),

    /** Fires a synthetic `webhook.test` delivery so admins can verify reachability. */
    sendTest: (id: string, options?: RequestOptions): Promise<WebhookDelivery> =>
      this.request<WebhookDelivery>('POST', `/webhook_endpoints/${id}/send_test`, options),

    /** Re-enables an endpoint that was disabled (manually or after auto-disable). */
    enable: (id: string, options?: RequestOptions): Promise<WebhookEndpoint> =>
      this.request<WebhookEndpoint>('PATCH', `/webhook_endpoints/${id}/enable`, options),

    /** Manually disable an endpoint with an optional human-readable reason. */
    disable: (
      id: string,
      params?: WebhookEndpointDisableParams,
      options?: RequestOptions,
    ): Promise<WebhookEndpoint> =>
      this.request<WebhookEndpoint>('PATCH', `/webhook_endpoints/${id}/disable`, {
        ...options,
        body: params,
      }),

    deliveries: {
      list: (
        endpointId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<WebhookDelivery>> =>
        this.request<PaginatedResponse<WebhookDelivery>>(
          'GET',
          `/webhook_endpoints/${endpointId}/deliveries`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (endpointId: string, id: string, options?: RequestOptions): Promise<WebhookDelivery> =>
        this.request<WebhookDelivery>(
          'GET',
          `/webhook_endpoints/${endpointId}/deliveries/${id}`,
          options,
        ),

      /**
       * Creates a new delivery row with the same payload + event_name and
       * queues it. The original row is preserved for audit history.
       */
      redeliver: (
        endpointId: string,
        id: string,
        options?: RequestOptions,
      ): Promise<WebhookDelivery> =>
        this.request<WebhookDelivery>(
          'POST',
          `/webhook_endpoints/${endpointId}/deliveries/${id}/redeliver`,
          options,
        ),
    },
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
export type {
  EmailPasswordLogin,
  ListParams,
  LoginCredentials,
  PaginatedResponse,
  ProviderLogin,
  RequestOptions,
}
