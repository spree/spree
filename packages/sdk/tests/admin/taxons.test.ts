import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / taxons', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  describe('list', () => {
    it('returns paginated taxons', async () => {
      const result = await client.admin.taxons.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('Clothing');
      expect(result.meta.page).toBe(1);
    });
  });

  describe('get', () => {
    it('returns a taxon by ID', async () => {
      const result = await client.admin.taxons.get('txon_1');

      expect(result.name).toBe(adminFixtures.taxon.name);
      expect(result.permalink).toBe('categories/clothing');
    });
  });
});
