import { createSpreeClient } from '@spree/sdk';

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
function resetClient() {
  _client = null;
  _config = null;
}

export { getClient, getConfig, initSpreeNext, resetClient };
//# sourceMappingURL=config.js.map
//# sourceMappingURL=config.js.map