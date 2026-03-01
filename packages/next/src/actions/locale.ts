'use server';

import { cookies } from 'next/headers';
import { getConfig } from '../config';

/**
 * Set locale/country cookies for subsequent requests.
 * Use this in country/language switchers instead of manipulating cookies directly.
 */
export async function setLocale(params: {
  country?: string;
  locale?: string;
}): Promise<void> {
  const config = getConfig();
  const cookieStore = await cookies();
  const maxAge = 60 * 60 * 24 * 365; // 1 year

  if (params.country) {
    cookieStore.set(config.countryCookieName ?? 'spree_country', params.country, {
      path: '/',
      maxAge,
    });
  }
  if (params.locale) {
    cookieStore.set(config.localeCookieName ?? 'spree_locale', params.locale, {
      path: '/',
      maxAge,
    });
  }
}
