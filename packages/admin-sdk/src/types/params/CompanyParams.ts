// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

export type CompanyParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  /** Required when creating. */
  name?: string
  /**
   * `company` is a legal entity (may hold tax registrations), `division` an organizational unit.
   * Roots must be `company`.
   */
  kind?: 'company' | 'division'
  /** The parent node. Omit or null for a root. */
  parent_id?: string | null
  /**
   * Whether this buyer's own procurement process demands a PO reference on every order: checkout
   * asks for one and refuses to complete without it.
   */
  po_number_required?: boolean
  metadata?: Record<string, unknown>
}
