import { CurrencyCode } from '@spree/admin-sdk'

/**
 * Every currency code Spree accepts. Used for contexts where the merchant can
 * pick *any* currency (a market's currency) rather than one the store already
 * supports.
 */
export const ALL_CURRENCY_CODES: readonly CurrencyCode[] = Object.values(CurrencyCode)
