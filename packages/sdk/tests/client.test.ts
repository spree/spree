import { describe, it, expect } from 'vitest';
import { SpreeClient, createSpreeClient } from '../src';
import { TEST_BASE_URL, TEST_API_KEY } from './helpers';

describe('SpreeClient', () => {
  it('creates a client via constructor', () => {
    const client = new SpreeClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    });
    expect(client).toBeInstanceOf(SpreeClient);
  });

  it('creates a client via factory function', () => {
    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    });
    expect(client).toBeInstanceOf(SpreeClient);
  });

  it('strips trailing slash from baseUrl', async () => {
    const client = createSpreeClient({
      baseUrl: `${TEST_BASE_URL}/`,
      publishableKey: TEST_API_KEY,
    });
    // Should not throw - the trailing slash is handled
    const store = await client.store.store.get();
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
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.store.get();
    expect(capturedUrl).toContain('/api/v3/store/store');
  });

  it('sends x-spree-api-key header on every store request', async () => {
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
      publishableKey: 'my-secret-key',
      fetch: customFetch,
    });

    await client.store.store.get();
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
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.store.get({ token: 'my-jwt-token' });
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
      publishableKey: TEST_API_KEY,
      fetch: customFetch,
    });

    await client.store.store.get({ locale: 'fr', currency: 'EUR' });
    expect(capturedHeaders['x-spree-locale']).toBe('fr');
    expect(capturedHeaders['x-spree-currency']).toBe('EUR');
  });

  it('exposes store and admin namespaces', () => {
    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    });

    expect(client.store).toBeDefined();
    expect(client.admin).toBeDefined();
  });

  it('exposes all resource namespaces under store', () => {
    const client = createSpreeClient({
      baseUrl: TEST_BASE_URL,
      publishableKey: TEST_API_KEY,
    });

    expect(client.store.auth).toBeDefined();
    expect(client.store.store).toBeDefined();
    expect(client.store.products).toBeDefined();
    expect(client.store.taxonomies).toBeDefined();
    expect(client.store.taxons).toBeDefined();
    expect(client.store.countries).toBeDefined();
    expect(client.store.currencies).toBeDefined();
    expect(client.store.locales).toBeDefined();
    expect(client.store.cart).toBeDefined();
    expect(client.store.orders).toBeDefined();
    expect(client.store.customer).toBeDefined();
    expect(client.store.wishlists).toBeDefined();
  });
});
