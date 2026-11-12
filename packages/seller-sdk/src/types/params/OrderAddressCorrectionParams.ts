// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { OrderAddressParams } from './OrderAddressParams'

export type OrderAddressCorrectionParams = {
  /** Only the lines that change; the rest of the address is carried over. */
  shipping_address?: OrderAddressParams
  /** Only the lines that change; the rest of the address is carried over. */
  billing_address?: OrderAddressParams
}
