"use server";

// src/actions/checkout.ts
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
async function getAccessToken() {
  const cookieStore = await cookies();
  return cookieStore.get(getAccessTokenCookieName())?.value;
}

// src/actions/checkout.ts
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
export {
  advance,
  applyCoupon,
  complete,
  getCheckout,
  getShipments,
  next,
  removeCoupon,
  selectShippingRate,
  updateAddresses
};
//# sourceMappingURL=checkout.js.map