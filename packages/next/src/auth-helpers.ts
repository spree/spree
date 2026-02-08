import { SpreeError } from '@spree/sdk';
import type { RequestOptions } from '@spree/sdk';
import { getClient } from './config';
import { getAccessToken, setAccessToken, clearAccessToken } from './cookies';

/**
 * Get auth request options from the current JWT token.
 * Proactively refreshes the token if it expires within 1 hour.
 */
export async function getAuthOptions(): Promise<RequestOptions> {
  const token = await getAccessToken();
  if (!token) {
    return {};
  }

  // Check if token is close to expiry by decoding JWT payload
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    const exp = payload.exp;
    const now = Math.floor(Date.now() / 1000);

    // Refresh if token expires in less than 1 hour
    if (exp && exp - now < 3600) {
      try {
        const refreshed = await getClient().auth.refresh({ token });
        await setAccessToken(refreshed.token);
        return { token: refreshed.token };
      } catch {
        // Refresh failed — use existing token, it might still work
      }
    }
  } catch {
    // Can't decode JWT — use it as-is, the server will reject if invalid
  }

  return { token };
}

/**
 * Execute an authenticated request with automatic token refresh on 401.
 * @param fn - Function that takes RequestOptions and returns a promise
 * @returns The result of the function
 * @throws SpreeError if auth fails after refresh attempt
 */
export async function withAuthRefresh<T>(
  fn: (options: RequestOptions) => Promise<T>
): Promise<T> {
  const options = await getAuthOptions();

  if (!options.token) {
    throw new Error('Not authenticated');
  }

  try {
    return await fn(options);
  } catch (error: unknown) {
    // If 401, try refreshing the token once
    if (error instanceof SpreeError && error.status === 401) {
      try {
        const refreshed = await getClient().auth.refresh({ token: options.token });
        await setAccessToken(refreshed.token);
        return await fn({ token: refreshed.token });
      } catch {
        // Refresh failed — clear token and rethrow
        await clearAccessToken();
        throw error;
      }
    }
    throw error;
  }
}
