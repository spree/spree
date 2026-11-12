// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { CustomFieldValueParams } from './CustomFieldValueParams'

export type CategoryCreateParams = {
  /**
   * Identities the record has in external systems, keyed by system: the same
   * `{ system: external_id }` map the Admin API renders, so what you read can be sent straight
   * back. Systems you do not name keep the reference they have. A list of `{ system, external_id }`
   * entries is accepted too.
   */
  external_references?: Record<string, unknown>
  name: string
  /**
   * The parent category. Omitted or null, a new category goes to the top level and an existing one
   * keeps its parent: moving one to the top level is the reposition endpoint.
   */
  parent_id?: string | null
  /** Rich text HTML. Reads come back as this (plain text) plus `description_html`. */
  description?: string
  permalink?: string
  meta_title?: string
  meta_description?: string
  meta_keywords?: string
  /** A `signed_id` from `files.upload()` for the landscape image, or null to remove it. */
  image_signed_id?: string | null
  /** A `signed_id` from `files.upload()` for the square image, or null to remove it. */
  square_image_signed_id?: string | null
  /** Custom field values, each validated against its definition. */
  custom_fields?: CustomFieldValueParams[]
}
