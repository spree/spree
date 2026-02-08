import { createSpreeClient } from '@spree/sdk';

// src/config.ts
var _client = null;
function initSpreeNext(config) {
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

export { getCountry, listCountries };
//# sourceMappingURL=countries.js.map
//# sourceMappingURL=countries.js.map