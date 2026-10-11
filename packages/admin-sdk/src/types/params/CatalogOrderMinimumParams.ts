// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type CatalogOrderMinimumParams = {
  /** ISO 4217 code. Required on create; one minimum per currency. */
  currency?: CurrencyCode
  amount?: string
}
