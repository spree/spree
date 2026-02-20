import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('markets', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns all markets', async () => {
      const result = await client.store.markets.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].name).toBe('North America');
      expect(result.data[0].currency).toBe('USD');
      expect(result.data[0].countries).toBeInstanceOf(Array);
    });
  });

  describe('get', () => {
    it('returns a market by prefixed ID', async () => {
      const result = await client.store.markets.get('mkt_1');
      expect(result.name).toBe(fixtures.market.name);
      expect(result.currency).toBe('USD');
    });
  });

  describe('resolve', () => {
    it('resolves a market from country ISO code', async () => {
      const result = await client.store.markets.resolve('US');
      expect(result.name).toBe(fixtures.market.name);
      expect(result.currency).toBe('USD');
    });
  });

  describe('countries', () => {
    describe('list', () => {
      it('returns countries in a market', async () => {
        const result = await client.store.markets.countries.list('mkt_1');
        expect(result.data).toHaveLength(1);
        expect(result.data[0].iso).toBe('US');
      });
    });

    describe('get', () => {
      it('returns a country by ISO code within a market', async () => {
        const result = await client.store.markets.countries.get('mkt_1', 'US');
        expect(result.name).toBe(fixtures.country.name);
        expect(result.iso).toBe('US');
      });
    });
  });
});
