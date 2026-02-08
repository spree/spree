import { createSpreeClient } from '../src';

export const TEST_BASE_URL = 'https://demo.spreecommerce.org';
export const TEST_API_KEY = 'test-publishable-key';

export function createTestClient() {
  return createSpreeClient({
    baseUrl: TEST_BASE_URL,
    apiKey: TEST_API_KEY,
  });
}
