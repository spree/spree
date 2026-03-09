// Main client
export { createClient } from './client';
export type { ClientConfig, Client } from './client';

// Store client class (for advanced use / subclassing)
export { StoreClient } from './store-client';

// Request infrastructure (re-export from sdk-core)
export { SpreeError } from '@spree/sdk-core';
export type { RequestOptions, RetryConfig } from '@spree/sdk-core';

// All types
export * from './types';
