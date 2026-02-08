import { describe, it, expect } from 'vitest';
import { SpreeClient, createSpreeClient } from '../src';
import { TEST_BASE_URL, TEST_API_KEY } from './helpers';

describe('SpreeClient', () => {
  it('creates a client via constructor', () => {
    const client = new SpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
    });
    expect(client).toBeInstanceOf(SpreeClient);
  });

  it('creates a client via factory function', () => {
    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
    });
    expect(client).toBeInstanceOf(SpreeClient);
  });

  it('strips trailing slash from baseUrl', async () => {
    const client = createSpreeClient({
      baseUrl: `${TEST_BASE_URL}/`,
      apiKey: TEST_API_KEY,
    });
    // Should not throw - the trailing slash is handled
    const store = await client.store.get();
    expect(store).toBeDefined();
  });

  it('accepts a custom fetch implementation', async () => {
    let capturedUrl = '';
    const customFetch = async (input: string | URL | Request, init?: RequestInit) => {
      capturedUrl = input.toString();
      return new Response(JSON.stringify({ id: 'store_1', name: 'Test' }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    };

    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.get();
    expect(capturedUrl).toContain('/api/v3/store/store');
  });

  it('sends x-spree-api-key header on every request', async () => {
    let capturedHeaders: Record<string, string> = {};
    const customFetch = async (input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries(init?.headers as Record<string, string> || {})
      );
      return new Response(JSON.stringify({}), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    };

    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: 'my-secret-key',
      fetch: customFetch,
    });

    await client.store.get();
    expect(capturedHeaders['x-spree-api-key']).toBe('my-secret-key');
  });

  it('sends Authorization header when token is provided', async () => {
    let capturedHeaders: Record<string, string> = {};
    const customFetch = async (input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries(init?.headers as Record<string, string> || {})
      );
      return new Response(JSON.stringify({}), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    };

    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.get({ token: 'my-jwt-token' });
    expect(capturedHeaders['Authorization']).toBe('Bearer my-jwt-token');
  });

  it('sends locale and currency headers when provided', async () => {
    let capturedHeaders: Record<string, string> = {};
    const customFetch = async (input: string | URL | Request, init?: RequestInit) => {
      capturedHeaders = Object.fromEntries(
        Object.entries(init?.headers as Record<string, string> || {})
      );
      return new Response(JSON.stringify({}), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    };

    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.get({ locale: 'fr', currency: 'EUR' });
    expect(capturedHeaders['x-spree-locale']).toBe('fr');
    expect(capturedHeaders['x-spree-currency']).toBe('EUR');
  });

  it('exposes all resource namespaces', () => {
    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      apiKey: TEST_API_KEY,
    });

    expect(client.auth).toBeDefined();
    expect(client.store).toBeDefined();
    expect(client.products).toBeDefined();
    expect(client.taxonomies).toBeDefined();
    expect(client.taxons).toBeDefined();
    expect(client.countries).toBeDefined();
    expect(client.cart).toBeDefined();
    expect(client.orders).toBeDefined();
    expect(client.customer).toBeDefined();
    expect(client.wishlists).toBeDefined();
  });
});
