import { describe, it, expect, beforeAll } from 'vitest';
import { createTestClient } from './helpers';
import { fixtures } from './mocks/handlers';
import type { SpreeClient } from '../src';

describe('countries', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns all countries', async () => {
      const result = await client.store.countries.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].iso).toBe('US');
      expect(result.data[0].name).toBe('United States');
    });
  });

  describe('get', () => {
    it('returns a country by ISO code', async () => {
      const result = await client.store.countries.get('US');
      expect(result.iso).toBe(fixtures.country.iso);
      expect(result.name).toBe('United States');
    });
  });
});

describe('currencies', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns all currencies', async () => {
      const result = await client.store.currencies.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].iso_code).toBe('USD');
      expect(result.data[0].name).toBe('United States Dollar');
      expect(result.data[0].symbol).toBe('$');
    });
  });
});

describe('locales', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns all locales', async () => {
      const result = await client.store.locales.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].code).toBe('en');
      expect(result.data[0].name).toBe('English');
    });
  });
});

describe('markets', () => {
  let client: SpreeClient;
  beforeAll(() => { client = createTestClient(); });

  describe('list', () => {
    it('returns all markets', async () => {
      const result = await client.store.markets.list();

      expect(result.data).toHaveLength(1);
      expect(result.data[0].id).toBe('mkt_1');
      expect(result.data[0].name).toBe('North America');
      expect(result.data[0].currency).toBe('USD');
      expect(result.data[0].default_locale).toBe('en');
      expect(result.data[0].supported_locales).toEqual(['en', 'es']);
      expect(result.data[0].tax_inclusive).toBe(false);
      expect(result.data[0].default).toBe(true);
      expect(result.data[0].countries).toHaveLength(1);
    });
  });

  describe('get', () => {
    it('returns a market by prefixed ID', async () => {
      const result = await client.store.markets.get('mkt_1');

      expect(result.id).toBe('mkt_1');
      expect(result.name).toBe('North America');
      expect(result.currency).toBe('USD');
    });
  });

  describe('resolve', () => {
    it('resolves a market by country ISO', async () => {
      const result = await client.store.markets.resolve('US');

      expect(result.id).toBe('mkt_1');
      expect(result.currency).toBe('USD');
    });
  });

  describe('countries', () => {
    it('lists countries in a market', async () => {
      const result = await client.store.markets.countries.list('mkt_1');

      expect(result.data).toHaveLength(1);
      expect(result.data[0].iso).toBe('US');
    });

    it('gets a country in a market', async () => {
      const result = await client.store.markets.countries.get('mkt_1', 'US');

      expect(result.iso).toBe('US');
    });
  });
});
