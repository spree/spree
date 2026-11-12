// This file is auto-generated from the request schemas in docs/api-reference by `pnpm generate:params`. Do not edit directly.

import type { ProductTypeCustomFieldDefinitionParams } from './ProductTypeCustomFieldDefinitionParams'

export type ProductTypeCreateParams = {
  name: string
  /**
   * Delivery profile stamped onto products created with this type. Null leaves new products on the
   * store default profile.
   */
  delivery_profile_id?: string | null
  /**
   * Option types seeded onto products that get this type. Use apply to products to backfill
   * existing ones.
   */
  option_type_ids?: string[]
  /**
   * Categories seeded onto products that get this type. Categories from other stores are ignored.
   */
  category_ids?: string[]
  /**
   * The custom field definitions the product form shows. Definitions not listed are removed from
   * the type.
   */
  custom_field_definitions?: ProductTypeCustomFieldDefinitionParams[]
}
