import { describe, it, expect, beforeAll } from 'vitest';
import { createAdminTestClient } from '../helpers';
import { adminFixtures } from '../mocks/admin-handlers';
import type { SpreeClient } from '../../src';

describe('admin / optionTypes', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createAdminTestClient(); });

  describe('list', () => {
    it('returns paginated option types', async () => {
      const result = await client.admin.optionTypes.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('color');
      expect(result.meta.page).toBe(1);
      expect(result.meta.count).toBe(1);
    });
  });

  describe('create', () => {
    it('creates an option type', async () => {
      const result = await client.admin.optionTypes.create({
        name: 'color',
        presentation: 'Color',
      });

      expect(result.name).toBe(adminFixtures.optionType.name);
      expect(result.presentation).toBe('Color');
    });
  });

  describe('get', () => {
    it('returns an option type by ID', async () => {
      const result = await client.admin.optionTypes.get('ot_1');

      expect(result.name).toBe(adminFixtures.optionType.name);
    });
  });

  describe('update', () => {
    it('updates an option type', async () => {
      const result = await client.admin.optionTypes.update('ot_1', {
        presentation: 'Updated Color',
      });

      expect(result.presentation).toBe('Updated Color');
    });
  });

  describe('delete', () => {
    it('deletes an option type', async () => {
      await expect(
        client.admin.optionTypes.delete('ot_1')
      ).resolves.toBeUndefined();
    });
  });
});
