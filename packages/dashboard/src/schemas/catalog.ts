import type { CatalogParams } from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import type { ProductMembershipStagingValue } from '../components/spree/product-membership-staging'

/** Validation for the catalog create sheet and settings card. */
export const catalogFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  /**
   * Staged product membership, applied on Save through the nested products
   * endpoints. Opaque by design — it holds SDK `Product` records so a staged
   * addition can render before it exists server-side, and RHF's `Path<T>`
   * must not walk that object graph. Never sent to the API;
   * `catalogValuesToParams` drops it.
   */
  staged_products: z.custom<ProductMembershipStagingValue>(() => true),
  active: z.boolean(),
  // Empty string = assortment-only (base prices).
  price_list_id: z.string().optional(),
})

/** Values the catalog form holds. */
export type CatalogFormValues = z.infer<typeof catalogFormSchema>

/** A new catalog: named on create, active, priced by base prices. */
export const CATALOG_DEFAULTS: CatalogFormValues = {
  name: '',
  active: true,
  price_list_id: '',
  staged_products: { adds: [], removes: [] },
}

/**
 * Maps form values to the Admin API payload; a blank price list means
 * "no list", which leaves the catalog pricing through base prices.
 */
export function catalogValuesToParams(values: CatalogFormValues): CatalogParams {
  return {
    name: values.name,
    active: values.active,
    price_list_id: blankToNull(values.price_list_id),
  }
}
