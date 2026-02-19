import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('taxonomies', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns paginated taxonomies', async () => {
      const result = await client.store.taxonomies.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Categories');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('get', () => {
    it('returns a taxonomy by ID', async () => {
      const result = await client.store.taxonomies.get('tax_1');
      expect(result.name).toBe(fixtures.taxonomy.name);
    });
  });
});
