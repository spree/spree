import { cookies } from 'next/headers';
import { getConfig } from './config';

const DEFAULT_COUNTRY_COOKIE = 'spree_country';
const DEFAULT_LOCALE_COOKIE = 'spree_locale';

/**
 * Read locale/currency/country from cookies (set by middleware).
 * Falls back to config defaults.
 * @internal
 */
export async function getLocaleOptions(): Promise<{
  locale?: string;
  currency?: string;
  country?: string;
}> {
  const config = getConfig();
  const cookieStore = await cookies();

  const country = cookieStore.get(config.countryCookieName ?? DEFAULT_COUNTRY_COOKIE)?.value;
  const locale = cookieStore.get(config.localeCookieName ?? DEFAULT_LOCALE_COOKIE)?.value;

  return {
    locale: locale || config.defaultLocale,
    country: country || config.defaultCountry,
    // No currency — backend resolves from country via X-Spree-Country header
  };
}
