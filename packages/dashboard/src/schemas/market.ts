import type { MarketCreateParams, MarketUpdateParams } from '@spree/admin-sdk'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const marketFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  currency: z.string().min(1, { error: requiredMessage('market.currency') }),
  default_locale: z.string().min(1, { error: requiredMessage('market.default_locale') }),
  supported_locales: z.array(z.string()),
  tax_inclusive: z.boolean(),
  default: z.boolean(),
  country_isos: z.array(z.string()).min(1, { error: requiredMessage('market.country_isos') }),
})

export type MarketFormValues = z.infer<typeof marketFormSchema>

export const MARKET_DEFAULTS: MarketFormValues = {
  name: '',
  currency: '',
  default_locale: '',
  supported_locales: [],
  tax_inclusive: false,
  default: false,
  country_isos: [],
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
    country_isos: v.country_isos,
  }
}
