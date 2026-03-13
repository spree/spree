import { describe, it, expect, vi } from 'vitest';
import { createClient } from '../src/client';
import { SpreeError } from '@spree/sdk-core';

function jsonResponse(body: object, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...headers },
  });
}

function errorResponse(status: number, code = 'error', message = 'Error', headers: Record<string, string> = {}): Response {
  return new Response(
    JSON.stringify({ error: { code, message } }),
    { status, headers: { 'Content-Type': 'application/json', ...headers } }
  );
}

const paginatedEmpty = { data: [], meta: { page: 1, limit: 25, count: 0, pages: 0, from: 0, to: 0, in: 0, previous: null, next: null } };

describe('Retry logic', () => {
  const baseConfig = { baseUrl: 'https://api.test.com', publishableKey: 'pk_test' };

  describe('GET requests', () => {
    it('retries on 500 and succeeds', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500))
        .mockResolvedValueOnce(jsonResponse(paginatedEmpty));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.products.list();

      expect(result).toEqual(paginatedEmpty);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries on 429 and succeeds', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests'))
        .mockResolvedValueOnce(jsonResponse(paginatedEmpty));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.products.list();

      expect(result).toEqual(paginatedEmpty);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries on 502, 503, 504', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(502))
        .mockResolvedValueOnce(errorResponse(503))
        .mockResolvedValueOnce(jsonResponse(paginatedEmpty));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.products.list();

      expect(result).toEqual(paginatedEmpty);
      expect(mockFetch).toHaveBeenCalledTimes(3);
    });

    it('throws after max retries exhausted', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValue(errorResponse(500, 'server_error', 'Internal error'));

      const client = createClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.products.list()).rejects.toThrow(SpreeError);
      // 1 initial + 2 retries = 3 attempts
      expect(mockFetch).toHaveBeenCalledTimes(3);
    });

    it('retries on network errors for GET', async () => {
      const mockFetch = vi.fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockResolvedValueOnce(jsonResponse(paginatedEmpty));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.products.list();

      expect(result).toEqual(paginatedEmpty);
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('does not retry on 400 (client error)', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(400, 'bad_request', 'Bad request'));

      const client = createClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.products.list()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('does not retry on 401 (unauthorized)', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(401, 'unauthorized', 'Unauthorized'));

      const client = createClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.products.list()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('POST requests (auto-idempotency)', () => {
    it('retries POST on 429', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests'))
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.auth.login({ email: 'a@b.com', password: 'pass' });

      expect(result.token).toBe('abc');
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries POST on 500 with auto-generated idempotency key', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500, 'server_error', 'Internal error'))
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.auth.login({ email: 'a@b.com', password: 'pass' });

      expect(result.token).toBe('abc');
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries POST on network errors with auto-generated idempotency key', async () => {
      const mockFetch = vi.fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.auth.login({ email: 'a@b.com', password: 'pass' });

      expect(result.token).toBe('abc');
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('sends auto-generated Idempotency-Key header on POST', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      await client.auth.login({ email: 'a@b.com', password: 'pass' });

      const headers = mockFetch.mock.calls[0][1].headers;
      expect(headers['Idempotency-Key']).toMatch(/^spree-sdk-retry-/);
    });

    it('does not send Idempotency-Key on GET', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(jsonResponse({ data: [], meta: {} }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      await client.products.list();

      const headers = mockFetch.mock.calls[0][1].headers;
      expect(headers['Idempotency-Key']).toBeUndefined();
    });

    it('does NOT retry POST when retries are disabled', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500, 'server_error', 'Internal error'));

      const client = createClient({ ...baseConfig, fetch: mockFetch, retry: false });

      await expect(
        client.auth.login({ email: 'a@b.com', password: 'pass' })
      ).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('does not send Idempotency-Key when retries are disabled', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createClient({ ...baseConfig, fetch: mockFetch, retry: false });
      await client.auth.login({ email: 'a@b.com', password: 'pass' });

      const headers = mockFetch.mock.calls[0][1].headers;
      expect(headers['Idempotency-Key']).toBeUndefined();
    });

    it('uses user-supplied key over auto-generated one', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(jsonResponse({ number: 'R123', token: 'cart-token' }));

      const client = createClient({ ...baseConfig, fetch: mockFetch });
      await client.carts.create(undefined, { idempotencyKey: 'my-custom-key' });

      const headers = mockFetch.mock.calls[0][1].headers;
      expect(headers['Idempotency-Key']).toBe('my-custom-key');
    });
  });

  describe('retry: false disables retries', () => {
    it('does not retry when retry is disabled', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500, 'server_error', 'Internal error'));

      const client = createClient({ ...baseConfig, fetch: mockFetch, retry: false });

      await expect(client.products.list()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('custom retry config', () => {
    it('respects custom maxRetries', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValue(errorResponse(500, 'server_error', 'Internal error'));

      const client = createClient({
        ...baseConfig,
        fetch: mockFetch,
        retry: { maxRetries: 4, baseDelay: 10 },
      });

      await expect(client.products.list()).rejects.toThrow(SpreeError);
      // 1 initial + 4 retries = 5 attempts
      expect(mockFetch).toHaveBeenCalledTimes(5);
    });

    it('respects Retry-After header', async () => {
      const start = Date.now();
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests', { 'Retry-After': '1' }))
        .mockResolvedValueOnce(jsonResponse(paginatedEmpty));

      const client = createClient({
        ...baseConfig,
        fetch: mockFetch,
        retry: { baseDelay: 10 },
      });

      const result = await client.products.list();
      const elapsed = Date.now() - start;

      expect(result).toEqual(paginatedEmpty);
      // Retry-After: 1 = 1000ms delay
      expect(elapsed).toBeGreaterThanOrEqual(900);
    });
  });
});
