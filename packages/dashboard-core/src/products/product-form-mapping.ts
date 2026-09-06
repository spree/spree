import { i18n } from '../lib/i18n'
import { normalizeQuantityRule } from './normalize-quantity'
import type { MediaType, ProductFormValues, VariantFormValues } from './product-schema'
import type { PanelMedia, PanelProduct, PanelVariant } from './product-types'

/**
 * Between the API's shape and the form's.
 *
 * Shared by both panels for the same reason the cards are: the form is one
 * form, so what fills it and what it sends have to agree, and two copies of
 * this mapping would be two ways to disagree.
 */

export function variantToFormValues(variant: PanelVariant, position: number): VariantFormValues {
  return {
    id: variant.id,
    sku: variant.sku ?? null,
    barcode: variant.barcode ?? null,
    position,
    // Derive {name, value} pairs from option_values. The serializer carries
    // option_type_name on each OptionValue, so no extra expand is needed.
    options: (variant.option_values ?? []).map((ov) => ({
      name: ov.option_type_name,
      value: ov.name,
    })),
    weight: variant.weight ?? null,
    height: variant.height ?? null,
    width: variant.width ?? null,
    depth: variant.depth ?? null,
    weight_unit: variant.weight_unit ?? null,
    dimensions_unit: variant.dimensions_unit ?? null,
    hs_code: variant.hs_code ?? null,
    country_of_origin: variant.country_of_origin ?? null,
    customs_description: variant.customs_description ?? null,
    minimum_order_quantity: variant.minimum_order_quantity?.toString() ?? null,
    order_multiple: variant.order_multiple?.toString() ?? null,
    purchase_unit: variant.purchase_unit ?? null,
    units_per_carton: variant.units_per_carton?.toString() ?? null,
    track_inventory: variant.track_inventory,
    preorderable: variant.preorderable ?? false,
    preorder_ships_at: variant.preorder_ships_at ?? null,
    backorder_limit: variant.backorder_limit ?? null,
    tax_category_id: variant.tax_category_id ?? null,
    prices: (variant.prices ?? [])
      .filter((p) => p.currency != null)
      .map((p) => ({
        currency: p.currency as string,
        // Keep amounts as the canonical decimal strings the API returns.
        // The bulk price editor displays them with the locale's decimal
        // separator and ships the raw user input unchanged on submit;
        // `Spree::LocalizedNumber.parse` handles locale-aware parsing.
        amount: p.amount != null ? String(p.amount) : '',
        compare_at_amount: p.compare_at_amount != null ? String(p.compare_at_amount) : null,
      })),
    stock_levels: (variant.stock_levels ?? []).map((si) => ({
      id: si.id,
      stock_location_id: si.stock_location_id ?? si.stock_location?.id ?? '',
      stock_location_name:
        si.stock_location?.name ?? i18n.t('admin.products.inventory.unknown_location'),
      count_on_hand: si.count_on_hand,
      backorderable: si.backorderable,
    })),
  }
}

// One mapping for both hydration paths (the form reset and the media-only
// late paint) so a new media field can't reach one and miss the other.
// Takes the generated SDK type rather than a hand-listed shape, so a field
// added to the serializer can't quietly go missing here.
export function mediaToFormValues(media: PanelMedia, index: number) {
  return {
    id: media.id,
    alt: media.alt ?? null,
    position: media.position ?? index + 1,
    variant_ids: media.variant_ids ?? [],
    media_type: (media.media_type ?? 'image') as MediaType,
    external_video_url: media.external_video_url ?? null,
    focal_point_x: media.focal_point_x ?? null,
    focal_point_y: media.focal_point_y ?? null,
    // Video rows have no image of their own, so the poster is the preview.
    previewUrl:
      media.small_url ?? media.mini_url ?? media.poster_url ?? media.original_url ?? undefined,
    // Only the square renditions: the focal point is picked against the
    // rendered box, and original_url is uncropped, so mixing them in would
    // move the point the merchant set.
    fullPreviewUrl: media.large_url ?? media.xlarge_url ?? media.poster_url ?? null,
    posterUrl: media.poster_url,
    // The file itself, so an uploaded video can actually play. Every sized URL
    // on a video row resolves to its poster, so none of them work here.
    videoUrl: media.video_url,
    downloadUrl: media.download_url,
  }
}

export function productToFormValues(
  product: PanelProduct,
  // Optional media list — passed in from useProductMedia (which is a separate
  // query). When provided we hydrate form.media here so the form.reset cycle
  // captures it atomically instead of via a follow-up setValue that races
  // with the merchant's unsaved edits.
  media?: PanelMedia[],
): ProductFormValues {
  const hasVariants = (product.variant_count ?? 0) > 0
  const variantSource = hasVariants
    ? (product.variants ?? [])
    : product.default_variant
      ? [product.default_variant]
      : []

  return {
    name: product.name,
    // Hydrate the Tiptap editor from the HTML field, not `description` — the
    // serializer squishes that one to tag-stripped plain text, which would
    // collapse paragraphs/line breaks on every reload. Writes send the editor's
    // HTML back under the plain `description` param.
    description: product.description_html ?? '',
    status: (product.status as ProductFormValues['status']) ?? 'draft',
    open_to_sellers: product.open_to_sellers ?? false,
    category_ids: product.categories?.map((category) => category.id) ?? product.category_ids ?? [],
    // Manual membership only — this field is what the picker edits, and the
    // API preserves automatic membership regardless of what it sends. Hydrating
    // automatic collections here would render chips a merchant can remove to
    // no effect.
    collection_ids:
      product.collections?.filter((collection) => !collection.automatic).map((c) => c.id) ??
      product.collection_ids ??
      [],
    tags: product.tags ?? [],
    tax_category_id: product.tax_category_id ?? null,
    product_type_id: product.product_type_id ?? null,
    delivery_profile_id: product.delivery_profile_id ?? null,
    meta_title: product.meta_title ?? '',
    meta_description: product.meta_description ?? '',
    slug: product.slug ?? '',
    variants: variantSource.map((v, i) => variantToFormValues(v, i)),
    custom_fields:
      product.custom_fields?.map((cf) => ({
        id: cf.id,
        custom_field_definition_id: cf.custom_field_definition_id,
        value: cf.value,
      })) ?? [],
    media: media?.map(mediaToFormValues) ?? [],
    product_publications: (product.product_publications ?? []).map((l) => ({
      id: l.id,
      channel_id: l.channel_id,
      published_at: l.published_at ?? null,
      unpublished_at: l.unpublished_at ?? null,
    })),
  }
}

// Strip UI-only fields (stock_location_name) and undefined entries so the
// PATCH body matches the Admin API VariantUpdateParams shape exactly. The
// Spree::Product#variants= setter reconciles by id, creates new entries,
// and removes any persisted variant not present in the array — see
// docs/plans/6.0-remove-master-variant.md.
//
// `index` is the variant's array position; we ship `index + 1` so
// `acts_as_list` persists the 1-indexed order. Form state stays 0-indexed
// (matches the React array), the API quirk lives only at this boundary.
export function variantToWirePayload(v: VariantFormValues, index: number) {
  // DB columns `sku` and `weight` are NOT NULL with defaults ("", 0.0).
  // The other scalar fields (barcode, dimensions, weight_unit,
  // dimensions_unit, tax_category_id) ARE nullable — those we always send
  // even when null so the merchant can clear them. NOT-NULL fields fall
  // back to their schema defaults when blank.
  const payload: Record<string, unknown> = {
    position: index + 1,
    options: v.options,
    sku: v.sku ?? '',
    weight: v.weight ?? 0,
    barcode: v.barcode ?? null,
    height: v.height ?? null,
    width: v.width ?? null,
    depth: v.depth ?? null,
    weight_unit: v.weight_unit ?? null,
    dimensions_unit: v.dimensions_unit ?? null,
    tax_category_id: v.tax_category_id ?? null,
    hs_code: v.hs_code ?? null,
    country_of_origin: v.country_of_origin ?? null,
    customs_description: v.customs_description ?? null,
    minimum_order_quantity: normalizeQuantityRule(v.minimum_order_quantity),
    order_multiple: normalizeQuantityRule(v.order_multiple),
    purchase_unit: v.purchase_unit ?? null,
    units_per_carton: normalizeQuantityRule(v.units_per_carton),
  }
  if (v.id) payload.id = v.id
  if (v.track_inventory != null) payload.track_inventory = v.track_inventory
  if (v.preorderable != null) payload.preorderable = v.preorderable
  if (v.preorder_ships_at !== undefined) payload.preorder_ships_at = v.preorder_ships_at
  if (v.backorder_limit !== undefined) payload.backorder_limit = v.backorder_limit
  // Always send `prices` when the form tracks it — including `[]`. The
  // backend's `Spree::Variant#prices=` treats an empty array as "clear all
  // base prices"; omitting it would otherwise leave the old amounts in
  // place when the merchant clears the last currency from the matrix.
  //
  // Amounts in form state are already canonical `"1234.56"` — the price editor
  // normalizes the merchant's localized input on commit (see
  // `ProductBulkPriceEditor#handleChange`), and untouched values hydrate from
  // the canonical API. So no normalization here — re-normalizing a canonical
  // value under a comma-decimal locale would mangle it (`34.56` → `3456`).
  if (v.prices != null) payload.prices = v.prices
  if (v.stock_levels?.length) {
    payload.stock_levels = v.stock_levels.map(({ stock_location_name, ...rest }) => rest)
  }
  return payload
}
