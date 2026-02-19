import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('countries', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns available countries', async () => {
      const result = await client.store.countries.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].iso).toBe('US');
    });
  });

  describe('get', () => {
    it('returns a country by ISO code', async () => {
      const result = await client.store.countries.get('US');
      expect(result.name).toBe(fixtures.country.name);
      expect(result.iso).toBe('US');
    });
  });
});
