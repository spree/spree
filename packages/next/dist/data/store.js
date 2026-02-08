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

// src/data/store.ts
async function getStore(options) {
  return getClient().store.get({
    locale: options?.locale,
    currency: options?.currency
  });
}

export { getStore };
//# sourceMappingURL=store.js.map
//# sourceMappingURL=store.js.map