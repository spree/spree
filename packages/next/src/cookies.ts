import { cookies } from 'next/headers';
import { getConfig } from './config';

const DEFAULT_CART_COOKIE = '_spree_cart_token';
const DEFAULT_ACCESS_TOKEN_COOKIE = '_spree_jwt';
const CART_TOKEN_MAX_AGE = 60 * 60 * 24 * 30; // 30 days
const ACCESS_TOKEN_MAX_AGE = 60 * 60 * 24 * 7; // 7 days

function getCartCookieName(): string {
  try {
    return getConfig().cartCookieName ?? DEFAULT_CART_COOKIE;
  } catch {
    return DEFAULT_CART_COOKIE;
  }
}

function getAccessTokenCookieName(): string {
  try {
    return getConfig().accessTokenCookieName ?? DEFAULT_ACCESS_TOKEN_COOKIE;
  } catch {
    return DEFAULT_ACCESS_TOKEN_COOKIE;
  }
}

// --- Cart Token ---

export async function getCartToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(getCartCookieName())?.value;
}

export async function setCartToken(token: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getCartCookieName(), token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: CART_TOKEN_MAX_AGE,
  });
}

export async function clearCartToken(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getCartCookieName(), '', {
    maxAge: -1,
    path: '/',
  });
}

// --- Access Token (JWT) ---

export async function getAccessToken(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(getAccessTokenCookieName())?.value;
}

export async function setAccessToken(token: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getAccessTokenCookieName(), token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: ACCESS_TOKEN_MAX_AGE,
  });
}

export async function clearAccessToken(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getAccessTokenCookieName(), '', {
    maxAge: -1,
    path: '/',
  });
}
