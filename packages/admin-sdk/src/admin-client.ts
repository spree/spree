import type { RequestFn, RequestOptions } from '@spree/sdk-core';
import { transformListParams, getParams } from '@spree/sdk-core';
import type { PaginatedResponse, ListParams } from '@spree/sdk-core';

// Placeholder: Admin client will be populated with admin endpoints
// as they are added to the API.
export class AdminClient {
  /** @internal */
  readonly request: RequestFn;

  constructor(request: RequestFn) {
    this.request = request;

    // Suppress unused warnings until endpoints are added
    void transformListParams;
    void getParams;
  }

  // Example structure for future admin endpoints:
  // readonly products = { ... };
  // readonly orders = { ... };
}

// Re-export for type convenience
export type { PaginatedResponse, ListParams, RequestOptions };
