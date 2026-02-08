"use server";

// src/auth-helpers.ts
import { SpreeError } from "@spree/sdk";

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
var DEFAULT_ACCESS_TOKEN_COOKIE = "_spree_jwt";
var CART_TOKEN_MAX_AGE = 60 * 60 * 24 * 30;
var ACCESS_TOKEN_MAX_AGE = 60 * 60 * 24 * 7;
function getAccessTokenCookieName() {
  try {
    return getConfig().accessTokenCookieName ?? DEFAULT_ACCESS_TOKEN_COOKIE;
  } catch {
    return DEFAULT_ACCESS_TOKEN_COOKIE;
  }
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

// src/auth-helpers.ts
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
export {
  getGiftCard,
  listGiftCards
};
//# sourceMappingURL=gift-cards.js.map