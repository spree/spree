import type { MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const TAX_DISPLAYS = ['included', 'dynamic'] as const

export const marketFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  currency: z.string().min(1, { error: requiredMessage('market.currency') }),
  default_locale: z.string().min(1, { error: requiredMessage('market.default_locale') }),
  supported_locales: z.array(z.string()),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  country_codes: z.array(z.string()).min(1, { error: requiredMessage('market.country_codes') }),
  // Empty means the installation default rather than "no tax".
  tax_provider: z.string().optional(),
  tax_display: z.enum(TAX_DISPLAYS),
  // Empty means the first of the market's countries by name.
  default_country_code: z.string(),
})

export type MarketFormValues = z.infer<typeof marketFormSchema>

export const MARKET_DEFAULTS: MarketFormValues = {
  name: '',
  currency: '',
  default_locale: '',
  supported_locales: [],
  tax_inclusive: false,
  default: false,
  country_codes: [],
  tax_provider: '',
  tax_display: 'included',
  default_country_code: '',
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
    tax_display: v.tax_display,
    default_country_code: v.default_country_code || null,
  }
}
