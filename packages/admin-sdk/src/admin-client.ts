import type {
  EmailPasswordLogin,
  ListParams,
  LoginCredentials,
  PaginatedResponse,
  PaginationMeta,
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

/**
 * One authentication provider the store accepts.
 *
 * `password` providers are driven by the login form; `redirect` providers send
 * the browser to `authorization_url` and come back through the OAuth callback.
 */
export interface AuthProvider {
  /** Registry key, e.g. "email" or "entra". Identifies the provider on login. */
  key: string
  kind: 'password' | 'redirect'
  /** Button label for redirect providers. Absent for password providers. */
  label?: string
  /** Where to send the browser. Absent if the provider is misconfigured or unreachable. */
  authorization_url?: string
}

export interface AuthProvidersResponse {
  providers: AuthProvider[]
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
  /**
   * The signed-in admin, serialized exactly like every other admin user — so a
   * profile save can be merged straight into the auth context without dropping
   * the fields the top bar reads (`full_name`, `avatar_url`).
   */
  user: AdminUser
  permissions: PermissionRule[]
  /**
   * The flat expanded catalog permission keys the user holds on the current
   * store (`read_orders`, `write_products`, …) — the same vocabulary as API
   * key scopes and the role editor. `write_x` is always accompanied by its
   * implied `read_x`.
   */
  permission_keys: string[]
}

import type {
  AdminUserUpdateParams,
  AllowedOriginCreateParams,
  AllowedOriginUpdateParams,
  ApiKeyCreateParams,
  ApiKeyUpdateParams,
  CatalogAssignParams,
  CatalogOrderMinimumParams,
  CatalogParams,
  CatalogProductTermsParams,
  CatalogQuantityRuleParams,
  CategoryCreateParams,
  CategoryRepositionParams,
  CategoryUpdateParams,
  ChannelCreateParams,
  ChannelUpdateParams,
  ClaimCreateParams,
  ClaimResolveParams,
  ClaimUpdateParams,
  CollectionCreateParams,
  CollectionUpdateParams,
  CommissionRateCreateParams,
  CommissionRateUpdateParams,
  CommissionRuleType,
  CompanyAddressParams,
  CompanyMembershipCreateParams,
  CompanyParams,
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
  CustomFieldResourceType,
  CustomFieldUpdateParams,
  DeliveryCreateParams,
  DeliveryMarkDeliveredParams,
  DeliveryMethodParams,
  DeliveryOriginGroupParams,
  DeliveryProfileParams,
  DeliveryUpdateParams,
  DeliveryZoneParams,
  DigitalAssetCreateParams,
  DigitalAssetProvider,
  DigitalAssetUpdateParams,
  DirectUploadCreateParams,
  ExchangeCreateParams,
  ExchangeFulfillParams,
  ExchangeReceiveParams,
  ExchangeUpdateParams,
  ExportCreateParams,
  FulfillmentCreateParams,
  FulfillmentFulfillParams,
  FulfillmentMarkDeliveredParams,
  FulfillmentSplitParams,
  FulfillmentUpdateParams,
  GiftCardApplyParams,
  GiftCardBatchCreateParams,
  GiftCardCreateParams,
  GiftCardUpdateParams,
  ImportCompleteMappingParams,
  ImportCreateParams,
  IntegrationCreateParams,
  IntegrationTypeDefinition,
  IntegrationUpdateParams,
  InvitationAcceptParams,
  InvitationCreateParams,
  LineItemCreateParams,
  LineItemUpdateParams,
  MarketCreateParams,
  MarketUpdateParams,
  MediaCreateParams,
  MediaLibraryCreateParams,
  MediaUpdateParams,
  MediaUsageReference,
  MeUpdateParams,
  OptionTypeCreateParams,
  OptionTypeUpdateParams,
  OrderCancelParams,
  OrderCompleteParams,
  OrderCreateParams,
  OrderRoutingRuleCreateParams,
  OrderRoutingRuleUpdateParams,
  OrderUpdateParams,
  PasswordResetParams,
  PasswordResetRequestParams,
  PaymentCreateParams,
  PaymentMethodCreateParams,
  PaymentMethodType,
  PaymentMethodUpdateParams,
  PolicyCreateParams,
  PolicyUpdateParams,
  PreferenceField,
  PriceBulkUpsertRow,
  PriceCreateParams,
  PriceListCreateParams,
  PriceListUpdateParams,
  PriceUpdateParams,
  ProductCreateParams,
  ProductMembershipRepositionParams,
  ProductTypeApplyToProductsResponse,
  ProductTypeCreateParams,
  ProductTypeUpdateParams,
  ProductUpdateParams,
  PromotionActionCalculator,
  PromotionActionCreateParams,
  PromotionActionUpdateParams,
  PromotionCreateParams,
  PromotionRuleCreateParams,
  PromotionRuleUpdateParams,
  PromotionUpdateParams,
  ReasonCreateParams,
  ReasonUpdateParams,
  ResourceTypeDefinition,
  ReturnCreateParams,
  ReturnReceiveParams,
  ReturnRefundParams,
  ReturnUpdateParams,
  RoleCreateParams,
  RoleUpdateParams,
  SellerApproveParams,
  SellerCreateParams,
  SellerInviteParams,
  SellerOnboarding,
  SellerRejectParams,
  SellerReopenOnboardingParams,
  SellerRequirementCreateParams,
  SellerRequirementReviewParams,
  SellerRequirementType,
  SellerRequirementUpdateParams,
  SellerRequirementWaiveParams,
  SellerSuspendParams,
  SellerUpdateParams,
  SetupCountries,
  SetupParams,
  SetupStatus,
  ShippingLabelCreateParams,
  StockLevelBulkUpsertRow,
  StockLevelUpdateParams,
  StockLocationCreateParams,
  StockLocationUpdateParams,
  StockTransferCreateParams,
  StoreCreditApplyParams,
  StoreDataSources,
  StorePayoutProvider,
  StoreUpdateParams,
  TaxCategoryCreateParams,
  TaxCategoryUpdateParams,
  TaxExemptionCertificateParams,
  TaxIdentifierParams,
  TaxRateParams,
  TrackingCarrierOption,
  VariantCreateParams,
  VariantUpdateParams,
  WebhookEndpointCreateParams,
  WebhookEndpointDisableParams,
  WebhookEndpointUpdateParams,
} from './params'
import type {
  Address,
  AdminUser,
  AllowedOrigin,
  ApiKey,
  Catalog,
  CatalogAssignment,
  CatalogOrderMinimum,
  CatalogProduct,
  CatalogProductTerm,
  CatalogQuantityRule,
  Category,
  Channel,
  Claim,
  ClaimReason,
  Collection,
  CommissionLine,
  CommissionRate,
  Company,
  CompanyInvitation,
  CompanyMembership,
  Country,
  CouponCode,
  CreditCard,
  Customer,
  CustomerGroup,
  CustomField,
  CustomFieldDefinition,
  Delivery,
  DeliveryMethod,
  DeliveryMethodRule,
  DeliveryOriginGroup,
  DeliveryProfile,
  DeliveryRateProviderOption,
  DeliveryZone,
  DigitalAsset,
  DigitalLink,
  Discount,
  Exchange,
  Export,
  Fee,
  Fulfillment,
  FulfillmentProviderOption,
  GiftCard,
  GiftCardBatch,
  Import,
  ImportRow,
  Integration,
  Invitation,
  LineItem,
  Locale,
  Market,
  Media,
  OptionType,
  Order,
  OrderCancellationReason,
  OrderRoutingRule,
  Payment,
  PaymentMethod,
  Permission,
  Policy,
  Price,
  PriceList,
  Product,
  ProductType,
  Promotion,
  PromotionAction,
  PromotionRule,
  Refund,
  RefundReason,
  ResourceTranslations,
  ResourceTranslationsNode,
  Return,
  ReturnReason,
  Role,
  Seller,
  SellerPayout,
  SellerRequirement,
  SellerRequirementSubmission,
  SellerTeamMember,
  SellerTransfer,
  ShippingLabel,
  StockLevel,
  StockLocation,
  StockMovement,
  StockTransfer,
  Store,
  StoreCredit,
  TaxCategory,
  TaxExemptionCertificate,
  TaxIdentifier,
  TaxLine,
  TaxRate,
  TranslatableResource,
  TranslationBatchEntry,
  TranslationCoverage,
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
  'Spree::Collection': '/collections',
  'Spree::OptionType': '/option_types',
} as const satisfies Record<Exclude<CustomFieldOwnerType, string & {}>, string>

export class AdminClient {
  /**
   * Low-level request function for calling custom Admin API endpoints —
   * e.g. ones added by a Spree extension gem that doesn't ship its own
   * client.
   *
   * Uses the same auth headers (secret API key or JWT, whichever was
   * configured), retry logic, and base URL as the built-in resources.
   * Paths are relative to `/api/v3/admin`.
   *
   * @example
   * ```ts
   * import { createAdminClient } from '@spree/admin-sdk'
   * import type { PaginatedResponse } from '@spree/admin-sdk'
   *
   * interface Brand { id: string; name: string; slug: string }
   *
   * const client = createAdminClient({ baseUrl: 'https://api.shop.com', token: '...' })
   *
   * const brands = await client.request<PaginatedResponse<Brand>>('GET', '/brands')
   * const brand = await client.request<Brand>('GET', '/brands/brand_2X9aQf7kEw')
   * ```
   */
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
   * Builds a read-only `translations` accessor for a translatable parent
   * resource. `get` returns the full matrix (source values + per-locale
   * translations + nested translatable children). Writes go through
   * `client.translations.batch(...)`, the single atomic write surface.
   * @internal
   */
  private parentScopedTranslations(basePath: string) {
    return {
      get: (parentId: string, options?: RequestOptions): Promise<ResourceTranslations> =>
        this.request<{ data: ResourceTranslations }>(
          'GET',
          `${basePath}/${parentId}/translations`,
          options,
        ).then((r) => r.data),
    }
  }

  /**
   * The uniform nested products surface every product-curating parent
   * exposes — categories, collections, catalogs and price lists all speak
   * the same protocol. Both writes are bulk: one request adds or removes
   * any number of products, and the counts report what actually changed
   * (already-present ids don't fail an add, non-members don't fail a
   * remove).
   */
  private productMembership<Row = Product>(basePath: string) {
    return {
      /**
       * A parent whose listing says more about a member than the plain
       * product does — a catalog reports what its agreement charges — types
       * `Row` accordingly.
       */
      list: (
        parentId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Row>> =>
        this.request<PaginatedResponse<Row>>('GET', `${basePath}/${parentId}/products`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      /** Bulk-adds products; already-present rows are skipped. */
      create: (
        parentId: string,
        productIds: string[],
        options?: RequestOptions,
      ): Promise<{ added_count: number }> =>
        this.request<{ added_count: number }>('POST', `${basePath}/${parentId}/products`, {
          ...options,
          body: { product_ids: productIds },
        }),

      /** Bulk-removes products; ids that aren't members are ignored. */
      delete: (
        parentId: string,
        productIds: string[],
        options?: RequestOptions,
      ): Promise<{ removed_count: number }> =>
        this.request<{ removed_count: number }>('DELETE', `${basePath}/${parentId}/products`, {
          ...options,
          body: { product_ids: productIds },
        }),
    }
  }

  /**
   * `productMembership` plus per-member reposition, for the parents whose
   * membership carries a manual order (categories, collections).
   */
  private positionedProductMembership(basePath: string) {
    return {
      ...this.productMembership(basePath),

      /** Persists a drag-to-reorder; `new_position` is a 0-based index. */
      reposition: (
        parentId: string,
        productId: string,
        params: ProductMembershipRepositionParams,
        options?: RequestOptions,
      ): Promise<void> =>
        this.request<void>('PATCH', `${basePath}/${parentId}/products/${productId}/reposition`, {
          ...options,
          body: params,
        }),
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

    /**
     * What a definition can be attached to. Comes from the server's registry,
     * so a resource an extension adds is offered without a dashboard release.
     */
    resourceTypes: (options?: RequestOptions): Promise<{ data: CustomFieldResourceType[] }> =>
      this.request<{ data: CustomFieldResourceType[] }>(
        'GET',
        '/custom_field_definitions/resource_types',
        options,
      ),

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
     * List the authentication providers this store accepts. Unauthenticated — it
     * is read before a session exists, to decide whether the login page shows the
     * password form, SSO buttons, or both.
     */
    providers: (options?: RequestOptions): Promise<AuthProvidersResponse> =>
      this.request<AuthProvidersResponse>('GET', '/auth/providers', options),

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

    /**
     * Public (unauthenticated) first-run setup availability check. True only
     * while the installation has no admin user — the login page uses it to
     * offer the setup screen.
     */
    setupStatus: (options?: RequestOptions): Promise<SetupStatus> =>
      this.request<SetupStatus>('GET', '/auth/setup', options),

    /**
     * Public (unauthenticated) list of countries the store can be set up in,
     * each with the currency and official languages derived from it. Returns
     * 404 once any admin user exists.
     */
    setupCountries: (options?: RequestOptions): Promise<SetupCountries> =>
      this.request<SetupCountries>('GET', '/auth/setup/countries', options),

    /**
     * Public (unauthenticated) first-run setup: creates the first admin
     * account and names the store, authorized by the one-time setup token
     * printed at install time. Issues a JWT + refresh-token cookie identical
     * to `login`. Returns 404 once any admin user exists.
     */
    completeSetup: (params: SetupParams, options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/setup', { ...options, body: params }),

    /**
     * Public (unauthenticated) request for a password reset email. Always
     * resolves (202) whether or not the email matches an account, to prevent
     * enumeration. The emailed link points at `redirect_url` (validated against
     * the store's allowed origins) with the reset token appended as `?token=`.
     */
    requestPasswordReset: (
      params: PasswordResetRequestParams,
      options?: RequestOptions,
    ): Promise<void> =>
      this.request<void>('POST', '/auth/password_resets', { ...options, body: params }),

    /**
     * Public (unauthenticated) consume of a password reset token: sets the new
     * password and signs the admin in (JWT + refresh-token cookie, like `login`).
     * The token is single-use — it invalidates as soon as the password changes.
     */
    resetPassword: (
      token: string,
      params: PasswordResetParams,
      options?: RequestOptions,
    ): Promise<AuthTokens> =>
      this.request<AuthTokens>('PATCH', `/auth/password_resets/${encodeURIComponent(token)}`, {
        ...options,
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

    /**
     * The pricing and inventory engines this store can choose between, and
     * whether each is usable — a provider whose integration is not connected
     * is listed but not selectable.
     */
    dataSources: (options?: RequestOptions): Promise<StoreDataSources> =>
      this.request<{ data: StoreDataSources }>('GET', '/store/data_sources', options).then(
        (r) => r.data,
      ),
  }

  /** The locales a merchant can translate content into for the current store. */
  readonly locales = {
    list: (options?: RequestOptions): Promise<Locale[]> =>
      this.request<{ data: Locale[] }>('GET', '/locales', options).then((r) => r.data),
  }

  /** Every translatable resource type and its translatable fields (registry). */
  readonly translatableResources = {
    list: (options?: RequestOptions): Promise<TranslatableResource[]> =>
      this.request<{ data: TranslatableResource[] }>(
        'GET',
        '/translatable_resources',
        options,
      ).then((r) => r.data),
  }

  /**
   * Translation writes that span multiple records (e.g. an option type plus
   * all its option values) in one atomic request. Each entry names its own
   * resource_type + resource_id; all succeed or none do.
   */
  readonly translations = {
    /**
     * Translation coverage across a whole resource type, for the centralized
     * Translations page.
     *
     * `resource_type` is sent as a plain param rather than through
     * `transformListParams`, which would wrap it into `q[resource_type]` and
     * leave the server without the one param it requires.
     */
    coverage: (
      resourceType: string,
      params?: ListParams & { search?: string } & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<{ data: TranslationCoverage; meta: PaginationMeta }> => {
      // `resource_type` and `search` are read as plain params by the server;
      // routing them through `transformListParams` would wrap both into
      // Ransack predicates (`q[resource_type]`) the controller never sees.
      const { page, limit, search, ...filters } = params ?? {}

      return this.request<{ data: TranslationCoverage; meta: PaginationMeta }>(
        'GET',
        '/translations',
        {
          ...options,
          params: {
            resource_type: resourceType,
            ...(page === undefined ? {} : { page: page as number }),
            ...(limit === undefined ? {} : { limit: limit as number }),
            ...(search === undefined ? {} : { search: search as string }),
            ...transformListParams(filters),
          },
        },
      )
    },

    batch: (
      entries: TranslationBatchEntry[],
      options?: RequestOptions,
    ): Promise<ResourceTranslationsNode[]> =>
      this.request<{ data: ResourceTranslationsNode[] }>('POST', '/translations/batch', {
        ...options,
        body: { translations: entries },
      }).then((r) => r.data),
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
     * Accept a product a seller submitted, putting it on sale. Refuses
     * anything not awaiting review — reaching `active` from elsewhere is an
     * ordinary status write.
     */
    approve: (id: string, options?: RequestOptions): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}/approve`, options),

    /**
     * Turn a submission down. The reason is shown to the seller, so they know
     * what to change before submitting again.
     */
    reject: (
      id: string,
      params?: { reason?: string },
      options?: RequestOptions,
    ): Promise<Product> =>
      this.request<Product>('PATCH', `/products/${id}/reject`, { ...options, body: params }),

    /**
     * Bulk-set `status` on a list of products. The server validates `status`
     * against the product status enum and reindexes affected products.
     */
    bulkStatusUpdate: (
      params: { ids: string[]; status: 'draft' | 'active' | 'archived' },
      options?: RequestOptions,
    ): Promise<{ product_count: number; status: string }> =>
      this.request('POST', '/products/bulk_status_update', { ...options, body: params }),

    /**
     * Let sellers list their own offers against every product in `ids`.
     *
     * Only the marketplace's own products can be opened; ids naming a product
     * a seller owns outright are reported as skipped.
     */
    bulkOpenToSellers: (
      params: { ids: string[] },
      options?: RequestOptions,
    ): Promise<{
      product_count: number
      open_to_sellers: boolean
      skipped_seller_owned_count?: number
    }> => this.request('POST', '/products/bulk_open_to_sellers', { ...options, body: params }),

    /**
     * Close them again. Offers already on a product stay — withdrawing one is
     * a review decision, not a side effect of this.
     */
    bulkCloseToSellers: (
      params: { ids: string[] },
      options?: RequestOptions,
    ): Promise<{
      product_count: number
      open_to_sellers: boolean
      skipped_seller_owned_count?: number
    }> => this.request('POST', '/products/bulk_close_to_sellers', { ...options, body: params }),

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

    /**
     * Attach every product in `ids` to every collection in `collection_ids`.
     * Automatic collections are skipped (their membership comes from rules), so
     * `collection_count` reports how many were actually applied.
     */
    bulkAddToCollections: (
      params: { ids: string[]; collection_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; collection_count: number }> =>
      this.request('POST', '/products/bulk_add_to_collections', { ...options, body: params }),

    /** Detach every product in `ids` from every collection in `collection_ids`. */
    bulkRemoveFromCollections: (
      params: { ids: string[]; collection_ids: string[] },
      options?: RequestOptions,
    ): Promise<{ product_count: number; collection_count: number }> =>
      this.request('POST', '/products/bulk_remove_from_collections', { ...options, body: params }),

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

    digitalAssets: {
      list: (
        productId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<DigitalAsset>> =>
        this.request<PaginatedResponse<DigitalAsset>>(
          'GET',
          `/products/${productId}/digital_assets`,
          {
            ...options,
            params: params ? transformListParams(params) : undefined,
          },
        ),

      create: (
        productId: string,
        params: DigitalAssetCreateParams,
        options?: RequestOptions,
      ): Promise<DigitalAsset> =>
        this.request<DigitalAsset>('POST', `/products/${productId}/digital_assets`, {
          ...options,
          body: params,
        }),

      update: (
        productId: string,
        id: string,
        params: DigitalAssetUpdateParams,
        options?: RequestOptions,
      ): Promise<DigitalAsset> =>
        this.request<DigitalAsset>('PATCH', `/products/${productId}/digital_assets/${id}`, {
          ...options,
          body: params,
        }),

      delete: (productId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/products/${productId}/digital_assets/${id}`, options),

      /**
       * The sources a merchant can pick for a new asset: the uploaded-file
       * default plus any host-registered provider. A host with only the default
       * gets a single-entry list.
       */
      providers: (
        productId: string,
        options?: RequestOptions,
      ): Promise<{ data: DigitalAssetProvider[] }> =>
        this.request<{ data: DigitalAssetProvider[] }>(
          'GET',
          `/products/${productId}/digital_assets/providers`,
          options,
        ),
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

      /**
       * Accept a seller's offer on this product, putting it on sale.
       *
       * An offer reaches `active` only this way: a plain status write is
       * refused while it is in review, so every decision records who made it.
       */
      approve: (
        productId: string,
        id: string,
        params?: { note?: string },
        options?: RequestOptions,
      ): Promise<Variant> =>
        this.request<Variant>('PATCH', `/products/${productId}/variants/${id}/approve`, {
          ...options,
          body: params ?? {},
        }),

      /** Send a seller's offer back. The reason is shown to the seller. */
      reject: (
        productId: string,
        id: string,
        params?: { reason?: string },
        options?: RequestOptions,
      ): Promise<Variant> =>
        this.request<Variant>('PATCH', `/products/${productId}/variants/${id}/reject`, {
          ...options,
          body: params ?? {},
        }),

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

    translations: this.parentScopedTranslations('/products'),
  }

  // ============================================
  // Digital links
  // ============================================

  /**
   * Download grants issued to customers when an order is placed. They are never
   * created by hand — `reset` gives a customer their allowance back.
   */
  readonly digitalLinks = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DigitalLink>> =>
      this.request<PaginatedResponse<DigitalLink>>('GET', '/digital_links', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    retrieve: (id: string, options?: RequestOptions): Promise<DigitalLink> =>
      this.request<DigitalLink>('GET', `/digital_links/${id}`, options),

    reset: (id: string, options?: RequestOptions): Promise<DigitalLink> =>
      this.request<DigitalLink>('PATCH', `/digital_links/${id}/reset`, options),
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

    approve: (id: string, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/approve`, options),

    resendConfirmation: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', `/orders/${id}/resend_confirmation`, options),

    /** Re-sends the "your files are ready" email. No-op when the order has no downloads. */
    resendDigitalLinks: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', `/orders/${id}/resend_digital_links`, options),

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

      create: (
        orderId: string,
        params: FulfillmentCreateParams,
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('POST', `/orders/${orderId}/fulfillments`, {
          ...options,
          body: params,
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

      // Passing `items` ships only those quantities: they are split into a new
      // fulfillment, which is what comes back — the addressed fulfillment keeps
      // the remainder and stays open.
      fulfill: (
        orderId: string,
        id: string,
        params?: FulfillmentFulfillParams,
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/fulfill`, {
          ...options,
          body: params,
        }),

      // Confirms the customer received the goods. Staff can record this by
      // hand — a merchant with no carrier integration still needs a delivered
      // state — and carriers reach the same endpoint through their webhooks.
      markDelivered: (
        orderId: string,
        id: string,
        params?: FulfillmentMarkDeliveredParams,
        options?: RequestOptions,
      ): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/mark_delivered`, {
          ...options,
          body: params,
        }),

      cancel: (orderId: string, id: string, options?: RequestOptions): Promise<Fulfillment> =>
        this.request<Fulfillment>('PATCH', `/orders/${orderId}/fulfillments/${id}/cancel`, options),

      /**
       * The carrier documents bought or uploaded for a parcel. Creating one
       * with no body buys it through the parcel's carrier account; creating it
       * with a `file` (a signed blob id from `directUploads.create()`) records
       * postage the merchant bought elsewhere. To print one, fetch
       * `download_url` with the `Authorization` header and drive the browser
       * download from a Blob — the bytes are streamed through the API rather
       * than served from storage.
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
          params?: ShippingLabelCreateParams,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'POST',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels`,
            { ...options, body: params },
          ),

        /**
         * Asks the carrier to refund a purchased label. The answer is
         * `refunded` when the carrier settled at once, `refund_requested` when
         * it will decide later. Uploaded labels cannot be refunded.
         */
        refund: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'PATCH',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/labels/${id}/refund`,
            options,
          ),

        /** Uploaded labels only — a purchased label is refunded instead. */
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

      /**
       * The tracked consignments of a parcel — one per tracking number, each
       * carrying the carrier status last reported. A fulfillment's own
       * `tracking` field summarizes the first of them.
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
          params: DeliveryCreateParams,
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'POST',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries`,
            { ...options, body: params },
          ),

        /** A corrected tracking number starts the carrier journey over. */
        update: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          params: DeliveryUpdateParams,
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'PATCH',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries/${id}`,
            { ...options, body: params },
          ),

        /** Refused for a consignment a label minted — refund the label. */
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

        /**
         * Staff confirming one consignment arrived. The parcel becomes
         * delivered once every one of its consignments has.
         */
        markDelivered: (
          orderId: string,
          fulfillmentId: string,
          id: string,
          params?: DeliveryMarkDeliveredParams,
          options?: RequestOptions,
        ): Promise<Delivery> =>
          this.request<Delivery>(
            'PATCH',
            `/orders/${orderId}/fulfillments/${fulfillmentId}/deliveries/${id}/mark_delivered`,
            { ...options, body: params },
          ),
      },

      // Returns every fulfillment on the order, since a split re-shapes the
      // source as well as creating the new one (and destroys the source when
      // it is fully drained).
      split: (
        orderId: string,
        id: string,
        params: FulfillmentSplitParams,
        options?: RequestOptions,
      ): Promise<{ data: Fulfillment[] }> =>
        this.request<{ data: Fulfillment[] }>(
          'PATCH',
          `/orders/${orderId}/fulfillments/${id}/split`,
          {
            ...options,
            body: params,
          },
        ),
    },

    returns: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Return>> =>
        this.request<PaginatedResponse<Return>>('GET', `/orders/${orderId}/returns`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('GET', `/orders/${orderId}/returns/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        orderId: string,
        params: ReturnCreateParams,
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('POST', `/orders/${orderId}/returns`, {
          ...options,
          body: params,
        }),

      update: (
        orderId: string,
        id: string,
        params: ReturnUpdateParams,
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}`, {
          ...options,
          body: params,
        }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/approve`, options),

      receive: (
        orderId: string,
        id: string,
        params?: ReturnReceiveParams,
        options?: RequestOptions,
      ): Promise<Return> =>
        this.request<Return>('PATCH', `/orders/${orderId}/returns/${id}/receive`, {
          ...options,
          body: params,
        }),

      refund: (
        orderId: string,
        id: string,
        params?: ReturnRefundParams,
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

      /**
       * The prepaid label for the parcel coming back. Bought through the
       * carrier that shipped the goods out, or recorded from a file when the
       * merchant bought postage elsewhere — the same shape as a fulfillment's
       * labels, owned by the return instead.
       *
       * The customer downloads it from the storefront; this is the merchant's
       * side of the same record.
       */
      labels: {
        list: (
          orderId: string,
          returnId: string,
          options?: RequestOptions,
        ): Promise<{ data: ShippingLabel[] }> =>
          this.request<{ data: ShippingLabel[] }>(
            'GET',
            `/orders/${orderId}/returns/${returnId}/labels`,
            options,
          ),

        get: (
          orderId: string,
          returnId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'GET',
            `/orders/${orderId}/returns/${returnId}/labels/${id}`,
            options,
          ),

        create: (
          orderId: string,
          returnId: string,
          params?: ShippingLabelCreateParams,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>('POST', `/orders/${orderId}/returns/${returnId}/labels`, {
            ...options,
            body: params,
          }),

        refund: (
          orderId: string,
          returnId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<ShippingLabel> =>
          this.request<ShippingLabel>(
            'PATCH',
            `/orders/${orderId}/returns/${returnId}/labels/${id}/refund`,
            options,
          ),

        /** Uploaded labels only — a purchased label is refunded instead. */
        delete: (
          orderId: string,
          returnId: string,
          id: string,
          options?: RequestOptions,
        ): Promise<void> =>
          this.request<void>(
            'DELETE',
            `/orders/${orderId}/returns/${returnId}/labels/${id}`,
            options,
          ),
      },
    },

    exchanges: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Exchange>> =>
        this.request<PaginatedResponse<Exchange>>('GET', `/orders/${orderId}/exchanges`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('GET', `/orders/${orderId}/exchanges/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        orderId: string,
        params: ExchangeCreateParams,
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('POST', `/orders/${orderId}/exchanges`, {
          ...options,
          body: params,
        }),

      update: (
        orderId: string,
        id: string,
        params: ExchangeUpdateParams,
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}`, {
          ...options,
          body: params,
        }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/approve`, options),

      receive: (
        orderId: string,
        id: string,
        params?: ExchangeReceiveParams,
        options?: RequestOptions,
      ): Promise<Exchange> =>
        this.request<Exchange>('PATCH', `/orders/${orderId}/exchanges/${id}/receive`, {
          ...options,
          body: params,
        }),

      fulfill: (
        orderId: string,
        id: string,
        params?: ExchangeFulfillParams,
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

    claims: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Claim>> =>
        this.request<PaginatedResponse<Claim>>('GET', `/orders/${orderId}/claims`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (
        orderId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('GET', `/orders/${orderId}/claims/${id}`, {
          ...options,
          params: getParams(params),
        }),

      create: (
        orderId: string,
        params: ClaimCreateParams,
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('POST', `/orders/${orderId}/claims`, {
          ...options,
          body: params,
        }),

      update: (
        orderId: string,
        id: string,
        params: ClaimUpdateParams,
        options?: RequestOptions,
      ): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}`, {
          ...options,
          body: params,
        }),

      approve: (orderId: string, id: string, options?: RequestOptions): Promise<Claim> =>
        this.request<Claim>('PATCH', `/orders/${orderId}/claims/${id}/approve`, options),

      resolve: (
        orderId: string,
        id: string,
        params: ClaimResolveParams,
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

    taxLines: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<TaxLine>> =>
        this.request<PaginatedResponse<TaxLine>>('GET', `/orders/${orderId}/tax_lines`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<TaxLine> =>
        this.request<TaxLine>('GET', `/orders/${orderId}/tax_lines/${id}`, options),
    },

    discounts: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Discount>> =>
        this.request<PaginatedResponse<Discount>>('GET', `/orders/${orderId}/discounts`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Discount> =>
        this.request<Discount>('GET', `/orders/${orderId}/discounts/${id}`, options),

      /**
       * Creates a manual discount. With `line_item_id` a single row is
       * created; without it the value is distributed across line items
       * (largest remainder). Works on completed orders.
       */
      create: (
        orderId: string,
        params: {
          label: string
          value: string | number
          value_type?: 'flat' | 'percent'
          line_item_id?: string
        },
        options?: RequestOptions,
      ): Promise<{ data: Discount[] }> =>
        this.request<{ data: Discount[] }>('POST', `/orders/${orderId}/discounts`, {
          ...options,
          body: params,
        }),

      /** Manual rows only — promotion-sourced rows respond 422 (`discount_not_editable`). */
      update: (
        orderId: string,
        id: string,
        params: { label?: string; amount?: string | number },
        options?: RequestOptions,
      ): Promise<Discount> =>
        this.request<Discount>('PATCH', `/orders/${orderId}/discounts/${id}`, {
          ...options,
          body: params,
        }),

      /** Manual rows only — promotion-sourced rows respond 422 (`discount_not_editable`). */
      delete: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/discounts/${id}`, options),
    },

    /**
     * Discount codes on a draft order — same pending semantics as the
     * storefront cart endpoint (a real-but-not-yet-eligible code is stored
     * and activates on recalculation). Completed orders respond 422
     * (`discount_not_editable`); use manual discounts instead.
     */
    discountCodes: {
      create: (
        orderId: string,
        params: { code: string },
        options?: RequestOptions,
      ): Promise<Order> =>
        this.request<Order>('POST', `/orders/${orderId}/discount_codes`, {
          ...options,
          body: params,
        }),

      /** `code` is the discount code string, not an ID. */
      delete: (orderId: string, code: string, options?: RequestOptions): Promise<Order> =>
        this.request<Order>(
          'DELETE',
          `/orders/${orderId}/discount_codes/${encodeURIComponent(code)}`,
          options,
        ),
    },

    fees: {
      list: (
        orderId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Fee>> =>
        this.request<PaginatedResponse<Fee>>('GET', `/orders/${orderId}/fees`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      get: (orderId: string, id: string, options?: RequestOptions): Promise<Fee> =>
        this.request<Fee>('GET', `/orders/${orderId}/fees/${id}`, options),

      create: (
        orderId: string,
        params: {
          label: string
          amount: string | number
          kind?: string
          line_item_id?: string
          fulfillment_id?: string
        },
        options?: RequestOptions,
      ): Promise<Fee> =>
        this.request<Fee>('POST', `/orders/${orderId}/fees`, { ...options, body: params }),

      update: (
        orderId: string,
        id: string,
        params: { label?: string; amount?: string | number; kind?: string },
        options?: RequestOptions,
      ): Promise<Fee> =>
        this.request<Fee>('PATCH', `/orders/${orderId}/fees/${id}`, { ...options, body: params }),

      delete: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/fees/${id}`, options),
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

    translations: this.parentScopedTranslations('/option_types'),
  }

  // ============================================
  // Payment Methods
  // ============================================

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

    /** Registered delivery calculator classes with preference schemas. */
    calculators: (
      options?: RequestOptions,
    ): Promise<{ data: Array<{ type: string; name: string; preference_schema: unknown[] }> }> =>
      this.request<{ data: Array<{ type: string; name: string; preference_schema: unknown[] }> }>(
        'GET',
        '/delivery_methods/calculators',
        options,
      ),

    /**
     * Registered fulfillment provider strategies plus the registered
     * fulfillment-type vocabulary (the strict set delivery methods and
     * product types validate against).
     */
    fulfillmentProviders: (
      options?: RequestOptions,
    ): Promise<{ data: FulfillmentProviderOption[] }> =>
      this.request<{ data: FulfillmentProviderOption[] }>(
        'GET',
        '/delivery_methods/fulfillment_providers',
        options,
      ),

    /** Rate providers available to this store, plus the default when none is chosen. */
    rateProviders: (
      options?: RequestOptions,
    ): Promise<{ data: DeliveryRateProviderOption[]; default: string }> =>
      this.request<{ data: DeliveryRateProviderOption[]; default: string }>(
        'GET',
        '/delivery_methods/rate_providers',
        options,
      ),

    /** Eligibility rules on a delivery method (item total / weight bounds, …). */
    rules: {
      list: (
        deliveryMethodId: string,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<DeliveryMethodRule>> =>
        this.request<PaginatedResponse<DeliveryMethodRule>>(
          'GET',
          `/delivery_methods/${deliveryMethodId}/rules`,
          options,
        ),

      create: (
        deliveryMethodId: string,
        params: {
          type: string
          active?: boolean
          preferences?: Record<string, unknown>
          /** Prefixed product IDs — association-backed rules (excluded_products_rule). */
          product_ids?: string[]
        },
        options?: RequestOptions,
      ): Promise<DeliveryMethodRule> =>
        this.request<DeliveryMethodRule>('POST', `/delivery_methods/${deliveryMethodId}/rules`, {
          ...options,
          body: params,
        }),

      update: (
        deliveryMethodId: string,
        id: string,
        params: {
          active?: boolean
          preferences?: Record<string, unknown>
          /** Prefixed product IDs — association-backed rules (excluded_products_rule). */
          product_ids?: string[]
        },
        options?: RequestOptions,
      ): Promise<DeliveryMethodRule> =>
        this.request<DeliveryMethodRule>(
          'PATCH',
          `/delivery_methods/${deliveryMethodId}/rules/${id}`,
          { ...options, body: params },
        ),

      delete: (deliveryMethodId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/delivery_methods/${deliveryMethodId}/rules/${id}`, options),
    },

    /** Registered rule kinds with preference schemas for building pickers. */
    ruleTypes: (
      options?: RequestOptions,
    ): Promise<{
      data: Array<{
        type: string
        name: string
        description: string
        preference_schema: PreferenceField[]
        /** Association-backed config the rule accepts, e.g. `['product_ids']`. */
        association_fields: string[]
      }>
    }> =>
      this.request<{
        data: Array<{
          type: string
          name: string
          description: string
          preference_schema: PreferenceField[]
          association_fields: string[]
        }>
      }>('GET', '/delivery_method_rules/types', options),
  }

  readonly deliveryProfiles = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DeliveryProfile>> =>
      this.request<PaginatedResponse<DeliveryProfile>>('GET', '/delivery_profiles', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<DeliveryProfile> =>
      this.request<DeliveryProfile>('GET', `/delivery_profiles/${id}`, options),

    create: (
      params: DeliveryProfileParams & { name: string },
      options?: RequestOptions,
    ): Promise<DeliveryProfile> =>
      this.request<DeliveryProfile>('POST', '/delivery_profiles', {
        ...options,
        body: params,
      }),

    /** `stock_location_ids` replaces the profile's full location set. */
    update: (
      id: string,
      params: DeliveryProfileParams,
      options?: RequestOptions,
    ): Promise<DeliveryProfile> =>
      this.request<DeliveryProfile>('PATCH', `/delivery_profiles/${id}`, {
        ...options,
        body: params,
      }),

    /** The default profile and profiles still referenced by products cannot be deleted. */
    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/delivery_profiles/${id}`, options),

    /** Registered profile kinds (shipping, digital, extension kinds). */
    kinds: (options?: RequestOptions): Promise<{ data: Array<{ type: string; kind: string }> }> =>
      this.request<{ data: Array<{ type: string; kind: string }> }>(
        'GET',
        '/delivery_profiles/kinds',
        options,
      ),

    /** Origin groups partition a profile's fulfillment origins; its zones and methods each belong to one. */
    originGroups: {
      list: (
        deliveryProfileId: string,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<DeliveryOriginGroup>> =>
        this.request<PaginatedResponse<DeliveryOriginGroup>>(
          'GET',
          `/delivery_profiles/${deliveryProfileId}/origin_groups`,
          options,
        ),

      create: (
        deliveryProfileId: string,
        params: DeliveryOriginGroupParams,
        options?: RequestOptions,
      ): Promise<DeliveryOriginGroup> =>
        this.request<DeliveryOriginGroup>(
          'POST',
          `/delivery_profiles/${deliveryProfileId}/origin_groups`,
          { ...options, body: params },
        ),

      update: (
        deliveryProfileId: string,
        id: string,
        params: DeliveryOriginGroupParams,
        options?: RequestOptions,
      ): Promise<DeliveryOriginGroup> =>
        this.request<DeliveryOriginGroup>(
          'PATCH',
          `/delivery_profiles/${deliveryProfileId}/origin_groups/${id}`,
          { ...options, body: params },
        ),

      /** The last group, or one still holding zones or methods, cannot be deleted. */
      delete: (deliveryProfileId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>(
          'DELETE',
          `/delivery_profiles/${deliveryProfileId}/origin_groups/${id}`,
          options,
        ),
    },
  }

  readonly trackingCarriers = {
    /**
     * Registered tracking carriers (Spree.tracking_carriers) a tracking
     * number can be pinned to — the source for carrier pickers. Extensions
     * that register carriers appear here without a client change.
     */
    list: (options?: RequestOptions): Promise<{ data: TrackingCarrierOption[] }> =>
      this.request<{ data: TrackingCarrierOption[] }>('GET', '/tracking_carriers', options),
  }

  readonly deliveryZones = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<DeliveryZone>> =>
      this.request<PaginatedResponse<DeliveryZone>>('GET', '/delivery_zones', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    /** Members are expand-gated; pass `{ expand: ['members'] }` to edit a zone. */
    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<DeliveryZone> =>
      this.request<DeliveryZone>('GET', `/delivery_zones/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: DeliveryZoneParams, options?: RequestOptions): Promise<DeliveryZone> =>
      this.request<DeliveryZone>('POST', '/delivery_zones', { ...options, body: params }),

    /** `members` replaces the zone's full member set atomically. */
    update: (
      id: string,
      params: DeliveryZoneParams,
      options?: RequestOptions,
    ): Promise<DeliveryZone> =>
      this.request<DeliveryZone>('PATCH', `/delivery_zones/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/delivery_zones/${id}`, options),
  }

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
  // Integrations (admin-only — provider credentials per store)
  // ============================================

  readonly integrations = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Integration>> =>
      this.request<PaginatedResponse<Integration>>('GET', '/integrations', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Integration> =>
      this.request<Integration>('GET', `/integrations/${id}`, options),

    create: (params: IntegrationCreateParams, options?: RequestOptions): Promise<Integration> =>
      this.request<Integration>('POST', '/integrations', { ...options, body: params }),

    update: (
      id: string,
      params: IntegrationUpdateParams,
      options?: RequestOptions,
    ): Promise<Integration> =>
      this.request<Integration>('PATCH', `/integrations/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/integrations/${id}`, options),

    /** Registered integration types with schemas and per-store connected state. */
    types: (options?: RequestOptions): Promise<{ data: IntegrationTypeDefinition[] }> =>
      this.request<{ data: IntegrationTypeDefinition[] }>('GET', '/integrations/types', options),

    /** Live connection check; nothing is persisted. */
    test: (
      id: string,
      options?: RequestOptions,
    ): Promise<{ connected: boolean; error_message: string | null }> =>
      this.request<{ connected: boolean; error_message: string | null }>(
        'POST',
        `/integrations/${id}/test`,
        options,
      ),
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
    /** Which products the list prices — the same nested surface categories,
     * collections and catalogs expose. Adding materializes placeholder
     * prices per variant × currency; removing hard-deletes the rows. */
    products: this.productMembership('/price_lists'),

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
  // Marketplace sellers
  // ============================================

  /**
   * CRUD for `Spree::Seller`, plus the lifecycle actions. Status is never
   * writable through `update` — each transition is a workflow that also
   * sends mail and runs extension hooks, so moving a seller by hand would
   * skip all of it.
   */
  readonly sellers = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Seller>> =>
      this.request<PaginatedResponse<Seller>>('GET', '/sellers', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Seller> =>
      this.request<Seller>('GET', `/sellers/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: SellerCreateParams, options?: RequestOptions): Promise<Seller> =>
      this.request<Seller>('POST', '/sellers', { ...options, body: params }),

    update: (id: string, params: SellerUpdateParams, options?: RequestOptions): Promise<Seller> =>
      this.request<Seller>('PATCH', `/sellers/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/sellers/${id}`, options),

    /** Opens the seller's team to someone; they join when they accept. */
    invite: (id: string, params: SellerInviteParams, options?: RequestOptions): Promise<Seller> =>
      this.request<Seller>('POST', `/sellers/${id}/invite`, { ...options, body: params }),

    /**
     * Lets the seller trade — also the way back from suspended or rejected.
     * Refused while a required onboarding requirement is unmet, unless
     * `override_requirements` says the operator means it anyway.
     */
    approve: (
      id: string,
      params?: SellerApproveParams,
      options?: RequestOptions,
    ): Promise<Seller> =>
      this.request<Seller>('PATCH', `/sellers/${id}/approve`, { ...options, body: params }),

    /** Where this seller stands against the marketplace's checklist. */
    onboarding: (id: string, options?: RequestOptions): Promise<SellerOnboarding> =>
      this.request<SellerOnboarding>('GET', `/sellers/${id}/onboarding`, options),

    /** Sends a seller awaiting review back to onboarding, with a note. */
    reopenOnboarding: (
      id: string,
      params?: SellerReopenOnboardingParams,
      options?: RequestOptions,
    ): Promise<Seller> =>
      this.request<Seller>('PATCH', `/sellers/${id}/reopen_onboarding`, {
        ...options,
        body: params,
      }),

    /**
     * Who runs this seller. The operator's view of what the seller panel
     * manages for itself — and the only way to repair a seller whose team has
     * locked itself out.
     */
    team: {
      list: (sellerId: string, options?: RequestOptions): Promise<{ data: SellerTeamMember[] }> =>
        this.request<{ data: SellerTeamMember[] }>('GET', `/sellers/${sellerId}/team`, options),

      /** Revokes a member's access. */
      remove: (sellerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/sellers/${sellerId}/team/${id}`, options),
    },

    /** Offers to join this seller that nobody has accepted yet. */
    invitations: {
      list: (sellerId: string, options?: RequestOptions): Promise<{ data: Invitation[] }> =>
        this.request<{ data: Invitation[] }>('GET', `/sellers/${sellerId}/invitations`, options),

      /** Withdraws an offer. */
      remove: (sellerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/sellers/${sellerId}/invitations/${id}`, options),

      /** Sends the email again; refused once the offer has lapsed. */
      resend: (sellerId: string, id: string, options?: RequestOptions): Promise<Invitation> =>
        this.request<Invitation>('PATCH', `/sellers/${sellerId}/invitations/${id}/resend`, options),
    },

    /** What this seller submitted about the requirements, and its decisions. */
    requirementSubmissions: {
      list: (
        sellerId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<SellerRequirementSubmission>> =>
        this.request<PaginatedResponse<SellerRequirementSubmission>>(
          'GET',
          `/sellers/${sellerId}/requirement_submissions`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (
        sellerId: string,
        id: string,
        options?: RequestOptions,
      ): Promise<SellerRequirementSubmission> =>
        this.request<SellerRequirementSubmission>(
          'GET',
          `/sellers/${sellerId}/requirement_submissions/${id}`,
          options,
        ),

      accept: (
        sellerId: string,
        id: string,
        params?: SellerRequirementReviewParams,
        options?: RequestOptions,
      ): Promise<SellerRequirementSubmission> =>
        this.request<SellerRequirementSubmission>(
          'PATCH',
          `/sellers/${sellerId}/requirement_submissions/${id}/accept`,
          { ...options, body: params },
        ),

      reject: (
        sellerId: string,
        id: string,
        params?: SellerRequirementReviewParams,
        options?: RequestOptions,
      ): Promise<SellerRequirementSubmission> =>
        this.request<SellerRequirementSubmission>(
          'PATCH',
          `/sellers/${sellerId}/requirement_submissions/${id}/reject`,
          { ...options, body: params },
        ),

      /** Excuses this seller from one requirement the store asks of everyone. */
      waive: (
        sellerId: string,
        params: SellerRequirementWaiveParams,
        options?: RequestOptions,
      ): Promise<SellerRequirementSubmission> =>
        this.request<SellerRequirementSubmission>(
          'POST',
          `/sellers/${sellerId}/requirement_submissions`,
          { ...options, body: params },
        ),
    },

    suspend: (
      id: string,
      params?: SellerSuspendParams,
      options?: RequestOptions,
    ): Promise<Seller> =>
      this.request<Seller>('PATCH', `/sellers/${id}/suspend`, { ...options, body: params }),

    reject: (id: string, params?: SellerRejectParams, options?: RequestOptions): Promise<Seller> =>
      this.request<Seller>('PATCH', `/sellers/${id}/reject`, { ...options, body: params }),
  }

  // ============================================
  // Seller onboarding requirements
  // ============================================

  /**
   * What this marketplace asks of a seller before it will let them trade.
   * Rows the operator composes from registered kinds — `types()` is what a
   * picker renders, and a marketplace's own kinds appear there as soon as
   * they are registered server-side.
   */
  readonly sellerRequirements = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<SellerRequirement>> =>
      this.request<PaginatedResponse<SellerRequirement>>('GET', '/seller_requirements', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<SellerRequirement> =>
      this.request<SellerRequirement>('GET', `/seller_requirements/${id}`, options),

    create: (
      params: SellerRequirementCreateParams,
      options?: RequestOptions,
    ): Promise<SellerRequirement> =>
      this.request<SellerRequirement>('POST', '/seller_requirements', { ...options, body: params }),

    update: (
      id: string,
      params: SellerRequirementUpdateParams,
      options?: RequestOptions,
    ): Promise<SellerRequirement> =>
      this.request<SellerRequirement>('PATCH', `/seller_requirements/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/seller_requirements/${id}`, options),

    /** The kinds an operator can add, with each one's configuration shape. */
    types: (options?: RequestOptions): Promise<{ data: SellerRequirementType[] }> =>
      this.request<{ data: SellerRequirementType[] }>('GET', '/seller_requirements/types', options),
  }

  // ============================================
  // Commissions (what the marketplace charges its sellers)
  // ============================================

  /**
   * CRUD for `Spree::CommissionRate`. Targeting rides the regular payload as
   * `rules: [...]` — the whole editor saves in one round-trip, and the server
   * replaces the rate's rules with exactly what it is sent.
   */
  readonly commissionRates = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<CommissionRate>> =>
      this.request<PaginatedResponse<CommissionRate>>('GET', '/commission_rates', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<CommissionRate> =>
      this.request<CommissionRate>('GET', `/commission_rates/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (
      params: CommissionRateCreateParams,
      options?: RequestOptions,
    ): Promise<CommissionRate> =>
      this.request<CommissionRate>('POST', '/commission_rates', { ...options, body: params }),

    update: (
      id: string,
      params: CommissionRateUpdateParams,
      options?: RequestOptions,
    ): Promise<CommissionRate> =>
      this.request<CommissionRate>('PATCH', `/commission_rates/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/commission_rates/${id}`, options),

    /**
     * Every registered rule kind with the schema describing its configuration,
     * so a client builds its editor from what the marketplace actually has
     * rather than a list hardcoded to match core's.
     */
    ruleTypes: (options?: RequestOptions): Promise<{ data: CommissionRuleType[] }> =>
      this.request<{ data: CommissionRuleType[] }>('GET', '/commission_rates/rule_types', options),
  }

  /**
   * Read-only view of `Spree::CommissionLine` — what each sale actually earned
   * the marketplace, frozen when the order was placed. There is no write path:
   * correcting a charge is a reversal, not an edit.
   */
  readonly commissionLines = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<CommissionLine>> =>
      this.request<PaginatedResponse<CommissionLine>>('GET', '/commission_lines', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<CommissionLine> =>
      this.request<CommissionLine>('GET', `/commission_lines/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  // ============================================
  // Seller fund ledger
  // ============================================

  /**
   * Read-only view of `Spree::SellerTransfer` — what one order earned one
   * seller, credited when the goods went out. There is no write path: a
   * refund writes a reversal, which is another row rather than an edit.
   */
  readonly sellerTransfers = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<SellerTransfer>> =>
      this.request<PaginatedResponse<SellerTransfer>>('GET', '/seller_transfers', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<SellerTransfer> =>
      this.request<SellerTransfer>('GET', `/seller_transfers/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  /**
   * `Spree::SellerPayout` — one settlement to one seller. Created by the
   * sweep on that seller's own schedule rather than by a caller, so there is
   * no create or update. `complete` is what the built-in provider waits for:
   * the operator saying the bank transfer went out.
   */
  readonly sellerPayouts = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<SellerPayout>> =>
      this.request<PaginatedResponse<SellerPayout>>('GET', '/seller_payouts', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<SellerPayout> =>
      this.request<SellerPayout>('GET', `/seller_payouts/${id}`, {
        ...options,
        params: getParams(params),
      }),

    complete: (
      id: string,
      data?: { reference?: string },
      options?: RequestOptions,
    ): Promise<SellerPayout> =>
      this.request<SellerPayout>('PATCH', `/seller_payouts/${id}/complete`, {
        ...options,
        body: data,
      }),
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
  // Post-sale, across all orders (read-only — creating any of these needs an
  // order, so writes live on client.orders.{returns,exchanges,claims})
  // ============================================

  readonly returns = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Return>> =>
      this.request<PaginatedResponse<Return>>('GET', '/returns', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Return> =>
      this.request<Return>('GET', `/returns/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  readonly exchanges = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Exchange>> =>
      this.request<PaginatedResponse<Exchange>>('GET', '/exchanges', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Exchange> =>
      this.request<Exchange>('GET', `/exchanges/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  readonly claims = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Claim>> =>
      this.request<PaginatedResponse<Claim>>('GET', '/claims', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Claim> =>
      this.request<Claim>('GET', `/claims/${id}`, {
        ...options,
        params: getParams(params),
      }),
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
  // Tax configuration
  // ============================================

  /**
   * Tax rates for the built-in engine. A rate names the jurisdiction it
   * applies to — a country and optionally one of its states — rather than a
   * zone; one naming no country taxes everywhere.
   */
  readonly taxRates = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<TaxRate>> =>
      this.request<PaginatedResponse<TaxRate>>('GET', '/tax_rates', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<TaxRate> =>
      this.request<TaxRate>('GET', `/tax_rates/${id}`, { ...options, params: getParams(params) }),

    create: (params: TaxRateParams, options?: RequestOptions): Promise<TaxRate> =>
      this.request<TaxRate>('POST', '/tax_rates', { ...options, body: params }),

    update: (id: string, params: TaxRateParams, options?: RequestOptions): Promise<TaxRate> =>
      this.request<TaxRate>('PATCH', `/tax_rates/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/tax_rates/${id}`, options),
  }

  /**
   * The tax engines this installation has available, each declaring the
   * domains it cannot handle — so a dashboard can warn that pairing the
   * built-in engine with a US market means no local sales tax, rather than
   * letting a merchant discover it at checkout.
   */
  readonly taxProviders = {
    list: (options?: RequestOptions): Promise<PaginatedResponse<Record<string, unknown>>> =>
      this.request<PaginatedResponse<Record<string, unknown>>>('GET', '/tax_providers', options),
  }

  /**
   * How this installation can pay its sellers. Discovery only — which one a
   * store uses is a store preference, so there is nothing here to create.
   *
   * Each says whether it is usable by this store today, and whether it needs
   * sellers to hold an account with it: choosing one changes what the
   * marketplace has to ask of its sellers before it can pay them.
   */
  readonly payoutProviders = {
    list: (options?: RequestOptions): Promise<PaginatedResponse<StorePayoutProvider>> =>
      this.request<PaginatedResponse<StorePayoutProvider>>('GET', '/payout_providers', options),
  }

  // ============================================
  // Companies (business customers)
  // ============================================

  /**
   * Business customers as an organization tree: self-referential company
   * nodes (`kind: 'company' | 'division'`), each with an address book and
   * members whose standing covers the node's subtree. A legal-entity node
   * holds the tax registration that goes on its invoices and the exemption
   * certificates that decide whether its purchases are taxed; a division
   * reads both through its nearest legal-entity ancestor.
   *
   * List roots with `{ parent_id_null: 1 }` and a node's children with
   * `{ parent_id_eq: 'comp_…' }`. Deleting a node destroys its subtree.
   *
   * Address-book entries, memberships and invitations all belong to a node,
   * so every one of them is reached through it.
   */
  readonly companies = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Company>> =>
      this.request<PaginatedResponse<Company>>('GET', '/companies', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Company> =>
      this.request<Company>('GET', `/companies/${id}`, { ...options, params: getParams(params) }),

    create: (params: CompanyParams, options?: RequestOptions): Promise<Company> =>
      this.request<Company>('POST', '/companies', { ...options, body: params }),

    /** Re-parenting is an ordinary update — depth, cycle and store revalidate. */
    update: (id: string, params: CompanyParams, options?: RequestOptions): Promise<Company> =>
      this.request<Company>('PATCH', `/companies/${id}`, { ...options, body: params }),

    /** Destroys the node and its whole subtree. */
    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/companies/${id}`, options),

    addresses: {
      list: (
        companyId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<Address>> =>
        this.request<PaginatedResponse<Address>>('GET', `/companies/${companyId}/addresses`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      create: (
        companyId: string,
        params: CompanyAddressParams,
        options?: RequestOptions,
      ): Promise<Address> =>
        this.request<Address>('POST', `/companies/${companyId}/addresses`, {
          ...options,
          body: params,
        }),

      get: (companyId: string, id: string, options?: RequestOptions): Promise<Address> =>
        this.request<Address>('GET', `/companies/${companyId}/addresses/${id}`, options),

      /** Address fields edit the entry in place, so send only what changes. */
      update: (
        companyId: string,
        id: string,
        params: CompanyAddressParams,
        options?: RequestOptions,
      ): Promise<Address> =>
        this.request<Address>('PATCH', `/companies/${companyId}/addresses/${id}`, {
          ...options,
          body: params,
        }),

      delete: (companyId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/companies/${companyId}/addresses/${id}`, options),
    },

    /**
     * The people with standing over the node (and, through it, its subtree).
     * `create` takes an email and does the right thing: a membership for an
     * existing customer, a CompanyInvitation otherwise — check the returned
     * id prefix (`cmem_` vs `cinv_`).
     */
    memberships: {
      list: (
        companyId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CompanyMembership>> =>
        this.request<PaginatedResponse<CompanyMembership>>(
          'GET',
          `/companies/${companyId}/memberships`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      create: (
        companyId: string,
        params: CompanyMembershipCreateParams,
        options?: RequestOptions,
      ): Promise<CompanyMembership | CompanyInvitation> =>
        this.request<CompanyMembership | CompanyInvitation>(
          'POST',
          `/companies/${companyId}/memberships`,
          { ...options, body: params },
        ),

      get: (companyId: string, id: string, options?: RequestOptions): Promise<CompanyMembership> =>
        this.request<CompanyMembership>(
          'GET',
          `/companies/${companyId}/memberships/${id}`,
          options,
        ),

      /** Withdraws the member's standing. The customer account is untouched. */
      delete: (companyId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/companies/${companyId}/memberships/${id}`, options),
    },

    invitations: {
      list: (
        companyId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CompanyInvitation>> =>
        this.request<PaginatedResponse<CompanyInvitation>>(
          'GET',
          `/companies/${companyId}/invitations`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (companyId: string, id: string, options?: RequestOptions): Promise<CompanyInvitation> =>
        this.request<CompanyInvitation>(
          'GET',
          `/companies/${companyId}/invitations/${id}`,
          options,
        ),

      /** Revokes a pending invitation; its token then stops resolving. */
      delete: (companyId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/companies/${companyId}/invitations/${id}`, options),
    },

    /**
     * The business's own tax registrations, one per kind. A company
     * registration takes precedence over the buyer's own when a sale is for
     * that business, because the invoice is addressed to the entity rather
     * than the person who placed the order.
     */
    taxIdentifiers: {
      list: (
        companyId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<TaxIdentifier>> =>
        this.request<PaginatedResponse<TaxIdentifier>>(
          'GET',
          `/companies/${companyId}/tax_identifiers`,
          {
            ...options,
            params: params ? transformListParams(params) : undefined,
          },
        ),

      get: (companyId: string, id: string, options?: RequestOptions): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>(
          'GET',
          `/companies/${companyId}/tax_identifiers/${id}`,
          options,
        ),

      create: (
        companyId: string,
        params: TaxIdentifierParams,
        options?: RequestOptions,
      ): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>('POST', `/companies/${companyId}/tax_identifiers`, {
          ...options,
          body: params,
        }),

      update: (
        companyId: string,
        id: string,
        params: TaxIdentifierParams,
        options?: RequestOptions,
      ): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>('PATCH', `/companies/${companyId}/tax_identifiers/${id}`, {
          ...options,
          body: params,
        }),

      delete: (companyId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/companies/${companyId}/tax_identifiers/${id}`, options),

      /**
       * Asks the registry again. A registry answers only "valid now", so a
       * number verified last year may have been deregistered since. Returns
       * `202` with the check queued.
       */
      validate: (companyId: string, id: string, options?: RequestOptions): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>(
          'POST',
          `/companies/${companyId}/tax_identifiers/${id}/validate`,
          options,
        ),
    },

    /**
     * Exemption evidence. Certificates start `pending` and exempt nothing
     * until verified; `active` — not `status` — answers whether one exempts a
     * sale, since a verified certificate stops counting once its expiry date
     * passes.
     *
     * Upload the document via `directUploads.create()` first and pass the
     * returned `signed_id` as `document`. To read it back, fetch
     * `document_url` with the `Authorization` header and drive the browser
     * download from a Blob — the bytes are streamed through the API rather
     * than served from storage, so a top-level navigation carrying no JWT
     * will not work.
     */
    taxExemptionCertificates: {
      list: (
        companyId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<TaxExemptionCertificate>> =>
        this.request<PaginatedResponse<TaxExemptionCertificate>>(
          'GET',
          `/companies/${companyId}/tax_exemption_certificates`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (
        companyId: string,
        id: string,
        params?: { expand?: string[] },
        options?: RequestOptions,
      ): Promise<TaxExemptionCertificate> =>
        this.request<TaxExemptionCertificate>(
          'GET',
          `/companies/${companyId}/tax_exemption_certificates/${id}`,
          { ...options, params: getParams(params) },
        ),

      create: (
        companyId: string,
        params: TaxExemptionCertificateParams,
        options?: RequestOptions,
      ): Promise<TaxExemptionCertificate> =>
        this.request<TaxExemptionCertificate>(
          'POST',
          `/companies/${companyId}/tax_exemption_certificates`,
          { ...options, body: params },
        ),

      update: (
        companyId: string,
        id: string,
        params: TaxExemptionCertificateParams,
        options?: RequestOptions,
      ): Promise<TaxExemptionCertificate> =>
        this.request<TaxExemptionCertificate>(
          'PATCH',
          `/companies/${companyId}/tax_exemption_certificates/${id}`,
          { ...options, body: params },
        ),

      /**
       * Accepts the certificate, which is what makes it exempt sales. Only a
       * pending certificate can be accepted. An installation that checks
       * numbers against a registry, or requires a second approval, can refuse
       * here — the refusal arrives as a validation error.
       */
      verify: (
        companyId: string,
        id: string,
        options?: RequestOptions,
      ): Promise<TaxExemptionCertificate> =>
        this.request<TaxExemptionCertificate>(
          'PATCH',
          `/companies/${companyId}/tax_exemption_certificates/${id}/verify`,
          options,
        ),

      /**
       * Withdraws accepted evidence. A verified certificate cannot be deleted
       * — how a sale was taxed has to stay explainable — so this is the way
       * out.
       */
      revoke: (
        companyId: string,
        id: string,
        options?: RequestOptions,
      ): Promise<TaxExemptionCertificate> =>
        this.request<TaxExemptionCertificate>(
          'PATCH',
          `/companies/${companyId}/tax_exemption_certificates/${id}/revoke`,
          options,
        ),

      /** Only a certificate still awaiting a decision can be deleted. */
      delete: (companyId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>(
          'DELETE',
          `/companies/${companyId}/tax_exemption_certificates/${id}`,
          options,
        ),
    },
  }

  // ============================================
  // Catalogs (assortment + optional price list)
  // ============================================

  /**
   * Catalogs narrow what an audience sees and, through an attached price
   * list, what they pay. Audiences are assignments: a channel, a customer
   * group, a market, or a company node (covering its subtree).
   */
  readonly catalogs = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Catalog>> =>
      this.request<PaginatedResponse<Catalog>>('GET', '/catalogs', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Catalog> =>
      this.request<Catalog>('GET', `/catalogs/${id}`, { ...options, params: getParams(params) }),

    create: (params: CatalogParams, options?: RequestOptions): Promise<Catalog> =>
      this.request<Catalog>('POST', '/catalogs', { ...options, body: params }),

    update: (id: string, params: CatalogParams, options?: RequestOptions): Promise<Catalog> =>
      this.request<Catalog>('PATCH', `/catalogs/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/catalogs/${id}`, options),

    /**
     * The catalog's assortment. Rows carry `catalog_price` when asked for
     * with `expand: ['catalog_price']` — what a buyer on this agreement pays
     * and where the amount comes from.
     */
    products: this.productMembership<CatalogProduct>('/catalogs'),

    /**
     * Puts the agreement into effect: its audience starts seeing its
     * assortment and paying its prices. Refused for a catalog nobody is
     * assigned to, which would reach no buyer.
     */
    activate: (id: string, options?: RequestOptions): Promise<Catalog> =>
      this.request<Catalog>('PATCH', `/catalogs/${id}/activate`, options),

    /** Takes it out of effect; everything it holds survives untouched. */
    deactivate: (id: string, options?: RequestOptions): Promise<Catalog> =>
      this.request<Catalog>('PATCH', `/catalogs/${id}/deactivate`, options),

    /**
     * Copies the attached price list's products into the assortment.
     * Explicit by design — an empty assortment is a pricing-only overlay
     * (nothing hidden), so making a catalog restrictive is deliberate.
     */
    importProducts: (id: string, options?: RequestOptions): Promise<{ added_count: number }> =>
      this.request<{ added_count: number }>('POST', `/catalogs/${id}/import_products`, options),

    /** Shows the catalog to an audience. */
    assign: (
      id: string,
      params: CatalogAssignParams,
      options?: RequestOptions,
    ): Promise<CatalogAssignment> =>
      this.request<CatalogAssignment>('POST', `/catalogs/${id}/assign`, {
        ...options,
        body: params,
      }),

    /**
     * Per-variant quantity terms. The catalog-wide default is a pair of
     * fields on the catalog itself, so this is strictly the overrides.
     */
    quantityRules: {
      list: (
        catalogId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CatalogQuantityRule>> =>
        this.request<PaginatedResponse<CatalogQuantityRule>>(
          'GET',
          `/catalogs/${catalogId}/quantity_rules`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      create: (
        catalogId: string,
        params: CatalogQuantityRuleParams,
        options?: RequestOptions,
      ): Promise<CatalogQuantityRule> =>
        this.request<CatalogQuantityRule>('POST', `/catalogs/${catalogId}/quantity_rules`, {
          ...options,
          body: params,
        }),

      update: (
        catalogId: string,
        id: string,
        params: CatalogQuantityRuleParams,
        options?: RequestOptions,
      ): Promise<CatalogQuantityRule> =>
        this.request<CatalogQuantityRule>('PATCH', `/catalogs/${catalogId}/quantity_rules/${id}`, {
          ...options,
          body: params,
        }),

      delete: (catalogId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/catalogs/${catalogId}/quantity_rules/${id}`, options),
    },

    /**
     * Per-product quantity terms — the grain the agreement editor states
     * them at, over rows the database keeps per variant.
     */
    productTerms: {
      list: (
        catalogId: string,
        options?: RequestOptions,
      ): Promise<{ data: CatalogProductTerm[] }> =>
        this.request<{ data: CatalogProductTerm[] }>(
          'GET',
          `/catalogs/${catalogId}/product_terms`,
          options,
        ),

      /**
       * Writes the whole set in one request. A product whose pair is both
       * null has its terms cleared; a product not yet in the assortment is
       * added, since a term with nothing to apply to is not a reachable
       * state.
       */
      upsert: (
        catalogId: string,
        params: CatalogProductTermsParams,
        options?: RequestOptions,
      ): Promise<{ data: CatalogProductTerm[] }> =>
        this.request<{ data: CatalogProductTerm[] }>(
          'PUT',
          `/catalogs/${catalogId}/product_terms`,
          { ...options, body: params },
        ),
    },

    /** The order minimum in each currency this agreement states one for. */
    orderMinimums: {
      list: (
        catalogId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<CatalogOrderMinimum>> =>
        this.request<PaginatedResponse<CatalogOrderMinimum>>(
          'GET',
          `/catalogs/${catalogId}/order_minimums`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      create: (
        catalogId: string,
        params: CatalogOrderMinimumParams,
        options?: RequestOptions,
      ): Promise<CatalogOrderMinimum> =>
        this.request<CatalogOrderMinimum>('POST', `/catalogs/${catalogId}/order_minimums`, {
          ...options,
          body: params,
        }),

      update: (
        catalogId: string,
        id: string,
        params: CatalogOrderMinimumParams,
        options?: RequestOptions,
      ): Promise<CatalogOrderMinimum> =>
        this.request<CatalogOrderMinimum>('PATCH', `/catalogs/${catalogId}/order_minimums/${id}`, {
          ...options,
          body: params,
        }),

      delete: (catalogId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/catalogs/${catalogId}/order_minimums/${id}`, options),
    },
  }

  readonly catalogAssignments = {
    /** Withdraws the catalog from an audience. */
    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/catalog_assignments/${id}`, options),
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
  // Imports (CSV: products, customers, …)
  // ============================================

  /**
   * Queues asynchronous CSV imports and drives the mapping flow. Upload the
   * file via `directUploads.create()` first, then `create()` the import with
   * the returned `signed_id` — the response is in the `mapping` state and
   * carries `schema_fields`, `csv_headers`, a `sample_row` and the
   * auto-assigned `mappings`. Adjust mappings if needed and call
   * `completeMapping(id)` to start processing, then poll `get(id)` while
   * `status` is `completed_mapping`/`processing` (`completed`/`failed` are
   * terminal). Failed rows are listed via `rows.list(id, { status_eq:
   * 'failed' })` (flat Ransack predicates, wrapped into `q[...]` by
   * `transformListParams`) and can be re-processed with `retryFailedRows(id)`.
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
     * Everything the store holds about this customer, for answering a GDPR
     * subject access request that arrived by email.
     */
    export: (id: string, options?: RequestOptions): Promise<Record<string, unknown>> =>
      this.request<Record<string, unknown>>('GET', `/customers/${id}/export`, options),

    /**
     * Erases the customer's personal data, keeping the financial record.
     * Irreversible.
     */
    anonymize: (id: string, options?: RequestOptions): Promise<Customer> =>
      this.request<Customer>('POST', `/customers/${id}/anonymize`, options),

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

    /**
     * The customer's own tax registrations — the durable profile value, as
     * opposed to the override entered during a single checkout. A company's
     * registration outranks these when the buyer purchases for a business.
     */
    taxIdentifiers: {
      list: (
        customerId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<TaxIdentifier>> =>
        this.request<PaginatedResponse<TaxIdentifier>>(
          'GET',
          `/customers/${customerId}/tax_identifiers`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (customerId: string, id: string, options?: RequestOptions): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>(
          'GET',
          `/customers/${customerId}/tax_identifiers/${id}`,
          options,
        ),

      create: (
        customerId: string,
        params: TaxIdentifierParams,
        options?: RequestOptions,
      ): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>('POST', `/customers/${customerId}/tax_identifiers`, {
          ...options,
          body: params,
        }),

      update: (
        customerId: string,
        id: string,
        params: TaxIdentifierParams,
        options?: RequestOptions,
      ): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>('PATCH', `/customers/${customerId}/tax_identifiers/${id}`, {
          ...options,
          body: params,
        }),

      delete: (customerId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/customers/${customerId}/tax_identifiers/${id}`, options),

      /**
       * Re-asks the registry. Manual because a registry answers only "valid
       * now" — a number verified last year may have been deregistered since.
       */
      validate: (
        customerId: string,
        id: string,
        options?: RequestOptions,
      ): Promise<TaxIdentifier> =>
        this.request<TaxIdentifier>(
          'POST',
          `/customers/${customerId}/tax_identifiers/${id}/validate`,
          options,
        ),
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

  /**
   * The media library — every file in the store, whether or not it has been
   * placed on a product. Files are put ON a product through
   * `products.media.create` with a `source_media_id`; this is where they are
   * uploaded, browsed and deleted.
   */
  readonly media = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Media>> =>
      this.request<PaginatedResponse<Media>>('GET', '/media', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<Media> =>
      this.request<Media>('GET', `/media/${id}`, options),

    /** Upload a file before deciding where it goes. */
    create: (params: MediaLibraryCreateParams, options?: RequestOptions): Promise<Media> =>
      this.request<Media>('POST', '/media', { ...options, body: params }),

    update: (id: string, params: MediaUpdateParams, options?: RequestOptions): Promise<Media> =>
      this.request<Media>('PATCH', `/media/${id}`, { ...options, body: params }),

    /**
     * Deletes the file. A file still in use is refused (422 with its usage)
     * unless `detach` is set, which removes it from every place using it —
     * product galleries, category and collection images — in one pass.
     * Descriptions embedding it keep a URL that no longer resolves.
     */
    delete: (id: string, params?: { detach?: boolean }, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/media/${id}`, {
        ...options,
        params: params?.detach ? { detach: 'true' } : undefined,
      }),

    /**
     * Where this file is in use. Worth showing before a delete: reuse shares
     * the file, so removing one placement can leave others pointing at it.
     */
    usage: (id: string, options?: RequestOptions): Promise<{ data: MediaUsageReference[] }> =>
      this.request<{ data: MediaUsageReference[] }>('GET', `/media/${id}/usage`, options),
  }

  readonly categories = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Category>> =>
      this.request<PaginatedResponse<Category>>('GET', '/categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Category> =>
      this.request<Category>('GET', `/categories/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: CategoryCreateParams, options?: RequestOptions): Promise<Category> =>
      this.request<Category>('POST', '/categories', { ...options, body: params }),

    update: (
      id: string,
      params: CategoryUpdateParams,
      options?: RequestOptions,
    ): Promise<Category> =>
      this.request<Category>('PATCH', `/categories/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/categories/${id}`, options),

    /** Move a category to a new parent and/or index within the tree. */
    reposition: (
      id: string,
      params: CategoryRepositionParams,
      options?: RequestOptions,
    ): Promise<Category> =>
      this.request<Category>('PATCH', `/categories/${id}/reposition`, { ...options, body: params }),

    /** Manual product membership + ordering within a category. */
    products: this.positionedProductMembership('/categories'),

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Category']),

    translations: this.parentScopedTranslations('/categories'),
  }

  // ============================================
  // Collections
  // ============================================

  readonly collections = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<Collection>> =>
      this.request<PaginatedResponse<Collection>>('GET', '/collections', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<Collection> =>
      this.request<Collection>('GET', `/collections/${id}`, {
        ...options,
        params: getParams(params),
      }),

    create: (params: CollectionCreateParams, options?: RequestOptions): Promise<Collection> =>
      this.request<Collection>('POST', '/collections', { ...options, body: params }),

    /**
     * Collections are a flat list, so reordering one is a plain `position`
     * update — `acts_as_list` shifts its siblings on save and there is no
     * separate reposition action.
     */
    update: (
      id: string,
      params: CollectionUpdateParams,
      options?: RequestOptions,
    ): Promise<Collection> =>
      this.request<Collection>('PATCH', `/collections/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/collections/${id}`, options),

    /**
     * Manual product membership + ordering within a collection. `add`, `remove`
     * and `reposition` are rejected on an automatic collection, whose members
     * are materialized from its rules; `list` works on both.
     */
    products: this.positionedProductMembership('/collections'),

    customFields: this.parentScopedCustomFields(CUSTOM_FIELD_OWNER_PATHS['Spree::Collection']),

    translations: this.parentScopedTranslations('/collections'),
  }

  /**
   * Collection rule kinds. Read-only discovery — rules themselves are written
   * through the owning collection's `rules` array on update. The list is
   * registry-driven server-side, so plugin-registered rules appear here too.
   */
  readonly collectionRules = {
    types: (options?: RequestOptions): Promise<{ data: ResourceTypeDefinition[] }> =>
      this.request<{ data: ResourceTypeDefinition[] }>('GET', '/collection_rules/types', options),
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

    create: (params: ProductTypeCreateParams, options?: RequestOptions): Promise<ProductType> =>
      this.request<ProductType>('POST', '/product_types', { ...options, body: params }),

    update: (
      id: string,
      params: ProductTypeUpdateParams,
      options?: RequestOptions,
    ): Promise<ProductType> =>
      this.request<ProductType>('PATCH', `/product_types/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/product_types/${id}`, options),

    /**
     * Backfills the type's option types and categories onto the products that
     * already carry it. Additive — nothing is removed. Runs in the background;
     * the response reports how many products are affected.
     */
    applyToProducts: (
      id: string,
      options?: RequestOptions,
    ): Promise<ProductTypeApplyToProductsResponse> =>
      this.request<ProductTypeApplyToProductsResponse>(
        'POST',
        `/product_types/${id}/apply_to_products`,
        options,
      ),
  }

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
  // Policies — the store's legal documents
  // ============================================

  /**
   * The store's own policy documents: terms of service, privacy, returns,
   * shipping, and anything else the merchant publishes.
   *
   * Addressable by slug as well as prefixed id. A marketplace seller's
   * policies are theirs and live on the seller API, not here.
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

  // ============================================
  // Reasons — why a return, claim or refund happened
  // ============================================

  /** Why a customer sent something back. Shared by returns and exchanges. */
  readonly returnReasons = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<ReturnReason>> =>
      this.request<PaginatedResponse<ReturnReason>>('GET', '/return_reasons', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<ReturnReason> =>
      this.request<ReturnReason>('GET', `/return_reasons/${id}`, options),

    create: (params: ReasonCreateParams, options?: RequestOptions): Promise<ReturnReason> =>
      this.request<ReturnReason>('POST', '/return_reasons', { ...options, body: params }),

    update: (
      id: string,
      params: ReasonUpdateParams,
      options?: RequestOptions,
    ): Promise<ReturnReason> =>
      this.request<ReturnReason>('PATCH', `/return_reasons/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/return_reasons/${id}`, options),
  }

  /** What went wrong with a delivery — damaged, missing, wrong item. */
  readonly claimReasons = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<ClaimReason>> =>
      this.request<PaginatedResponse<ClaimReason>>('GET', '/claim_reasons', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<ClaimReason> =>
      this.request<ClaimReason>('GET', `/claim_reasons/${id}`, options),

    create: (params: ReasonCreateParams, options?: RequestOptions): Promise<ClaimReason> =>
      this.request<ClaimReason>('POST', '/claim_reasons', { ...options, body: params }),

    update: (
      id: string,
      params: ReasonUpdateParams,
      options?: RequestOptions,
    ): Promise<ClaimReason> =>
      this.request<ClaimReason>('PATCH', `/claim_reasons/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/claim_reasons/${id}`, options),
  }

  /** Why an order was called off before it shipped. */
  readonly orderCancellationReasons = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<OrderCancellationReason>> =>
      this.request<PaginatedResponse<OrderCancellationReason>>(
        'GET',
        '/order_cancellation_reasons',
        {
          ...options,
          params: params ? transformListParams(params) : undefined,
        },
      ),

    get: (id: string, options?: RequestOptions): Promise<OrderCancellationReason> =>
      this.request<OrderCancellationReason>('GET', `/order_cancellation_reasons/${id}`, options),

    create: (
      params: ReasonCreateParams,
      options?: RequestOptions,
    ): Promise<OrderCancellationReason> =>
      this.request<OrderCancellationReason>('POST', '/order_cancellation_reasons', {
        ...options,
        body: params,
      }),

    update: (
      id: string,
      params: ReasonUpdateParams,
      options?: RequestOptions,
    ): Promise<OrderCancellationReason> =>
      this.request<OrderCancellationReason>('PATCH', `/order_cancellation_reasons/${id}`, {
        ...options,
        body: params,
      }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/order_cancellation_reasons/${id}`, options),
  }

  /**
   * Why money went back. Some rows are seeded and immutable: core looks
   * them up by name, so `can_be_deleted` is false and renaming is refused.
   */
  readonly refundReasons = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<RefundReason>> =>
      this.request<PaginatedResponse<RefundReason>>('GET', '/refund_reasons', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, options?: RequestOptions): Promise<RefundReason> =>
      this.request<RefundReason>('GET', `/refund_reasons/${id}`, options),

    create: (params: ReasonCreateParams, options?: RequestOptions): Promise<RefundReason> =>
      this.request<RefundReason>('POST', '/refund_reasons', { ...options, body: params }),

    update: (
      id: string,
      params: ReasonUpdateParams,
      options?: RequestOptions,
    ): Promise<RefundReason> =>
      this.request<RefundReason>('PATCH', `/refund_reasons/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/refund_reasons/${id}`, options),
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

    /**
     * Order routing rules — the channel's prioritized list of signals the
     * `Rules` routing strategy walks when choosing fulfillment locations.
     * Rule kinds are discovered via `client.orderRoutingRules.types()`.
     */
    orderRoutingRules: {
      list: (
        channelId: string,
        params?: ListParams & Record<string, unknown>,
        options?: RequestOptions,
      ): Promise<PaginatedResponse<OrderRoutingRule>> =>
        this.request<PaginatedResponse<OrderRoutingRule>>(
          'GET',
          `/channels/${channelId}/order_routing_rules`,
          { ...options, params: params ? transformListParams(params) : undefined },
        ),

      get: (channelId: string, id: string, options?: RequestOptions): Promise<OrderRoutingRule> =>
        this.request<OrderRoutingRule>(
          'GET',
          `/channels/${channelId}/order_routing_rules/${id}`,
          options,
        ),

      create: (
        channelId: string,
        params: OrderRoutingRuleCreateParams,
        options?: RequestOptions,
      ): Promise<OrderRoutingRule> =>
        this.request<OrderRoutingRule>('POST', `/channels/${channelId}/order_routing_rules`, {
          ...options,
          body: params,
        }),

      update: (
        channelId: string,
        id: string,
        params: OrderRoutingRuleUpdateParams,
        options?: RequestOptions,
      ): Promise<OrderRoutingRule> =>
        this.request<OrderRoutingRule>(
          'PATCH',
          `/channels/${channelId}/order_routing_rules/${id}`,
          { ...options, body: params },
        ),

      delete: (channelId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/channels/${channelId}/order_routing_rules/${id}`, options),
    },
  }

  readonly orderRoutingRules = {
    types: (options?: RequestOptions): Promise<{ data: ResourceTypeDefinition[] }> =>
      this.request<{ data: ResourceTypeDefinition[] }>(
        'GET',
        '/order_routing_rules/types',
        options,
      ),
  }

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
  // Stock Levels
  // ============================================

  readonly stockLevels = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StockLevel>> =>
      this.request<PaginatedResponse<StockLevel>>('GET', '/stock_levels', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StockLevel> =>
      this.request<StockLevel>('GET', `/stock_levels/${id}`, {
        ...options,
        params: getParams(params),
      }),

    update: (
      id: string,
      params: StockLevelUpdateParams,
      options?: RequestOptions,
    ): Promise<StockLevel> =>
      this.request<StockLevel>('PATCH', `/stock_levels/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/stock_levels/${id}`, options),

    /**
     * Sets stock levels for many (variant, location) pairs at once — what a
     * warehouse feed posts on a schedule. Rows name their variant and location
     * either by Spree id or by an external reference, so a feed can use the
     * keys it already holds.
     *
     * Each change is recorded as a stock movement, so the history stays
     * intact. Response is `{ stock_level_count }`.
     */
    bulkUpsert: (
      params: { stock_levels: StockLevelBulkUpsertRow[] },
      options?: RequestOptions,
    ): Promise<{ stock_level_count: number }> =>
      this.request('POST', '/stock_levels/bulk_upsert', { ...options, body: params }),
  }

  // ============================================
  // Stock Movements
  // ============================================

  // Read-only: a movement records something that already happened to stock.
  // Reversing one means writing its counterpart through the resource that
  // caused it.
  readonly stockMovements = {
    list: (
      params?: ListParams & Record<string, unknown>,
      options?: RequestOptions,
    ): Promise<PaginatedResponse<StockMovement>> =>
      this.request<PaginatedResponse<StockMovement>>('GET', '/stock_movements', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (
      id: string,
      params?: { expand?: string[] },
      options?: RequestOptions,
    ): Promise<StockMovement> =>
      this.request<StockMovement>('GET', `/stock_movements/${id}`, {
        ...options,
        params: getParams(params),
      }),
  }

  // ============================================
  // Stock Transfers
  // ============================================

  /**
   * Inventory movement between stock locations, or external → location for
   * receives. Pass `source_location_id` for transfers; omit it to record a
   * seller receive (external stock arriving at the destination).
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
  // Roles (staff roles + catalog permissions)
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

    create: (params: RoleCreateParams, options?: RequestOptions): Promise<Role> =>
      this.request<Role>('POST', '/roles', { ...options, body: params }),

    update: (id: string, params: RoleUpdateParams, options?: RequestOptions): Promise<Role> =>
      this.request<Role>('PATCH', `/roles/${id}`, { ...options, body: params }),

    delete: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('DELETE', `/roles/${id}`, options),
  }

  // ============================================
  // Permissions (the grant vocabulary — read-only catalog)
  // ============================================

  readonly permissions = {
    list: (options?: RequestOptions): Promise<{ data: Permission[]; meta: { count: number } }> =>
      this.request<{ data: Permission[]; meta: { count: number } }>('GET', '/permissions', options),
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
