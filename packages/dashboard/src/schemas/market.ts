import type { LocaleCode, MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import {
  countryCodeSchema,
  currencyCodeSchema,
  isLocaleCode,
  localeCodeSchema,
} from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import type { DefaultValues } from 'react-hook-form'
import { z } from 'zod/v4'

export const marketFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  currency: currencyCodeSchema,
  default_locale: localeCodeSchema,
  supported_locales: z.array(z.custom<LocaleCode>(isLocaleCode)),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  country_codes: z
    .array(countryCodeSchema)
    .min(1, { error: requiredMessage('market.country_codes') }),
  // Empty means the installation default rather than "no tax".
  tax_provider: z.string().optional(),
})

export type MarketFormValues = z.infer<typeof marketFormSchema>

// No currency: a new market takes the store's, and an edited one its own.
export const MARKET_DEFAULTS: DefaultValues<MarketFormValues> = {
  name: '',
  supported_locales: [],
  tax_inclusive: false,
  default: false,
  country_codes: [],
  tax_provider: '',
}

export function marketValuesToParams(v: MarketFormValues): MarketCreateParams & MarketUpdateParams {
  return {
    name: v.name,
    currency: v.currency,
    default_locale: v.default_locale,
    // The default locale is always implicitly included server-side; strip
    // duplicates here so the request stays compact.
    supported_locales: v.supported_locales.filter((l) => l !== v.default_locale),
    tax_inclusive: v.tax_inclusive,
    default: v.default,
    country_codes: v.country_codes,
    tax_provider: v.tax_provider || null,
  }
}
