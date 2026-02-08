import { describe, it, expect, vi, beforeEach } from 'vitest';
import { createSpreeClient, SpreeError } from '../src/client';

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

describe('Retry logic', () => {
  const baseConfig = { baseUrl: 'https://api.test.com', apiKey: 'pk_test' };

  describe('GET requests', () => {
    it('retries on 500 and succeeds', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500))
        .mockResolvedValueOnce(jsonResponse({ name: 'Test Store' }));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.store.get();

      expect(result).toEqual({ name: 'Test Store' });
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries on 429 and succeeds', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests'))
        .mockResolvedValueOnce(jsonResponse({ name: 'Test Store' }));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.store.get();

      expect(result).toEqual({ name: 'Test Store' });
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('retries on 502, 503, 504', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(502))
        .mockResolvedValueOnce(errorResponse(503))
        .mockResolvedValueOnce(jsonResponse({ name: 'Test Store' }));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.store.get();

      expect(result).toEqual({ name: 'Test Store' });
      expect(mockFetch).toHaveBeenCalledTimes(3);
    });

    it('throws after max retries exhausted', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValue(errorResponse(500, 'server_error', 'Internal error'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.store.get()).rejects.toThrow(SpreeError);
      // 1 initial + 2 retries = 3 attempts
      expect(mockFetch).toHaveBeenCalledTimes(3);
    });

    it('retries on network errors for GET', async () => {
      const mockFetch = vi.fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'))
        .mockResolvedValueOnce(jsonResponse({ name: 'Test Store' }));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.store.get();

      expect(result).toEqual({ name: 'Test Store' });
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('does not retry on 400 (client error)', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(400, 'bad_request', 'Bad request'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.store.get()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('does not retry on 401 (unauthorized)', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(401, 'unauthorized', 'Unauthorized'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });

      await expect(client.store.get()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('POST requests (non-idempotent)', () => {
    it('retries POST on 429 only', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests'))
        .mockResolvedValueOnce(jsonResponse({ token: 'abc', user: { id: '1', email: 'a@b.com' } }));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });
      const result = await client.auth.login({ email: 'a@b.com', password: 'pass' });

      expect(result.token).toBe('abc');
      expect(mockFetch).toHaveBeenCalledTimes(2);
    });

    it('does NOT retry POST on 500', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500, 'server_error', 'Internal error'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });

      await expect(
        client.auth.login({ email: 'a@b.com', password: 'pass' })
      ).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });

    it('does NOT retry POST on network errors', async () => {
      const mockFetch = vi.fn()
        .mockRejectedValueOnce(new TypeError('fetch failed'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch });

      await expect(
        client.auth.login({ email: 'a@b.com', password: 'pass' })
      ).rejects.toThrow(TypeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('retry: false disables retries', () => {
    it('does not retry when retry is disabled', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(500, 'server_error', 'Internal error'));

      const client = createSpreeClient({ ...baseConfig, fetch: mockFetch, retry: false });

      await expect(client.store.get()).rejects.toThrow(SpreeError);
      expect(mockFetch).toHaveBeenCalledTimes(1);
    });
  });

  describe('custom retry config', () => {
    it('respects custom maxRetries', async () => {
      const mockFetch = vi.fn()
        .mockResolvedValue(errorResponse(500, 'server_error', 'Internal error'));

      const client = createSpreeClient({
        ...baseConfig,
        fetch: mockFetch,
        retry: { maxRetries: 4, baseDelay: 10 },
      });

      await expect(client.store.get()).rejects.toThrow(SpreeError);
      // 1 initial + 4 retries = 5 attempts
      expect(mockFetch).toHaveBeenCalledTimes(5);
    });

    it('respects Retry-After header', async () => {
      const start = Date.now();
      const mockFetch = vi.fn()
        .mockResolvedValueOnce(errorResponse(429, 'rate_limited', 'Too many requests', { 'Retry-After': '1' }))
        .mockResolvedValueOnce(jsonResponse({ name: 'Test Store' }));

      const client = createSpreeClient({
        ...baseConfig,
        fetch: mockFetch,
        retry: { baseDelay: 10 },
      });

      const result = await client.store.get();
      const elapsed = Date.now() - start;

      expect(result).toEqual({ name: 'Test Store' });
      // Retry-After: 1 = 1000ms delay
      expect(elapsed).toBeGreaterThanOrEqual(900);
    });
  });
});
