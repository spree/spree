// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { VariantOptionParams } from './VariantOptionParams'
import type { VariantParams } from './VariantParams'

export type VariantUpdateParams = VariantParams & {
  /**
   * One pair per option type the variant takes part in (size, color). Option types and values are
   * created when missing. On update, omit to leave the option values untouched.
   */
  options?: VariantOptionParams[]
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
}
