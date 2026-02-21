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
      expect(result.data[0].currency).toBe('USD');
      expect(result.data[0].default_locale).toBe('en');
    });
  });

  describe('get', () => {
    it('returns a country by ISO code', async () => {
      const result = await client.store.countries.get('US');
      expect(result.iso).toBe(fixtures.country.iso);
      expect(result.currency).toBe('USD');
      expect(result.default_locale).toBe('en');
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
