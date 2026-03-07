import { describe, it, expect } from 'vitest';
import { server } from '../mocks/server';
import { http, HttpResponse } from 'msw';
import { createAdminTestClient, TEST_BASE_URL } from '../helpers';

const API_PREFIX = `${TEST_BASE_URL}/api/v3/admin`;

describe('admin auth', () => {
  describe('login', () => {
    it('returns auth tokens on successful login', async () => {
      const client = createAdminTestClient();
      const result = await client.admin.auth.login({
        email: 'admin@example.com',
        password: 'password123',
      });

      expect(result.token).toBe('admin-jwt-token');
      expect(result.user.email).toBe('admin@example.com');
      expect(result.user.first_name).toBe('Admin');
    });

    it('throws SpreeError on invalid credentials', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, () =>
          HttpResponse.json(
            { error: { code: 'authentication_failed', message: 'Invalid email or password' } },
            { status: 401 }
          )
        )
      );

      const client = createAdminTestClient();
      await expect(
        client.admin.auth.login({ email: 'bad@example.com', password: 'wrong' })
      ).rejects.toThrow('Invalid email or password');
    });
  });

  describe('refresh', () => {
    it('returns new tokens', async () => {
      const client = createAdminTestClient();
      const result = await client.admin.auth.refresh({ token: 'old-admin-token' });

      expect(result.token).toBe('refreshed-admin-jwt-token');
      expect(result.user.email).toBe('admin@example.com');
    });

    it('throws SpreeError on invalid token', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/refresh`, () =>
          HttpResponse.json(
            { error: { code: 'authentication_required', message: 'Authentication required' } },
            { status: 401 }
          )
        )
      );

      const client = createAdminTestClient();
      await expect(
        client.admin.auth.refresh({ token: 'invalid-token' })
      ).rejects.toThrow('Authentication required');
    });
  });
});
