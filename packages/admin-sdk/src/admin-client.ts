import type { RequestFn, RequestOptions, AuthTokens, LoginCredentials } from '@spree/sdk-core';
import { transformListParams, getParams } from '@spree/sdk-core';
import type { PaginatedResponse, ListParams } from '@spree/sdk-core';
import type { Store, Product, Order, Asset, Taxon, TaxCategory, ShippingCategory } from './types';
import type {
  StoreUpdateParams,
  ProductUpdateParams,
  OrderUpdateParams,
  AssetCreateParams,
  AssetUpdateParams,
  LineItemCreateParams,
  LineItemUpdateParams,
  AdjustmentCreateParams,
  ShipmentUpdateParams,
  DirectUploadCreateParams,
} from './params';

export class AdminClient {
  /** @internal */
  readonly request: RequestFn;

  constructor(request: RequestFn) {
    this.request = request;
  }

  // ============================================
  // Authentication
  // ============================================

  readonly auth = {
    login: (credentials: LoginCredentials, options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/login', { ...options, body: credentials }),

    refresh: (options?: RequestOptions): Promise<AuthTokens> =>
      this.request<AuthTokens>('POST', '/auth/refresh', options),
  };

  // ============================================
  // Store Settings
  // ============================================

  readonly store = {
    get: (options?: RequestOptions): Promise<Store> =>
      this.request<Store>('GET', '/store', options),

    update: (params: StoreUpdateParams, options?: RequestOptions): Promise<Store> =>
      this.request<Store>('PATCH', '/store', { ...options, body: params }),
  };

  // ============================================
  // Products
  // ============================================

  readonly products = {
    list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<Product>> =>
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

    assets: {
      list: (productId: string, params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<Asset>> =>
        this.request<PaginatedResponse<Asset>>('GET', `/products/${productId}/assets`, {
          ...options,
          params: params ? transformListParams(params) : undefined,
        }),

      create: (productId: string, params: AssetCreateParams, options?: RequestOptions): Promise<Asset> =>
        this.request<Asset>('POST', `/products/${productId}/assets`, { ...options, body: params }),

      update: (productId: string, id: string, params: AssetUpdateParams, options?: RequestOptions): Promise<Asset> =>
        this.request<Asset>('PATCH', `/products/${productId}/assets/${id}`, { ...options, body: params }),

      delete: (productId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/products/${productId}/assets/${id}`, options),
    },
  };

  // ============================================
  // Orders
  // ============================================

  readonly orders = {
    list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<Order>> =>
      this.request<PaginatedResponse<Order>>('GET', '/orders', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),

    get: (id: string, params?: { expand?: string[] }, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('GET', `/orders/${id}`, {
        ...options,
        params: getParams(params),
      }),

    update: (id: string, params: OrderUpdateParams | Record<string, unknown>, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}`, { ...options, body: params }),

    cancel: (id: string, options?: RequestOptions): Promise<Order> =>
      this.request<Order>('PATCH', `/orders/${id}/cancel`, options),

    resendConfirmation: (id: string, options?: RequestOptions): Promise<void> =>
      this.request<void>('POST', `/orders/${id}/resend_confirmation`, options),

    lineItems: {
      create: (orderId: string, params: LineItemCreateParams, options?: RequestOptions): Promise<unknown> =>
        this.request('POST', `/orders/${orderId}/line_items`, { ...options, body: params }),

      update: (orderId: string, id: string, params: LineItemUpdateParams, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/line_items/${id}`, { ...options, body: params }),

      delete: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/line_items/${id}`, options),
    },

    shipments: {
      update: (orderId: string, id: string, params: ShipmentUpdateParams, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/shipments/${id}`, { ...options, body: params }),

      ship: (orderId: string, id: string, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/shipments/${id}/ship`, options),

      cancel: (orderId: string, id: string, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/shipments/${id}/cancel`, options),
    },

    payments: {
      capture: (orderId: string, id: string, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/payments/${id}/capture`, options),

      void: (orderId: string, id: string, options?: RequestOptions): Promise<unknown> =>
        this.request('PATCH', `/orders/${orderId}/payments/${id}/void`, options),
    },

    adjustments: {
      create: (orderId: string, params: AdjustmentCreateParams, options?: RequestOptions): Promise<unknown> =>
        this.request('POST', `/orders/${orderId}/adjustments`, { ...options, body: params }),

      delete: (orderId: string, id: string, options?: RequestOptions): Promise<void> =>
        this.request<void>('DELETE', `/orders/${orderId}/adjustments/${id}`, options),
    },
  };

  // ============================================
  // Taxons
  // ============================================

  readonly taxons = {
    list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<Taxon>> =>
      this.request<PaginatedResponse<Taxon>>('GET', '/taxons', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),
  };

  // ============================================
  // Tax Categories
  // ============================================

  readonly taxCategories = {
    list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<TaxCategory>> =>
      this.request<PaginatedResponse<TaxCategory>>('GET', '/tax_categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),
  };

  // ============================================
  // Shipping Categories
  // ============================================

  readonly shippingCategories = {
    list: (params?: ListParams & Record<string, unknown>, options?: RequestOptions): Promise<PaginatedResponse<ShippingCategory>> =>
      this.request<PaginatedResponse<ShippingCategory>>('GET', '/shipping_categories', {
        ...options,
        params: params ? transformListParams(params) : undefined,
      }),
  };

  // ============================================
  // Direct Uploads (Active Storage)
  // ============================================

  readonly directUploads = {
    create: (params: DirectUploadCreateParams, options?: RequestOptions): Promise<{
      direct_upload: { url: string; headers: Record<string, string> };
      signed_id: string;
    }> =>
      this.request('POST', '/direct_uploads', { ...options, body: params }),
  };
}

// Re-export for type convenience
export type { PaginatedResponse, ListParams, RequestOptions };
