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

export { getTaxon, listTaxonProducts, listTaxons };
//# sourceMappingURL=taxons.js.map
//# sourceMappingURL=taxons.js.map