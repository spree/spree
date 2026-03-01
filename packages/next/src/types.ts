export interface SpreeNextConfig {
  /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
  baseUrl: string;
  /** Publishable API key for Store API access */
  publishableKey: string;
  /** Cookie name for the cart order token (default: '_spree_cart_token') */
  cartCookieName?: string;
  /** Cookie name for the JWT access token (default: '_spree_jwt') */
  accessTokenCookieName?: string;
  /** Cookie name for country (default: 'spree_country') */
  countryCookieName?: string;
  /** Cookie name for locale (default: 'spree_locale') */
  localeCookieName?: string;
  /** Default locale for API requests */
  defaultLocale?: string;
  /** Default currency for API requests */
  defaultCurrency?: string;
  /** Default country ISO code for market resolution */
  defaultCountry?: string;
}

export interface SpreeNextOptions {
  /** Locale for translated content (e.g., 'en', 'fr') */
  locale?: string;
  /** Currency for prices (e.g., 'USD', 'EUR') */
  currency?: string;
  /** Country ISO code for market resolution (e.g., 'US', 'DE') */
  country?: string;
}
