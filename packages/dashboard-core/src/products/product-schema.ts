import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'
import { isSupportedVideoUrl } from './video-url'

export const stockLevelFormSchema = z.object({
  id: z.string().optional(),
  stock_location_id: z.string(),
  stock_location_name: z.string().optional(),
  count_on_hand: z.coerce.number().int(),
  backorderable: z.boolean(),
})

export type StockLevelFormValues = z.infer<typeof stockLevelFormSchema>

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
  hs_code: z.string().nullable().optional(),
  country_of_origin: z.string().nullable().optional(),
  customs_description: z.string().nullable().optional(),
  minimum_order_quantity: z.number().int().positive().nullable().optional(),
  order_multiple: z.number().int().positive().nullable().optional(),
  purchase_unit: z.string().nullable().optional(),
  units_per_carton: z.number().int().positive().nullable().optional(),
  track_inventory: z.boolean().optional(),
  preorderable: z.boolean().optional(),
  preorder_ships_at: z.string().nullable().optional(),
  backorder_limit: z.coerce.number().int().nonnegative().nullable().optional(),
  tax_category_id: z.string().nullable().optional(),
  prices: z.array(variantPriceFormSchema).optional(),
  stock_levels: z.array(stockLevelFormSchema).optional(),
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

// Media in form state. Persisted entries carry an `id`; pre-save entries carry
// a `signed_id` (from a completed ActiveStorage direct upload) or a
// `source_media_id` (a file picked from the library). All can hold edits to
// alt, position, and variant_ids that the parent product PATCH/POST ships
// inline. previewUrl + uploadId are UI-only; stripped at submit.
export const MEDIA_TYPES = ['image', 'video', 'external_video'] as const

export type MediaType = (typeof MEDIA_TYPES)[number]

export const mediaFormSchema = z
  .object({
    id: z.string().optional(),
    signed_id: z.string().optional(),
    // A file picked from the library. The save places a copy sharing the
    // source's file rather than uploading a second one.
    source_media_id: z.string().optional(),
    alt: z.string().nullable().optional(),
    position: z.number().int().nonnegative().optional(),
    variant_ids: z.array(z.string()).optional(),
    media_type: z.enum(MEDIA_TYPES).optional(),
    external_video_url: z.string().nullable().optional(),
    // A video's still frame. Sent as a signed id like the media file itself;
    // `posterUrl` is the UI-only preview and never reaches the API.
    poster_signed_id: z.string().optional(),
    posterUrl: z.string().nullable().optional(),
    // Playback source for an uploaded video. UI-only: a blob URL before save,
    // the served file after. Never sent back.
    videoUrl: z.string().nullable().optional(),
    focal_point_x: z.number().min(0).max(1).nullable().optional(),
    focal_point_y: z.number().min(0).max(1).nullable().optional(),
    // UI-only — strip at submit.
    previewUrl: z.string().optional(),
    // Larger rendition for the edit sheet; previewUrl is grid-sized and
    // visibly pixelates when blown up. Absent before save, where the blob URL
    // in previewUrl is full resolution anyway.
    fullPreviewUrl: z.string().nullable().optional(),
    // Server URL for downloading the original; absent until the row is saved.
    downloadUrl: z.string().nullable().optional(),
    uploadId: z.string().optional(),
  })
  // The server rejects a link it can't embed, and that failure aborts the whole
  // product save. Catch it here so the merchant sees it on the field instead.
  .refine(
    (media) =>
      media.media_type !== 'external_video' || isSupportedVideoUrl(media.external_video_url),
    { message: 'unsupported_video_provider', path: ['external_video_url'] },
  )

export type MediaFormValues = z.infer<typeof mediaFormSchema>

// A downloadable file staged on the new-product form. Create-time only: each
// entry is an upload (signed_id) buffered until the product POST. UI-only
// fields (filename, byteSize, uploadId) are stripped at submit.
export const digitalFileFormSchema = z.object({
  signed_id: z.string(),
  filename: z.string().nullable().optional(),
  byteSize: z.number().nullable().optional(),
  uploadId: z.string().optional(),
})

export type DigitalFileFormValues = z.infer<typeof digitalFileFormSchema>

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
  // Every status the API may answer, not just the ones a form sets. A
  // marketplace product also comes back `proposed` or `rejected`, and a schema
  // that rejects those makes the whole form unsavable rather than flagging a
  // field (docs/plans/6.0-seller-product-submission.md).
  status: z.enum(['draft', 'active', 'archived', 'proposed', 'rejected']).optional(),

  // Categorization
  category_ids: z.array(z.string()).optional(),
  collection_ids: z.array(z.string()).optional(),
  tags: z.array(z.string()).optional(),

  // Tax
  tax_category_id: z.string().nullable().optional(),

  // Product type — a creation-time template for the product's associations
  product_type_id: z.string().nullable().optional(),

  // Fulfillment profile — decides which zones and delivery methods reach this
  // product; null falls back to the store default profile.
  delivery_profile_id: z.string().nullable().optional(),

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
  // via Spree::HasCustomFields#custom_fields=). Partial updates: omitting a
  // definition leaves its value untouched.
  custom_fields: z.array(customFieldFormSchema).optional(),

  // Media. On the new product page this starts empty and accumulates
  // pre-save uploads (with signed_id). On the edit page it's hydrated from
  // the persisted assets (with id) so edits to alt/position/variant_ids and
  // new uploads ride the same product PATCH.
  media: z.array(mediaFormSchema).optional(),

  // Downloadable files, staged pre-save on the new product page and shipped in
  // the product POST. Edit uses the live API-driven card instead, so this stays
  // empty there.
  digital_assets: z.array(digitalFileFormSchema).optional(),

  product_publications: z.array(productPublicationFormSchema).optional(),
})

export type ProductFormValues = z.infer<typeof productFormSchema>

// Defaults for the "new product" page. Starts with a single placeholder
// variant (no options, empty stock_levels/prices) so the variants matrix
// renders a "Default variant" row the merchant can edit pre-save. On submit
// the page strips this row if it carries no meaningful data, letting
// Spree::Product#variants= auto-create the default variant server-side.
export function newProductFormDefaults(): ProductFormValues {
  return {
    name: '',
    description: '',
    status: 'draft',
    category_ids: [],
    collection_ids: [],
    tags: [],
    tax_category_id: null,
    product_type_id: null,
    delivery_profile_id: null,
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
        stock_levels: [],
      },
    ],
    custom_fields: [],
    media: [],
    digital_assets: [],
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
    (v.stock_levels ?? []).length === 0 &&
    v.weight == null &&
    v.height == null &&
    v.width == null &&
    v.depth == null &&
    v.weight_unit == null &&
    v.dimensions_unit == null &&
    v.tax_category_id == null &&
    !v.hs_code &&
    !v.country_of_origin &&
    !v.customs_description &&
    v.minimum_order_quantity == null &&
    v.order_multiple == null &&
    v.purchase_unit == null &&
    v.units_per_carton == null &&
    v.preorderable !== true &&
    v.preorder_ships_at == null &&
    v.backorder_limit == null &&
    // `track_inventory` defaults to `true` in `newProductFormDefaults`. Only
    // count an explicit `false` (merchant toggled it off) as non-default.
    v.track_inventory !== false
  )
}
