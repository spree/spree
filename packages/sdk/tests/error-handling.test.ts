import { describe, it, expect } from 'vitest';
import { server } from './mocks/server';
import { http, HttpResponse } from 'msw';
import { SpreeError } from '../src';
import { createTestClient, TEST_BASE_URL } from './helpers';

const API_PREFIX = `${TEST_BASE_URL}/api/v3/store`;

describe('error handling', () => {
  it('throws SpreeError with correct properties on 4xx', async () => {
    server.use(
      http.get(`${API_PREFIX}/products/:id`, () =>
        HttpResponse.json(
          {
            error: {
              code: 'not_found',
              message: 'Product not found',
            },
          },
          { status: 404 }
        )
      )
    );

    const client = createTestClient();
    try {
      await client.products.get('nonexistent');
      expect.unreachable('Should have thrown');
    } catch (error) {
      expect(error).toBeInstanceOf(SpreeError);
      const spreeError = error as SpreeError;
      expect(spreeError.code).toBe('not_found');
      expect(spreeError.status).toBe(404);
      expect(spreeError.message).toBe('Product not found');
      expect(spreeError.name).toBe('SpreeError');
    }
  });

  it('throws SpreeError with details on 422', async () => {
    server.use(
      http.post(`${API_PREFIX}/customer/addresses`, () =>
        HttpResponse.json(
          {
            error: {
              code: 'unprocessable_entity',
              message: 'Validation failed',
              details: {
                address1: ['can\'t be blank'],
                city: ['can\'t be blank'],
              },
            },
          },
          { status: 422 }
        )
      )
    );

    const client = createTestClient();
    try {
      await client.customer.addresses.create(
        { firstname: 'A', lastname: 'B', address1: '', city: '', zipcode: '00000', country_iso: 'US' },
        { token: 'jwt' }
      );
      expect.unreachable('Should have thrown');
    } catch (error) {
      const spreeError = error as SpreeError;
      expect(spreeError.status).toBe(422);
      expect(spreeError.details).toHaveProperty('address1');
      expect(spreeError.details).toHaveProperty('city');
    }
  });

  it('throws SpreeError on 500 server error', async () => {
    server.use(
      http.get(`${API_PREFIX}/store`, () =>
        HttpResponse.json(
          {
            error: {
              code: 'internal_server_error',
              message: 'Something went wrong',
            },
          },
          { status: 500 }
        )
      )
    );

    const client = createTestClient();
    try {
      await client.store.get();
      expect.unreachable('Should have thrown');
    } catch (error) {
      const spreeError = error as SpreeError;
      expect(spreeError.status).toBe(500);
      expect(spreeError.code).toBe('internal_server_error');
    }
  });

  it('throws SpreeError on 401 unauthorized', async () => {
    server.use(
      http.get(`${API_PREFIX}/customer`, () =>
        HttpResponse.json(
          {
            error: {
              code: 'unauthorized',
              message: 'You must be logged in',
            },
          },
          { status: 401 }
        )
      )
    );

    const client = createTestClient();
    try {
      await client.customer.get();
      expect.unreachable('Should have thrown');
    } catch (error) {
      const spreeError = error as SpreeError;
      expect(spreeError.status).toBe(401);
      expect(spreeError.code).toBe('unauthorized');
    }
  });

  it('handles 204 No Content responses', async () => {
    const client = createTestClient();
    const result = await client.orders.lineItems.delete('order_1', 'li_1', { token: 'jwt' });
    expect(result).toBeUndefined();
  });
});
