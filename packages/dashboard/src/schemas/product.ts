import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const stockItemFormSchema = z.object({
  id: z.string().optional(),
  stock_location_id: z.string(),
  stock_location_name: z.string().optional(),
  count_on_hand: z.coerce.number().int(),
  backorderable: z.boolean(),
})

export type StockItemFormValues = z.infer<typeof stockItemFormSchema>

export const variantOptionPairSchema = z.object({
  name: z.string().min(1),
  value: z.string().min(1),
})

export type VariantOptionPair = z.infer<typeof variantOptionPairSchema>

// Form-side prices use raw STRING amounts (the merchant's typed input).
// The backend's `Spree::LocalizedNumber.parse` handles locale-aware parsing
// (comma decimals, grouped digits, etc.), so the frontend ships exactly what
// the merchant typed — no `Number(...)` coercion that mangles `"1.234,56"`
// into `NaN` and silently drops the price.
export const variantPriceFormSchema = z.object({
  currency: z.string(),
  amount: z.string(),
  compare_at_amount: z.string().nullable().optional(),
})

export type VariantPriceFormValues = z.infer<typeof variantPriceFormSchema>

export const variantFormSchema = z.object({
  // Present for persisted variants. Omit for newly-generated rows so the
  // API can create them. Spree::Product#variants= reconciles by id.
  id: z.string().optional(),
  sku: z.string().nullable().optional(),
  barcode: z.string().nullable().optional(),
  position: z.number().int().nonnegative(),
  options: z.array(variantOptionPairSchema),
  weight: z.coerce.number().nullable().optional(),
  height: z.coerce.number().nullable().optional(),
  width: z.coerce.number().nullable().optional(),
  depth: z.coerce.number().nullable().optional(),
  weight_unit: z.string().nullable().optional(),
  dimensions_unit: z.string().nullable().optional(),
  track_inventory: z.boolean().optional(),
  preorderable: z.boolean().optional(),
  preorder_ships_at: z.string().nullable().optional(),
  tax_category_id: z.string().nullable().optional(),
  prices: z.array(variantPriceFormSchema).optional(),
  stock_items: z.array(stockItemFormSchema).optional(),
})

export type VariantFormValues = z.infer<typeof variantFormSchema>

export const customFieldFormSchema = z.object({
  // Prefixed id of an existing custom-field value. Present when hydrating a
  // persisted record so edits patch the existing row rather than insert.
  id: z.string().optional(),
  custom_field_definition_id: z.string(),
  value: z.unknown(),
})

export type CustomFieldFormValues = z.infer<typeof customFieldFormSchema>

// Media in form state. Persisted entries carry an `id`; pre-save entries
// carry a `signed_id` (from a completed ActiveStorage direct upload). Both
// can hold edits to alt, position, and variant_ids that the parent product
// PATCH/POST ships inline. previewUrl + uploadId are UI-only; stripped at
// submit.
export const mediaFormSchema = z.object({
  id: z.string().optional(),
  signed_id: z.string().optional(),
  alt: z.string().nullable().optional(),
  position: z.number().int().nonnegative().optional(),
  variant_ids: z.array(z.string()).optional(),
  // UI-only — strip at submit.
  previewUrl: z.string().optional(),
  uploadId: z.string().optional(),
})

export type MediaFormValues = z.infer<typeof mediaFormSchema>

export const productPublicationFormSchema = z.object({
  id: z.string().optional(),
  channel_id: z.string(),
  published_at: z.string().nullable().optional(),
  unpublished_at: z.string().nullable().optional(),
})

export type ProductPublicationFormValues = z.infer<typeof productPublicationFormSchema>

export const productFormSchema = z.object({
  // General
  name: z.string().min(1, { error: requiredMessage('name') }),
  description: z.string().optional(),

  // Status
  status: z.enum(['draft', 'active', 'archived']).optional(),

  // Categorization
  category_ids: z.array(z.string()).optional(),
  tags: z.array(z.string()).optional(),

  // Tax
  tax_category_id: z.string().nullable().optional(),

  // SEO
  meta_title: z.string().optional(),
  meta_description: z.string().optional(),
  slug: z.string().optional(),

  // Variants — the single source of truth for purchasable attributes.
  // Spree::Product#variants= matches by id, creates new entries, and
  // removes any persisted variant not present in the array. See
  // docs/plans/6.0-remove-master-variant.md for the wire contract.
  variants: z.array(variantFormSchema).optional(),

  // Inline custom field values, keyed by definition id (upserted server-side
  // via Spree::Metafields#custom_fields=). Partial updates: omitting a
  // definition leaves its value untouched.
  custom_fields: z.array(customFieldFormSchema).optional(),

  // Media. On the new product page this starts empty and accumulates
  // pre-save uploads (with signed_id). On the edit page it's hydrated from
  // the persisted assets (with id) so edits to alt/position/variant_ids and
  // new uploads ride the same product PATCH.
  media: z.array(mediaFormSchema).optional(),

  product_publications: z.array(productPublicationFormSchema).optional(),
})

export type ProductFormValues = z.infer<typeof productFormSchema>

// Defaults for the "new product" page. Starts with a single placeholder
// variant (no options, empty stock_items/prices) so the variants matrix
// renders a "Default variant" row the merchant can edit pre-save. On submit
// the page strips this row if it carries no meaningful data, letting
// Spree::Product#variants= auto-create the default variant server-side.
export function newProductFormDefaults(): ProductFormValues {
  return {
    name: '',
    description: '',
    status: 'draft',
    category_ids: [],
    tags: [],
    tax_category_id: null,
    meta_title: '',
    meta_description: '',
    slug: '',
    variants: [
      {
        sku: null,
        barcode: null,
        position: 0,
        options: [],
        weight: null,
        height: null,
        width: null,
        depth: null,
        weight_unit: null,
        dimensions_unit: null,
        track_inventory: true,
        tax_category_id: null,
        prices: [],
        stock_items: [],
      },
    ],
    custom_fields: [],
    media: [],
    product_publications: [],
  }
}

// Returns true if the given variant is essentially the empty default —
// no merchant-entered data on any variant-only field. Used by the create
// page to strip the placeholder variant so the backend auto-creates the
// canonical default variant.
//
// Stays in sync with `hasVariantOnlyData` in new.tsx — any field that
// makes the variant "meaningful" enough to ship inline must also count
// as "not a placeholder" here. Otherwise simple-product creates would
// filter the variant out before ever consulting hasVariantOnlyData.
export function isPlaceholderDefaultVariant(v: VariantFormValues): boolean {
  return (
    !v.id &&
    !v.sku &&
    !v.barcode &&
    v.options.length === 0 &&
    (v.prices ?? []).length === 0 &&
    (v.stock_items ?? []).length === 0 &&
    v.weight == null &&
    v.height == null &&
    v.width == null &&
    v.depth == null &&
    v.weight_unit == null &&
    v.dimensions_unit == null &&
    v.tax_category_id == null &&
    // `track_inventory` defaults to `true` in `newProductFormDefaults`. Only
    // count an explicit `false` (merchant toggled it off) as non-default.
    v.track_inventory !== false
  )
}
