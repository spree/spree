import { zodResolver } from '@hookform/resolvers/zod'
import { type Product, SpreeError, type Variant } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, PageHeader, Slot } from '@spree/dashboard-core'
import {
  ErrorState,
  FormActions,
  MetadataCard,
  ResourceLayout,
  Skeleton,
  StatusBadge,
  useConfirm,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import i18n from 'i18next'
import { useEffect } from 'react'
import { useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import {
  CustomFieldsInlineCard,
  FormBackedCustomFieldsProvider,
} from '../../../../components/spree/custom-fields/custom-fields-inline'
import {
  CategorizationCard,
  GeneralCard,
  InventoryCard,
  MediaCard,
  PricesCard,
  SEOCard,
  StatusCard,
  TaxCard,
  VariantsCard,
} from '../../../../components/spree/products/product-form-cards'
import { PublishingCard } from '../../../../components/spree/products/publishing-card'
import { ResourceTranslationsCard } from '../../../../components/spree/translations/resource-translations-card'
import { useDeleteProduct, useProduct, useUpdateProduct } from '../../../../hooks/use-product'
import { useProductMedia } from '../../../../hooks/use-product-media'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'
import {
  type ProductFormValues,
  productFormSchema,
  type VariantFormValues,
} from '../../../../schemas/product'

// Purchasable attributes (sku, barcode, prices, weight, dimensions, stock,
// track_inventory) live on variants in API v3. The product form no longer
// exposes top-level master fields; see docs/plans/6.0-remove-master-variant.md.

export const Route = createFileRoute('/_authenticated/$storeId/products/$productId')({
  component: ProductDetailPage,
})

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function variantToFormValues(variant: Variant, position: number): VariantFormValues {
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
    stock_items: (variant.stock_items ?? []).map((si) => ({
      id: si.id,
      stock_location_id: si.stock_location_id ?? si.stock_location?.id ?? '',
      stock_location_name:
        si.stock_location?.name ?? i18n.t('admin.products.inventory.unknown_location'),
      count_on_hand: si.count_on_hand,
      backorderable: si.backorderable,
    })),
  }
}

function productToFormValues(
  product: Product,
  // Optional media list — passed in from useProductMedia (which is a separate
  // query). When provided we hydrate form.media here so the form.reset cycle
  // captures it atomically instead of via a follow-up setValue that races
  // with the merchant's unsaved edits.
  media?: Array<{
    id: string
    alt: string | null
    position: number | null
    variant_ids: string[] | null
    small_url: string | null
    mini_url: string | null
    original_url: string | null
  }>,
): ProductFormValues {
  const hasVariants = (product.variant_count ?? 0) > 0
  const variantSource = hasVariants
    ? (product.variants ?? [])
    : product.default_variant
      ? [product.default_variant]
      : []

  return {
    name: product.name,
    description: product.description ?? '',
    status: (product.status as ProductFormValues['status']) ?? 'draft',
    category_ids: product.categories?.map((t) => t.id) ?? [],
    tags: product.tags ?? [],
    tax_category_id: product.tax_category_id ?? null,
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
    media:
      media?.map((m, i) => ({
        id: m.id,
        alt: m.alt ?? null,
        position: m.position ?? i + 1,
        variant_ids: m.variant_ids ?? [],
        previewUrl: m.small_url ?? m.mini_url ?? m.original_url ?? undefined,
      })) ?? [],
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
  if (v.stock_items?.length) {
    payload.stock_items = v.stock_items.map(({ stock_location_name, ...rest }) => rest)
  }
  return payload
}

export { productToFormValues }

// ---------------------------------------------------------------------------
// Page
// ---------------------------------------------------------------------------

function ProductDetailPage() {
  const { t } = useTranslation()
  const { productId } = Route.useParams()
  const { data: product, isLoading, error, refetch } = useProduct(productId)

  if (isLoading) return <ProductSkeleton />
  if (error || !product) {
    return (
      <ErrorState
        title={t('admin.errors.failed_to_load_product')}
        error={error as Error | undefined}
        onRetry={() => refetch()}
      />
    )
  }

  return <ProductForm product={product as Product} />
}

// ---------------------------------------------------------------------------
// Form
// ---------------------------------------------------------------------------

function ProductForm({ product }: { product: Product }) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { productId, storeId } = Route.useParams()
  const router = useRouter()
  const updateProduct = useUpdateProduct()
  const deleteProduct = useDeleteProduct()
  const { data: mediaResponse } = useProductMedia(productId)

  const mediaItems = mediaResponse?.data

  const form = useForm<ProductFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productFormSchema) as any,
    defaultValues: productToFormValues(product, mediaItems),
  })

  // Variants the MediaCard can assign uploaded images to. Only server-persisted
  // variants have an `id` that can ride media[].variant_ids on the PATCH, so we
  // start from `product.variants`. But the merchant may have queued one of those
  // for deletion in the current session (matrix Trash button) — drop those by
  // intersecting against the live form `variants` ids. Newly-added variants
  // without a server id are unassignable until save (no id to send).
  const liveVariants = useWatch({ control: form.control, name: 'variants' })
  const liveVariantIds = new Set(
    (liveVariants ?? []).map((v) => v.id).filter((id): id is string => !!id),
  )
  const assignableVariants = (product.variants ?? []).filter((v) => liveVariantIds.has(v.id))

  // Reset the form whenever the source data changes — product itself (PATCH
  // refetch) and media (separate query). Both queries invalidate on save so
  // the reset cycle naturally re-hydrates with persisted state.
  //
  // Skip the reset if the form is currently dirty: a background refetch
  // (window focus, query invalidation triggered by an unrelated mutation
  // like deleting a media item) would otherwise overwrite the merchant's
  // unsaved edits. After the save round-trip itself, RHF's submission
  // already cleared isDirty, so the post-save refetch still re-hydrates.
  useEffect(() => {
    if (form.formState.isDirty) return
    form.reset(productToFormValues(product, mediaItems))
  }, [product, mediaItems, form])

  // Media-only hydration that bypasses the isDirty guard for the
  // already-empty case. Scenario: page mounts with mediaResponse still
  // in flight → form.media is `[]` baseline → merchant edits a different
  // card (status, name, etc.) → isDirty flips true → mediaResponse
  // resolves → main effect skips the reset → form.media stays `[]`
  // permanently, so the MediaCard renders blank even though the product
  // has assets. Fix: when mediaItems arrives AND form.media is still
  // empty AND nothing the merchant did has dirtied the media field, paint
  // the persisted assets in. `shouldDirty: false` so we don't flip dirty.
  useEffect(() => {
    if (!mediaItems || mediaItems.length === 0) return
    const current = form.getValues('media') ?? []
    if (current.length > 0) return
    if (form.formState.dirtyFields?.media) return
    form.setValue(
      'media',
      mediaItems.map((m, i) => ({
        id: m.id,
        alt: m.alt ?? null,
        position: m.position ?? i + 1,
        variant_ids: m.variant_ids ?? [],
        previewUrl: m.small_url ?? m.mini_url ?? m.original_url ?? undefined,
      })),
      { shouldDirty: false },
    )
  }, [mediaItems, form])

  const onSubmit = async (data: ProductFormValues) => {
    const { variants, media, ...rest } = data
    const payload: Record<string, unknown> = { ...rest }

    if (variants && variants.length > 0) {
      payload.variants = variants.map((v, i) => variantToWirePayload(v, i))
    }

    // Strip UI-only fields and ship media inline. The server upserts by id
    // (alt/position/variant_ids), creates new entries from signed_id, and
    // leaves omitted persisted items alone — deletes still go through the
    // dedicated DELETE /media endpoint, which the MediaCard already calls
    // before removing an entry from form state.
    if (media && media.length > 0) {
      payload.media = media.map(({ previewUrl, uploadId, ...rest }, i) => ({
        ...rest,
        position: i + 1,
      }))
    }

    try {
      await updateProduct.mutateAsync({ id: productId, ...payload })
      // Re-baseline the form to the just-submitted values so isDirty flips
      // to false BEFORE the post-save refetch lands. The dirty-skip in the
      // hydration effect would otherwise keep isDirty true forever (since
      // we then skip the refetch's reset).
      //
      // Strip `signed_id` and the UI-only fields from baseline media so a
      // subsequent save before the mediaResponse refetch lands can't re-ship
      // the same signed_id and create a duplicate Asset. The persisted media
      // ids will hydrate on the next refetch.
      const baseline: ProductFormValues = {
        ...data,
        media: (data.media ?? []).map(
          ({ signed_id: _sid, previewUrl: _p, uploadId: _u, ...rest }) => rest,
        ),
      }
      form.reset(baseline)
      toast.success(t('admin.messages.product_saved'))
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(t('admin.errors.failed_to_save'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

  const handleDelete = async () => {
    const confirmed = await confirm({
      message: t('admin.products.delete_confirm'),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!confirmed) return
    try {
      await deleteProduct.mutateAsync(productId)
      toast.success(t('admin.messages.product_deleted'))
      await router.navigate({
        to: '/$storeId/products',
        params: { storeId },
        search: { filters: [], columns: [] },
      })
    } catch {
      toast.error(t('admin.errors.failed_to_delete'))
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      {form.formState.errors.root?.message && (
        <p className="text-sm text-destructive" role="alert">
          {form.formState.errors.root.message}
        </p>
      )}
      <ResourceLayout
        header={
          <PageHeader
            title={product.name}
            backTo="products"
            badges={<StatusBadge status={product.status} />}
            actions={<FormActions form={form} saveLabel={t('admin.products.save_label')} />}
            resource={{ id: product.id }}
            onDelete={handleDelete}
            deleteLabel={t('admin.products.delete_label')}
            jsonPreview={{
              title: `Product ${product.name}`,
              fetch: () => adminClient.products.get(productId),
              endpoint: `/api/v3/admin/products/${productId}`,
              resolveLink: spreeJsonLinkResolver(storeId),
            }}
          />
        }
        main={
          <>
            <GeneralCard form={form} />
            <VariantsCard form={form} />
            <MediaCard productId={productId} variants={assignableVariants} form={form} />
            <PricesCard form={form} productName={product.name} />
            <InventoryCard form={form} storeId={storeId} />
            <FormBackedCustomFieldsProvider form={form} resourceType="Spree::Product">
              <CustomFieldsInlineCard />
            </FormBackedCustomFieldsProvider>
            <ResourceTranslationsCard resourceType="product" resourceId={productId} />
            <MetadataCard
              metadata={product.metadata}
              title={t('admin.components.metadata_card.title')}
              emptyTitle={t('admin.components.metadata_card.empty_title')}
              emptyDescription={t('admin.components.metadata_card.empty_description')}
            />
          </>
        }
        sidebar={
          <>
            <StatusCard form={form} />
            <PublishingCard form={form} />
            <CategorizationCard form={form} />
            <TaxCard form={form} />
            <SEOCard form={form} product={product} />
            <Slot name="product.form_sidebar" context={{ product }} />
          </>
        }
      />
    </form>
  )
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function ProductSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      <div className="flex items-center gap-3">
        <Skeleton className="size-8 rounded-lg" />
        <Skeleton className="h-8 w-48" />
        <Skeleton className="h-5 w-16 rounded-md" />
        <div className="ml-auto flex items-center gap-2">
          <Skeleton className="h-8 w-20 rounded-lg" />
          <Skeleton className="h-8 w-16 rounded-lg" />
        </div>
      </div>
      <div className="grid grid-cols-12 gap-6">
        <div className="col-span-12 lg:col-span-8 flex flex-col gap-6">
          <Skeleton className="h-72 w-full rounded-xl" />
          <Skeleton className="h-48 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-52 w-full rounded-xl" />
        </div>
        <div className="col-span-12 lg:col-span-4 flex flex-col gap-6">
          <Skeleton className="h-56 w-full rounded-xl" />
          <Skeleton className="h-40 w-full rounded-xl" />
          <Skeleton className="h-52 w-full rounded-xl" />
          <Skeleton className="h-24 w-full rounded-xl" />
        </div>
      </div>
    </div>
  )
}
