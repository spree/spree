import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('taxons', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns paginated taxons', async () => {
      const result = await client.store.taxons.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Clothing');
      expect(result.meta.page).toBe(1);
    });

    it('passes query parameters', async () => {
      const result = await client.store.taxons.list({
        taxonomy_id_eq: 'tax_1',
      });
      expect(result.data).toBeDefined();
    });
  });

  describe('get', () => {
    it('returns a taxon by ID', async () => {
      const result = await client.store.taxons.get('taxon_1');
      expect(result.name).toBe(fixtures.taxon.name);
    });

});

  describe('products', () => {
    it('lists products in a taxon', async () => {
      const result = await client.store.taxons.products.list('taxon_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Test Product');
      expect(result.meta.page).toBe(1);
    });
  });
});
