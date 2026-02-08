import { describe, it, expect } from 'vitest';
import { server } from './mocks/server';
import { http, HttpResponse } from 'msw';
import { createTestClient, TEST_BASE_URL } from './helpers';

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`;

describe('auth', () => {
  describe('login', () => {
    it('returns auth tokens on successful login', async () => {
      const client = createTestClient();
      const result = await client.auth.login({
        email: 'test@example.com',
        password: 'password123',
      });

      expect(result.token).toBe('test-jwt-token');
      expect(result.user.email).toBe('test@example.com');
    });

    it('throws SpreeError on invalid credentials', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/login`, () =>
          HttpResponse.json(
            { error: { code: 'unauthorized', message: 'Invalid credentials' } },
            { status: 401 }
          )
        )
      );

      const client = createTestClient();
      await expect(
        client.auth.login({ email: 'bad@example.com', password: 'wrong' })
      ).rejects.toThrow('Invalid credentials');
    });
  });

  describe('register', () => {
    it('returns auth tokens on successful registration', async () => {
      const client = createTestClient();
      const result = await client.auth.register({
        email: 'new@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
      });

      expect(result.token).toBeDefined();
      expect(result.user).toBeDefined();
    });

    it('throws SpreeError on validation failure', async () => {
      server.use(
        http.post(`${API_PREFIX}/auth/register`, () =>
          HttpResponse.json(
            {
              error: {
                code: 'unprocessable_entity',
                message: 'Validation failed',
                details: { email: ['has already been taken'] },
              },
            },
            { status: 422 }
          )
        )
      );

      const client = createTestClient();
      try {
        await client.auth.register({
          email: 'existing@example.com',
          password: 'password123',
          password_confirmation: 'password123',
        });
        expect.unreachable('Should have thrown');
      } catch (error: any) {
        expect(error.code).toBe('unprocessable_entity');
        expect(error.status).toBe(422);
        expect(error.details?.email).toContain('has already been taken');
      }
    });
  });

  describe('refresh', () => {
    it('returns new tokens', async () => {
      const client = createTestClient();
      const result = await client.auth.refresh({ token: 'old-token' });

      expect(result.token).toBe('refreshed-jwt-token');
    });
  });
});
