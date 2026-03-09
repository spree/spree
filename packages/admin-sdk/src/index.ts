// Main client
export { createAdminClient } from './client';
export type { AdminClientConfig, Client } from './client';

// Admin client class (for advanced use / subclassing)
export { AdminClient } from './admin-client';

// Request infrastructure (re-export from sdk-core)
export { SpreeError } from '@spree/sdk-core';
export type { RequestOptions, RetryConfig } from '@spree/sdk-core';

// All types
export * from './types';
