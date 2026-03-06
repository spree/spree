import { createClient } from '../src';

export const TEST_BASE_URL = 'https://demo.spreecommerce.org';
export const TEST_API_KEY = 'test-publishable-key';
export const TEST_SECRET_KEY = 'spree_sk_test_admin';

export function createTestClient() {
  return createClient({
    baseUrl: TEST_BASE_URL,
    publishableKey: TEST_API_KEY,
  });
}

export function createAdminTestClient() {
  return createSpreeClient({
    baseUrl: TEST_BASE_URL,
    secretKey: TEST_SECRET_KEY,
  });
}
