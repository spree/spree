"use server";

// src/actions/cart.ts
import { revalidateTag } from "next/cache";

// src/config.ts
import { createSpreeClient } from "@spree/sdk";
var _client = null;
var _config = null;
function initSpreeNext(config) {
  _config = config;
  _client = createSpreeClient({
    baseUrl: config.baseUrl,
    apiKey: config.apiKey
  });
}
function getClient() {
  if (!_client) {
    const baseUrl = process.env.SPREE_API_URL;
    const apiKey = process.env.SPREE_API_KEY;
    if (baseUrl && apiKey) {
      initSpreeNext({ baseUrl, apiKey });
    } else {
      throw new Error(
        "@spree/next is not configured. Either call initSpreeNext() or set SPREE_API_URL and SPREE_API_KEY environment variables."
      );
    }
  }
  return _client;
}
function getConfig() {
  if (!_config) {
    getClient();
  }
  return _config;
}

// src/cookies.ts
import { cookies } from "next/headers";
var DEFAULT_CART_COOKIE = "_spree_cart_token";
var DEFAULT_ACCESS_TOKEN_COOKIE = "_spree_jwt";
var CART_TOKEN_MAX_AGE = 60 * 60 * 24 * 30;
var ACCESS_TOKEN_MAX_AGE = 60 * 60 * 24 * 7;
function getCartCookieName() {
  try {
    return getConfig().cartCookieName ?? DEFAULT_CART_COOKIE;
  } catch {
    return DEFAULT_CART_COOKIE;
  }
}
function getAccessTokenCookieName() {
  try {
    return getConfig().accessTokenCookieName ?? DEFAULT_ACCESS_TOKEN_COOKIE;
  } catch {
    return DEFAULT_ACCESS_TOKEN_COOKIE;
  }
}
async function getCartToken() {
  const cookieStore = await cookies();
  return cookieStore.get(getCartCookieName())?.value;
}
async function setCartToken(token) {
  const cookieStore = await cookies();
  cookieStore.set(getCartCookieName(), token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: CART_TOKEN_MAX_AGE
  });
}
async function clearCartToken() {
  const cookieStore = await cookies();
  cookieStore.set(getCartCookieName(), "", {
    maxAge: -1,
    path: "/"
  });
}
async function getAccessToken() {
  const cookieStore = await cookies();
  return cookieStore.get(getAccessTokenCookieName())?.value;
}

// src/actions/cart.ts
async function getCart() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) return null;
  try {
    return await getClient().cart.get({ orderToken, token });
  } catch {
    return null;
  }
}
async function getOrCreateCart() {
  const existing = await getCart();
  if (existing) return existing;
  const token = await getAccessToken();
  const cart = await getClient().cart.create(token ? { token } : void 0);
  if (cart.token) {
    await setCartToken(cart.token);
  }
  revalidateTag("cart");
  return cart;
}
async function addItem(variantId, quantity = 1) {
  const cart = await getOrCreateCart();
  const orderToken = cart.token;
  const token = await getAccessToken();
  const lineItem = await getClient().orders.lineItems.create(
    cart.id,
    { variant_id: variantId, quantity },
    { orderToken, token }
  );
  revalidateTag("cart");
  return lineItem;
}
async function updateItem(lineItemId, quantity) {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) throw new Error("No cart found");
  const cart = await getClient().cart.get({ orderToken, token });
  const lineItem = await getClient().orders.lineItems.update(
    cart.id,
    lineItemId,
    { quantity },
    { orderToken, token }
  );
  revalidateTag("cart");
  return lineItem;
}
async function removeItem(lineItemId) {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken && !token) throw new Error("No cart found");
  const cart = await getClient().cart.get({ orderToken, token });
  await getClient().orders.lineItems.delete(cart.id, lineItemId, {
    orderToken,
    token
  });
  revalidateTag("cart");
}
async function clearCart() {
  await clearCartToken();
  revalidateTag("cart");
}
async function associateCart() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  if (!orderToken || !token) return null;
  try {
    const result = await getClient().cart.associate({ orderToken, token });
    revalidateTag("cart");
    return result;
  } catch {
    await clearCartToken();
    revalidateTag("cart");
    return null;
  }
}
export {
  addItem,
  associateCart,
  clearCart,
  getCart,
  getOrCreateCart,
  removeItem,
  updateItem
};
//# sourceMappingURL=cart.js.map