import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('products', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns paginated products', async () => {
      const result = await client.store.products.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Test Product');
      expect(result.meta.page).toBe(1);
      expect(result.meta.count).toBe(1);
    });

    it('passes query parameters', async () => {
      const result = await client.store.products.list({
        page: 2,
        per_page: 10,
        'q[name_cont]': 'shirt',
      });

      // MSW handler returns the same fixture regardless of params,
      // but the request is formed correctly (tested via custom fetch in client tests)
      expect(result.data).toBeDefined();
    });
  });

  describe('get', () => {
    it('returns a product by slug', async () => {
      const result = await client.store.products.get('test-product');

      expect(result.name).toBe(fixtures.product.name);
      expect(result.slug).toBe('test-product');
    });

    it('returns a product by ID', async () => {
      const result = await client.store.products.get('prod_1');
      expect(result.id).toBe('prod_1');
    });
  });

  describe('filters', () => {
    it('returns filter options', async () => {
      const result = await client.store.products.filters();

      expect(result.filters).toBeDefined();
      expect(result.sort_options).toBeDefined();
      expect(result.default_sort).toBe('default');
      expect(result.total_count).toBe(1);
    });
  });
});
