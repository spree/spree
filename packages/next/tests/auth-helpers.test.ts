import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from './setup';
import { initSpreeNext, resetClient } from '../src/config';

const mockClient = {
  store: {
    auth: {
      refresh: vi.fn(),
    },
  },
};

vi.mock('@spree/sdk', () => {
  class SpreeError extends Error {
    public readonly status: number;
    constructor(response: { error: { message: string } }, status: number) {
      super(response.error.message);
      this.status = status;
    }
  }
  return {
    createSpreeClient: vi.fn(() => mockClient),
    SpreeError,
  };
});

import { getAuthOptions, withAuthRefresh } from '../src/auth-helpers';
import { SpreeError } from '@spree/sdk';

// Helper: create a JWT with a specific expiration time
function makeJwt(expInSeconds: number): string {
  const payload = { exp: expInSeconds };
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

describe('auth-helpers', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
  });

  describe('getAuthOptions', () => {
    it('returns empty object when no token', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const options = await getAuthOptions();
      expect(options).toEqual({});
    });

    it('returns token without refresh when far from expiry', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400; // 24h from now
      const jwt = makeJwt(futureExp);
      mockCookieStore.get.mockReturnValue({ value: jwt });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: jwt });
      expect(mockClient.store.auth.refresh).not.toHaveBeenCalled();
    });

    it('refreshes token when near expiry', async () => {
      const nearExp = Math.floor(Date.now() / 1000) + 1800; // 30min from now (< 1h)
      const jwt = makeJwt(nearExp);
      const newJwt = 'refreshed_token';
      mockCookieStore.get.mockReturnValue({ value: jwt });
      mockClient.store.auth.refresh.mockResolvedValue({ token: newJwt });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: newJwt });
      expect(mockClient.store.auth.refresh).toHaveBeenCalledWith({ token: jwt });
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        newJwt,
        expect.any(Object)
      );
    });

    it('uses original token when refresh fails near expiry', async () => {
      const nearExp = Math.floor(Date.now() / 1000) + 1800;
      const jwt = makeJwt(nearExp);
      mockCookieStore.get.mockReturnValue({ value: jwt });
      mockClient.store.auth.refresh.mockRejectedValue(new Error('Refresh failed'));

      const options = await getAuthOptions();
      expect(options).toEqual({ token: jwt });
    });

    it('uses token as-is when JWT cannot be decoded', async () => {
      const malformedJwt = 'not-a-valid-jwt';
      mockCookieStore.get.mockReturnValue({ value: malformedJwt });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: malformedJwt });
      expect(mockClient.store.auth.refresh).not.toHaveBeenCalled();
    });
  });

  describe('withAuthRefresh', () => {
    it('throws when not authenticated', async () => {
      mockCookieStore.get.mockReturnValue(undefined);
      const fn = vi.fn();

      await expect(withAuthRefresh(fn)).rejects.toThrow('Not authenticated');
      expect(fn).not.toHaveBeenCalled();
    });

    it('calls fn with auth options and returns result', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookieStore.get.mockReturnValue({ value: jwt });
      const fn = vi.fn().mockResolvedValue({ data: 'result' });

      const result = await withAuthRefresh(fn);
      expect(result).toEqual({ data: 'result' });
      expect(fn).toHaveBeenCalledWith(expect.objectContaining({ token: jwt }));
    });

    it('retries with refreshed token on 401', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      const newJwt = 'refreshed_token';
      mockCookieStore.get.mockReturnValue({ value: jwt });

      const error401 = new SpreeError({ error: { message: 'Unauthorized' } } as any, 401);
      const fn = vi.fn()
        .mockRejectedValueOnce(error401)
        .mockResolvedValueOnce({ data: 'retried' });
      mockClient.store.auth.refresh.mockResolvedValue({ token: newJwt });

      const result = await withAuthRefresh(fn);
      expect(result).toEqual({ data: 'retried' });
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenLastCalledWith({ token: newJwt });
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        newJwt,
        expect.any(Object)
      );
    });

    it('clears token and rethrows when refresh fails on 401', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookieStore.get.mockReturnValue({ value: jwt });

      const error401 = new SpreeError({ error: { message: 'Unauthorized' } } as any, 401);
      const fn = vi.fn().mockRejectedValue(error401);
      mockClient.store.auth.refresh.mockRejectedValue(new Error('Refresh failed'));

      await expect(withAuthRefresh(fn)).rejects.toThrow('Unauthorized');
      // Token should be cleared
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
    });

    it('rethrows non-401 errors without refresh', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookieStore.get.mockReturnValue({ value: jwt });

      const error500 = new Error('Server error');
      const fn = vi.fn().mockRejectedValue(error500);

      await expect(withAuthRefresh(fn)).rejects.toThrow('Server error');
      expect(mockClient.store.auth.refresh).not.toHaveBeenCalled();
    });
  });
});
