import { zodResolver } from '@hookform/resolvers/zod'
import { type Product, SpreeError } from '@spree/admin-sdk'
import {
  adminClient,
  CategorizationCard,
  extensionFormValues,
  extensionSubmitValues,
  GeneralCard,
  InventoryCard,
  MediaCard,
  mapSpreeErrorsToForm,
  mediaToFormValues,
  PageHeader,
  PricesCard,
  type ProductFormValues,
  productFormSchema,
  productToFormValues,
  SEOCard,
  Slot,
  StatusCard,
  TaxCard,
  VariantsCard,
  variantToWirePayload,
} from '@spree/dashboard-core'
import {
  ErrorState,
  FormActions,
  MetadataCard,
  ResourceLayout,
  Skeleton,
  StatusBadge,
  toastManager,
  useConfirm,
  useFormSubmitShortcut,
} from '@spree/dashboard-ui'
import { createFileRoute, useRouter } from '@tanstack/react-router'
import { useEffect } from 'react'
import { FormProvider, useForm, useWatch } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CustomFieldsInlineCard } from '../../../../components/spree/custom-fields/custom-fields-inline'
import { MediaRichTextEditor } from '../../../../components/spree/media-rich-text-editor'
import { DigitalAssetsCard } from '../../../../components/spree/products/digital-assets-card'
import { ProductCustomFieldsProvider } from '../../../../components/spree/products/product-custom-fields-provider'
import { ProductReviewActions } from '../../../../components/spree/products/product-review-actions'
import { ProductSellerCard } from '../../../../components/spree/products/product-seller-card'
import { PublishingCard } from '../../../../components/spree/products/publishing-card'
import { ResourceTranslationsCard } from '../../../../components/spree/translations/resource-translations-card'
import { useDeleteProduct, useProduct, useUpdateProduct } from '../../../../hooks/use-product'
import { useProductMedia } from '../../../../hooks/use-product-media'
import { spreeJsonLinkResolver } from '../../../../lib/json-link-resolver'

// Purchasable attributes (sku, barcode, prices, weight, dimensions, stock,
// track_inventory) live on variants in API v3. The product form no longer
// exposes top-level master fields; see docs/plans/6.0-remove-master-variant.md.

export const Route = createFileRoute('/_authenticated/$storeId/products/$productId')({
  component: ProductDetailPage,
})

// ---------------------------------------------------------------------------
// Helpers
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
    // Extension form values ride along: fields registered via
    // `formFields.register('product', …)` hydrate from the fetched product
    // and flow into the PATCH payload through the loose schema.
    defaultValues: {
      ...productToFormValues(product, mediaItems),
      ...extensionFormValues('product', product),
    },
  })

  const selectedProductTypeId = form.watch('product_type_id')

  // Variants the MediaCard can assign uploaded images to. Only server-persisted
  // variants have an `id` that can ride media[].variant_ids on the PATCH, so we
  // start from `product.variants`. But the merchant may have queued one of those
  // for deletion in the current session (matrix Trash button) — drop those by
  // intersecting against the live form `variants` ids. Newly-added variants
  // without a server id are unassignable until save (no id to send).
  const liveVariants = useWatch({ control: form.control, name: 'variants' })
  const formStatus = useWatch({ control: form.control, name: 'status' }) ?? product?.status
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
    form.reset({
      ...productToFormValues(product, mediaItems),
      ...extensionFormValues('product', product),
    })
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
    form.setValue('media', mediaItems.map(mediaToFormValues), { shouldDirty: false })
  }, [mediaItems, form])

  const onSubmit = async (data: ProductFormValues) => {
    const { variants, media, ...rest } = data
    // Extension fields come from live form state: the Zod parse behind
    // `data` strips keys the first-party schema doesn't know.
    const extensionValues = extensionSubmitValues('product', form)
    // `description` rides through as HTML — the editor's output is what the
    // column stores; the API reads it back as plain text plus `description_html`.
    const payload: Record<string, unknown> = { ...rest, ...extensionValues }

    if (variants && variants.length > 0) {
      payload.variants = variants.map((v, i) => variantToWirePayload(v, i))
    }

    // Strip UI-only fields and ship media inline. The server upserts by id
    // (alt/position/variant_ids), creates new entries from signed_id, and
    // leaves omitted persisted items alone — deletes still go through the
    // dedicated DELETE /media endpoint, which the MediaCard already calls
    // before removing an entry from form state.
    if (media && media.length > 0) {
      payload.media = media.map(
        (
          { previewUrl, fullPreviewUrl, posterUrl, videoUrl, downloadUrl, uploadId, ...rest },
          i,
        ) => ({
          ...rest,
          position: i + 1,
        }),
      )
    }

    try {
      await updateProduct.mutateAsync({ id: productId, ...payload })
      // Re-baseline the form to the just-submitted values so isDirty flips
      // to false BEFORE the post-save refetch lands. The dirty-skip in the
      // hydration effect would otherwise keep isDirty true forever (since
      // we then skip the refetch's reset).
      //
      // Strip the file-transport keys and the UI-only fields from baseline
      // media so a subsequent save before the mediaResponse refetch lands
      // can't re-ship them and create a duplicate Asset — `signed_id` would
      // re-attach the upload, `source_media_id` would place the library file a
      // second time. The persisted media ids hydrate on the next refetch.
      const baseline: ProductFormValues = {
        ...data,
        // `data` is the parsed (extension-stripped) shape — put extension
        // values back so the reset doesn't blank their inputs pre-refetch.
        ...extensionValues,
        media: (data.media ?? []).map(
          ({
            signed_id: _sid,
            source_media_id: _smid,
            poster_signed_id: _psid,
            previewUrl: _p,
            fullPreviewUrl: _fp,
            posterUrl: _pu,
            videoUrl: _vu,
            downloadUrl: _du,
            uploadId: _u,
            ...rest
          }) => rest,
        ),
      }
      form.reset(baseline)
      toastManager.add({ type: 'success', title: t('admin.messages.product_saved') })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
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
      toastManager.add({ type: 'success', title: t('admin.messages.product_deleted') })
      await router.navigate({
        to: '/$storeId/products',
        params: { storeId },
        search: { filters: [], columns: [] },
      })
    } catch {
      toastManager.add({ type: 'error', title: t('admin.errors.failed_to_delete') })
    }
  }

  return (
    // FormProvider exposes the form to slot widgets: a `product.form_sidebar`
    // extension binds inputs via `useHostForm()` and they persist through
    // this form's Save — no widget-owned save cycle.
    <FormProvider {...form}>
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
              <GeneralCard form={form} descriptionEditor={MediaRichTextEditor} />
              <VariantsCard form={form} />
              <MediaCard productId={productId} variants={assignableVariants} form={form} />
              <PricesCard form={form} productName={product.name} />
              <InventoryCard
                form={form}
                stockLocationHref={(id) =>
                  `/${storeId}/settings/stock-locations?edit=${encodeURIComponent(id)}`
                }
              />
              <DigitalAssetsCard productId={productId} variants={assignableVariants} />
              <ProductCustomFieldsProvider form={form} productTypeId={selectedProductTypeId}>
                <CustomFieldsInlineCard />
              </ProductCustomFieldsProvider>
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
              <ProductSellerCard product={product} />
              <StatusCard
                form={form}
                reviewActions={
                  // The form's status, not the record's: StatusCard decides
                  // whether to render these from the same value, and reading
                  // a different one left the buttons up against a product
                  // that had already been approved.
                  <ProductReviewActions productId={productId} status={formStatus ?? ''} />
                }
              />
              <PublishingCard form={form} />
              <CategorizationCard form={form} />
              <TaxCard form={form} />
              <SEOCard form={form} product={product} />
              <Slot name="product.form_sidebar" context={{ product }} />
            </>
          }
        />
      </form>
    </FormProvider>
  )
}

// ---------------------------------------------------------------------------
// Loading skeleton
// ---------------------------------------------------------------------------

function ProductSkeleton() {
  return (
    <div className="flex flex-col gap-6">
      {/* Mirrors PageHeader: the name on its own line, the status below it. */}
      <div className="flex items-start gap-3">
        <Skeleton className="size-8 shrink-0 rounded-lg" />
        <div className="flex flex-col gap-1">
          <Skeleton className="h-8 w-48" />
          <Skeleton className="h-5 w-20 rounded-md" />
        </div>
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
