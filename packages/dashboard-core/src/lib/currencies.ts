import { CurrencyCode } from '@spree/admin-sdk'

// Replaced currencies Spree still accepts so orders priced in them stay
// valid, but which no merchant should pick for new pricing.
const RETIRED_CURRENCY_CODES: ReadonlySet<string> = new Set([
  'BYR',
  'CUC',
  'EEK',
  'HRK',
  'LTL',
  'LVL',
  'MRO',
  'MTL',
  'SKK',
  'SLL',
  'STD',
  'TMM',
  'VEF',
  'ZMK',
  'ZWD',
  'ZWL',
  'ZWN',
  'ZWR',
])

/**
 * Every currency Spree accepts that is still in use. Used for contexts where
 * the merchant can pick *any* currency (a market's currency) rather than one
 * the store already supports. The list ships with the SDK, so a currency a
 * newer server adds appears once the dashboard is upgraded with it.
 */
export const ALL_CURRENCY_CODES: readonly CurrencyCode[] = Object.values(CurrencyCode).filter(
  (code) => !RETIRED_CURRENCY_CODES.has(code),
)
