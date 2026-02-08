interface SpreeNextConfig {
    /** Base URL of the Spree API (e.g., 'https://api.mystore.com') */
    baseUrl: string;
    /** Publishable API key for store access */
    apiKey: string;
    /** Cookie name for the cart order token (default: '_spree_cart_token') */
    cartCookieName?: string;
    /** Cookie name for the JWT access token (default: '_spree_jwt') */
    accessTokenCookieName?: string;
    /** Default locale for API requests */
    defaultLocale?: string;
    /** Default currency for API requests */
    defaultCurrency?: string;
}
interface SpreeNextOptions {
    /** Locale for translated content (e.g., 'en', 'fr') */
    locale?: string;
    /** Currency for prices (e.g., 'USD', 'EUR') */
    currency?: string;
}

export type { SpreeNextConfig, SpreeNextOptions };
