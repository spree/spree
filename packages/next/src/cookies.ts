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

function getCartIdCookieName(): string {
  return `${getCartCookieName()}_id`;
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

// --- Cart ID (prefixed ID stored alongside token for REST API) ---

export async function getCartId(): Promise<string | undefined> {
  const cookieStore = await cookies();
  return cookieStore.get(getCartIdCookieName())?.value;
}

export async function setCartId(id: string): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getCartIdCookieName(), id, {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    path: '/',
    maxAge: CART_TOKEN_MAX_AGE,
  });
}

export async function clearCartId(): Promise<void> {
  const cookieStore = await cookies();
  cookieStore.set(getCartIdCookieName(), '', {
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

// --- Cart Options (combined cart + access tokens for cart/checkout/payment actions) ---

export async function getCartOptions(): Promise<{
  spreeToken: string | undefined;
  token: string | undefined;
}> {
  const spreeToken = await getCartToken();
  const token = await getAccessToken();
  return { spreeToken, token };
}

// --- Cart ID (required) ---

export async function requireCartId(): Promise<string> {
  const cartId = await getCartId();
  if (!cartId) throw new Error('No cart found');
  return cartId;
}
