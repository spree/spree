// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CurrencyCode } from '../generated'

export type CustomerStoreCreditCreateParams = {
  amount: string
  currency: CurrencyCode
  memo?: string
}
