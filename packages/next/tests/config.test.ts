import { describe, it, expect, beforeEach } from 'vitest';
import { initSpreeNext, getClient, resetClient } from '../src/config';

describe('config', () => {
  beforeEach(() => {
    resetClient();
    delete process.env.SPREE_API_URL;
    delete process.env.SPREE_API_KEY;
  });

  it('initializes from explicit config', () => {
    initSpreeNext({ baseUrl: 'https://api.test.com', apiKey: 'pk_test' });
    const client = getClient();
    expect(client).toBeDefined();
  });

  it('auto-initializes from env vars', () => {
    process.env.SPREE_API_URL = 'https://api.env.com';
    process.env.SPREE_API_KEY = 'pk_env';
    const client = getClient();
    expect(client).toBeDefined();
  });

  it('throws when no config and no env vars', () => {
    expect(() => getClient()).toThrow('@spree/next is not configured');
  });
});
