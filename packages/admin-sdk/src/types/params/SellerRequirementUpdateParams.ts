// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type SellerRequirementUpdateParams = {
  /**
   * What the seller sees. Required for kinds that can be added more than once, since the wording is
   * the only thing telling them apart. Left blank on the others, the kind names itself.
   */
  name?: string
  /** Instructions shown to the seller. */
  description?: string
  /** Place in the checklist. */
  position?: number
  active?: boolean
  /** Whether this blocks approval. Off means recommended. */
  required?: boolean
  /** Configuration for this kind, per its type's `schema`. */
  preferences?: Record<string, unknown>
  metadata?: Record<string, unknown>
  /**
   * Custom field definitions this requirement asks the seller to fill in (`required_custom_fields`
   * kind).
   */
  custom_field_definition_ids?: string[]
}
