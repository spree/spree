'use server';

import { revalidateTag } from 'next/cache';
import type { StoreUser } from '@spree/sdk';
import { getClient } from '../config';
import { setAccessToken, clearAccessToken, getAccessToken, getCartToken } from '../cookies';
import { withAuthRefresh } from '../auth-helpers';

/**
 * Login with email and password.
 * Automatically associates any guest cart with the authenticated user.
 */
export async function login(
  email: string,
  password: string
): Promise<{ success: boolean; user?: { id: string; email: string; first_name?: string | null; last_name?: string | null }; error?: string }> {
  try {
    const result = await getClient().auth.login({ email, password });
    await setAccessToken(result.token);

    // Associate guest cart if one exists
    const cartToken = await getCartToken();
    if (cartToken) {
      try {
        await getClient().cart.associate({
          token: result.token,
          orderToken: cartToken,
        });
      } catch {
        // Cart association failure is non-fatal
      }
    }

    revalidateTag('customer');
    revalidateTag('cart');
    return { success: true, user: result.user };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Invalid email or password',
    };
  }
}

/**
 * Register a new customer account.
 * Automatically associates any guest cart with the new account.
 */
export async function register(
  email: string,
  password: string,
  passwordConfirmation: string
): Promise<{ success: boolean; user?: { id: string; email: string; first_name?: string | null; last_name?: string | null }; error?: string }> {
  try {
    const result = await getClient().auth.register({
      email,
      password,
      password_confirmation: passwordConfirmation,
    });
    await setAccessToken(result.token);

    // Associate guest cart
    const cartToken = await getCartToken();
    if (cartToken) {
      try {
        await getClient().cart.associate({
          token: result.token,
          orderToken: cartToken,
        });
      } catch {
        // Non-fatal
      }
    }

    revalidateTag('customer');
    revalidateTag('cart');
    return { success: true, user: result.user };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Registration failed',
    };
  }
}

/**
 * Logout the current user.
 */
export async function logout(): Promise<void> {
  await clearAccessToken();
  revalidateTag('customer');
  revalidateTag('cart');
  revalidateTag('addresses');
  revalidateTag('credit-cards');
}

/**
 * Get the currently authenticated customer. Returns null if not logged in.
 */
export async function getCustomer(): Promise<StoreUser | null> {
  const token = await getAccessToken();
  if (!token) return null;

  try {
    return await withAuthRefresh(async (options) => {
      return getClient().customer.get(options);
    });
  } catch {
    await clearAccessToken();
    return null;
  }
}

/**
 * Update the current customer's profile.
 */
export async function updateCustomer(
  data: { first_name?: string; last_name?: string; email?: string }
): Promise<StoreUser> {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.update(data, options);
  });
  revalidateTag('customer');
  return result;
}
