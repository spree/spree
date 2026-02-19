import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('store', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('get', () => {
    it('returns store information', async () => {
      const result = await client.store.store.get();

      expect(result.name).toBe(fixtures.store.name);
      expect(result.default_currency).toBe('USD');
    });
  });
});
