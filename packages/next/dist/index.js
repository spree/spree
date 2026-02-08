import { createSpreeClient, SpreeError } from '@spree/sdk';
import { revalidateTag } from 'next/cache';
import { cookies } from 'next/headers';

// src/config.ts
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

// src/data/products.ts
async function listProducts(params, options) {
  return getClient().products.list(params, {
    locale: options?.locale,
    currency: options?.currency
  });
}
async function getProduct(slugOrId, params, options) {
  return getClient().products.get(slugOrId, params, {
    locale: options?.locale,
    currency: options?.currency
  });
}
async function getProductFilters(params, options) {
  return getClient().products.filters(params, {
    locale: options?.locale,
    currency: options?.currency
  });
}

// src/data/taxons.ts
async function listTaxons(params, options) {
  return getClient().taxons.list(params, {
    locale: options?.locale,
    currency: options?.currency
  });
}
async function getTaxon(idOrPermalink, params, options) {
  return getClient().taxons.get(idOrPermalink, params, {
    locale: options?.locale,
    currency: options?.currency
  });
}
async function listTaxonProducts(taxonId, params, options) {
  return getClient().taxons.products.list(taxonId, params, {
    locale: options?.locale,
    currency: options?.currency
  });
}

// src/data/taxonomies.ts
async function listTaxonomies(params, options) {
  return getClient().taxonomies.list(params, {
    locale: options?.locale,
    currency: options?.currency
  });
}
async function getTaxonomy(id, params, options) {
  return getClient().taxonomies.get(id, params, {
    locale: options?.locale,
    currency: options?.currency
  });
}

// src/data/store.ts
async function getStore(options) {
  return getClient().store.get({
    locale: options?.locale,
    currency: options?.currency
  });
}

// src/data/countries.ts
async function listCountries(options) {
  return getClient().countries.list({
    locale: options?.locale,
    currency: options?.currency
  });
}
async function getCountry(iso, options) {
  return getClient().countries.get(iso, {
    locale: options?.locale,
    currency: options?.currency
  });
}
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
async function setAccessToken(token) {
  const cookieStore = await cookies();
  cookieStore.set(getAccessTokenCookieName(), token, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: ACCESS_TOKEN_MAX_AGE
  });
}
async function clearAccessToken() {
  const cookieStore = await cookies();
  cookieStore.set(getAccessTokenCookieName(), "", {
    maxAge: -1,
    path: "/"
  });
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
async function getCheckoutOptions() {
  const orderToken = await getCartToken();
  const token = await getAccessToken();
  return { orderToken, token };
}
async function getCheckout(orderId) {
  const options = await getCheckoutOptions();
  return getClient().orders.get(orderId, void 0, options);
}
async function updateAddresses(orderId, params) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.update(orderId, params, options);
  revalidateTag("checkout");
  return result;
}
async function advance(orderId) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.advance(orderId, options);
  revalidateTag("checkout");
  return result;
}
async function next(orderId) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.next(orderId, options);
  revalidateTag("checkout");
  return result;
}
async function getShipments(orderId) {
  const options = await getCheckoutOptions();
  return getClient().orders.shipments.list(orderId, options);
}
async function selectShippingRate(orderId, shipmentId, shippingRateId) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.shipments.update(
    orderId,
    shipmentId,
    { selected_shipping_rate_id: shippingRateId },
    options
  );
  revalidateTag("checkout");
  return result;
}
async function applyCoupon(orderId, code) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.couponCodes.apply(orderId, code, options);
  revalidateTag("checkout");
  revalidateTag("cart");
  return result;
}
async function removeCoupon(orderId, promotionId) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.couponCodes.remove(orderId, promotionId, options);
  revalidateTag("checkout");
  revalidateTag("cart");
  return result;
}
async function complete(orderId) {
  const options = await getCheckoutOptions();
  const result = await getClient().orders.complete(orderId, options);
  revalidateTag("checkout");
  revalidateTag("cart");
  return result;
}
async function getAuthOptions() {
  const token = await getAccessToken();
  if (!token) {
    return {};
  }
  try {
    const payload = JSON.parse(atob(token.split(".")[1]));
    const exp = payload.exp;
    const now = Math.floor(Date.now() / 1e3);
    if (exp && exp - now < 3600) {
      try {
        const refreshed = await getClient().auth.refresh({ token });
        await setAccessToken(refreshed.token);
        return { token: refreshed.token };
      } catch {
      }
    }
  } catch {
  }
  return { token };
}
async function withAuthRefresh(fn) {
  const options = await getAuthOptions();
  if (!options.token) {
    throw new Error("Not authenticated");
  }
  try {
    return await fn(options);
  } catch (error) {
    if (error instanceof SpreeError && error.status === 401) {
      try {
        const refreshed = await getClient().auth.refresh({ token: options.token });
        await setAccessToken(refreshed.token);
        return await fn({ token: refreshed.token });
      } catch {
        await clearAccessToken();
        throw error;
      }
    }
    throw error;
  }
}

// src/actions/auth.ts
async function login(email, password) {
  try {
    const result = await getClient().auth.login({ email, password });
    await setAccessToken(result.token);
    const cartToken = await getCartToken();
    if (cartToken) {
      try {
        await getClient().cart.associate({
          token: result.token,
          orderToken: cartToken
        });
      } catch {
      }
    }
    revalidateTag("customer");
    revalidateTag("cart");
    return { success: true, user: result.user };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Invalid email or password"
    };
  }
}
async function register(email, password, passwordConfirmation) {
  try {
    const result = await getClient().auth.register({
      email,
      password,
      password_confirmation: passwordConfirmation
    });
    await setAccessToken(result.token);
    const cartToken = await getCartToken();
    if (cartToken) {
      try {
        await getClient().cart.associate({
          token: result.token,
          orderToken: cartToken
        });
      } catch {
      }
    }
    revalidateTag("customer");
    revalidateTag("cart");
    return { success: true, user: result.user };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : "Registration failed"
    };
  }
}
async function logout() {
  await clearAccessToken();
  revalidateTag("customer");
  revalidateTag("cart");
  revalidateTag("addresses");
  revalidateTag("credit-cards");
}
async function getCustomer() {
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
async function updateCustomer(data) {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.update(data, options);
  });
  revalidateTag("customer");
  return result;
}
async function listAddresses() {
  return withAuthRefresh(async (options) => {
    return getClient().customer.addresses.list(void 0, options);
  });
}
async function getAddress(id) {
  return withAuthRefresh(async (options) => {
    return getClient().customer.addresses.get(id, options);
  });
}
async function createAddress(params) {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.create(params, options);
  });
  revalidateTag("addresses");
  return result;
}
async function updateAddress(id, params) {
  const result = await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.update(id, params, options);
  });
  revalidateTag("addresses");
  return result;
}
async function deleteAddress(id) {
  await withAuthRefresh(async (options) => {
    return getClient().customer.addresses.delete(id, options);
  });
  revalidateTag("addresses");
}

// src/actions/orders.ts
async function listOrders(params) {
  return withAuthRefresh(async (options) => {
    return getClient().orders.list(params, options);
  });
}
async function getOrder(idOrNumber, params) {
  return withAuthRefresh(async (options) => {
    return getClient().orders.get(idOrNumber, params, options);
  });
}
async function listCreditCards() {
  return withAuthRefresh(async (options) => {
    return getClient().customer.creditCards.list(void 0, options);
  });
}
async function deleteCreditCard(id) {
  await withAuthRefresh(async (options) => {
    return getClient().customer.creditCards.delete(id, options);
  });
  revalidateTag("credit-cards");
}

// src/actions/gift-cards.ts
async function listGiftCards() {
  return withAuthRefresh(async (options) => {
    return getClient().customer.giftCards.list(void 0, options);
  });
}
async function getGiftCard(id) {
  return withAuthRefresh(async (options) => {
    return getClient().customer.giftCards.get(id, options);
  });
}

export { addItem, advance, applyCoupon, associateCart, clearCart, complete, createAddress, deleteAddress, deleteCreditCard, getAddress, getCart, getCheckout, getClient, getCountry, getCustomer, getGiftCard, getOrCreateCart, getOrder, getProduct, getProductFilters, getShipments, getStore, getTaxon, getTaxonomy, initSpreeNext, listAddresses, listCountries, listCreditCards, listGiftCards, listOrders, listProducts, listTaxonProducts, listTaxonomies, listTaxons, login, logout, next, register, removeCoupon, removeItem, selectShippingRate, updateAddress, updateAddresses, updateCustomer, updateItem };
//# sourceMappingURL=index.js.map
//# sourceMappingURL=index.js.map