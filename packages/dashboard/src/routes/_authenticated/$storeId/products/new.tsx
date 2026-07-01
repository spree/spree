import { zodResolver } from '@hookform/resolvers/zod'
import { type ProductCreateParams, SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
import { FormActions, ResourceLayout, useFormSubmitShortcut } from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import {
  CustomFieldsInlineCard,
  FormBackedCustomFieldsProvider,
} from '@/components/spree/custom-fields/custom-fields-inline'
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
} from '@/components/spree/products/product-form-cards'
import { PublishingCard } from '@/components/spree/products/publishing-card'
import { useCreateProduct } from '@/hooks/use-product'
import {
  isPlaceholderDefaultVariant,
  newProductFormDefaults,
  type ProductFormValues,
  productFormSchema,
} from '@/schemas/product'
import { variantToWirePayload } from './$productId'

export const Route = createFileRoute('/_authenticated/$storeId/products/new')({
  component: NewProductPage,
})

function NewProductPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const create = useCreateProduct()

  const form = useForm<ProductFormValues>({
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    resolver: zodResolver(productFormSchema) as any,
    defaultValues: newProductFormDefaults(),
  })

  const onSubmit = async (data: ProductFormValues) => {
    const { variants, custom_fields, media, ...rest } = data

    // Strip the placeholder default variant if the merchant didn't touch it.
    // Spree::Product#variants= auto-creates the canonical default variant
    // server-side when none is provided. Any variant with options, SKU,
    // prices, or stock_items survives as merchant intent.
    const meaningful = (variants ?? []).filter((v) => !isPlaceholderDefaultVariant(v))

    const payload: ProductCreateParams = {
      ...(rest as ProductCreateParams),
    }
    // Only ship custom_fields when there are some — empty arrays are noise
    // and Spree::Metafields#custom_fields= already no-ops on empty input.
    if (custom_fields && custom_fields.length > 0) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(payload as any).custom_fields = custom_fields
    }

    // Pre-save media uploads: strip the UI-only fields and ship inline.
    // The server's Product#media= setter attaches each blob via signed_id
    // after the product is created (deferred to after_save).
    if (media && media.length > 0) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(payload as any).media = media.map(({ previewUrl, uploadId, ...rest }, i) => ({
        ...rest,
        position: i + 1,
      }))
    }

    // For simple products (single variant with no options) the merchant
    // doesn't realise the master variant exists. Two routes:
    //
    // - Prices only (no SKU/weight/dimensions/stock/track_inventory edits):
    //   lift to the product-level `prices` key. `Spree::Product#prices=`
    //   forwards to the master. Shipping a no-options variant inline
    //   alongside the auto-created master would create a duplicate
    //   non-master variant (apply_variants always builds a fresh variant
    //   for entries without an id).
    //
    // - Any variant-only data: ship the variant inline. The backend's
    //   `Product#variants=` builds a non-master variant carrying every
    //   field — including prices — so we MUST NOT also ship top-level
    //   `prices` (would double-record the price on both master and the
    //   inline variant).
    const isSingleOptionlessVariant = meaningful.length === 1 && meaningful[0].options.length === 0
    if (isSingleOptionlessVariant) {
      const v = meaningful[0]
      // Mirrors isPlaceholderDefaultVariant — any variant-only field the
      // merchant edited should ride inline so the backend's apply_variants
      // upserts onto the master rather than leaving the field at its
      // default.
      const hasVariantOnlyData =
        v.sku != null ||
        v.barcode != null ||
        v.weight != null ||
        v.height != null ||
        v.width != null ||
        v.depth != null ||
        v.weight_unit != null ||
        v.dimensions_unit != null ||
        v.tax_category_id != null ||
        v.track_inventory === false ||
        v.preorderable === true ||
        v.preorder_ships_at != null ||
        v.backorder_limit != null ||
        (v.stock_items?.length ?? 0) > 0
      if (hasVariantOnlyData) {
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ;(payload as any).variants = [variantToWirePayload(v, 0)]
      } else if (v.prices?.length) {
        // Top-level `prices` shorthand (simple product). Amounts are already
        // canonical — the price editor normalizes on commit.
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        ;(payload as any).prices = v.prices.filter((p) => p.currency != null)
      }
    } else if (meaningful.length > 0) {
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      ;(payload as any).variants = meaningful.map((v, i) => variantToWirePayload(v, i))
    }

    try {
      const product = await create.mutateAsync(payload)
      toast.success(t('admin.pages.products.new.create_succeeded'))
      // Replace history rather than pushing — otherwise the edit page's back
      // button lands the merchant back on the (now-stale) new product form.
      navigate({
        to: '/$storeId/products/$productId',
        params: { storeId, productId: product.id },
        replace: true,
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      if (err instanceof SpreeError) throw err
      toast.error(t('admin.pages.products.new.create_failed'))
    }
  }

  useFormSubmitShortcut(form, onSubmit)

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
            title={t('admin.pages.products.new.title')}
            subtitle={t('admin.pages.products.new.description')}
            backTo="products"
            actions={
              <FormActions form={form} saveLabel={t('admin.pages.products.new.save_label')} />
            }
          />
        }
        main={
          <>
            <GeneralCard form={form} />
            <VariantsCard form={form} />
            {/* Form-backed media uploader — files are uploaded to ActiveStorage
                pre-save and their signed_ids ride the product POST. */}
            <MediaCard form={form} />
            <PricesCard
              form={form}
              productName={form.watch('name') || t('admin.pages.products.new.title')}
            />
            <InventoryCard form={form} storeId={storeId} />
            <FormBackedCustomFieldsProvider form={form} resourceType="Spree::Product">
              <CustomFieldsInlineCard />
            </FormBackedCustomFieldsProvider>
          </>
        }
        sidebar={
          <>
            <StatusCard form={form} />
            <PublishingCard form={form} seedDefaultChannel />
            <CategorizationCard form={form} />
            <TaxCard form={form} />
            <SEOCard form={form} />
          </>
        }
      />
    </form>
  )
}
