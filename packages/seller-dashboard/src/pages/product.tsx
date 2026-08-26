import { zodResolver } from '@hookform/resolvers/zod'
import {
  GeneralCard,
  InventoryCard,
  MediaCard,
  mapSpreeErrorsToForm,
  PageHeader,
  type PanelProduct,
  PricesCard,
  type ProductFormValues,
  productFormSchema,
  productToFormValues,
  VariantsCard,
  variantToWirePayload,
} from '@spree/dashboard-core'
import { FormActions, ResourceLayout, StatusBadge, toastManager } from '@spree/dashboard-ui'
import type { ProductParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useEffect } from 'react'
import { FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { ProductStatusCard } from '../components/product-status-card'
import { RetryableError } from '../components/retryable-error'

/** Everything the form edits, in one request. */
const PRODUCT_EXPAND = 'variants,media,default_variant'

/**
 * One product, created or edited.
 *
 * The same cards the operator's dashboard renders, in the same order, from
 * `@spree/dashboard-core` — the two forms are one form, and the differences
 * are only what a seller may not do. Publishing to channels and tax category
 * are absent because they are marketplace configuration, and status is not a
 * field here at all: a seller submits for review and the marketplace decides
 * (docs/plans/6.0-seller-product-submission.md).
 */
export function ProductPage({ mode }: { mode: 'new' | 'edit' }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const params = useParams({ strict: false }) as { productId?: string }
  const productId = mode === 'edit' ? params.productId : undefined
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const productKey = ['seller', sellerId, 'product', productId]
  const {
    data: product,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: productKey,
    queryFn: () => sellerClient().products.get(productId as string, PRODUCT_EXPAND),
    enabled: !!productId,
  })

  // The seller panel has no StoreProvider — its tenant is a seller and the
  // store is derived server-side — so the currencies the price cards need
  // come from the profile, which reports the store's.
  const { data: profile } = useQuery({
    queryKey: ['seller', sellerId, 'profile'],
    queryFn: () => sellerClient().profile.get(),
  })

  const form = useForm<ProductFormValues>({
    // Cast for the same reason the operator's form does: `z.coerce.number()`
    // infers `unknown` input, which the resolver's generic will not accept.
    resolver: zodResolver(productFormSchema) as any,
    defaultValues: productToFormValues({ id: '', name: '' }),
  })

  // Reset once the record arrives, so the inputs show what was last saved
  // rather than the blank defaults the form mounted with.
  useEffect(() => {
    if (!product) return

    form.reset(productToFormValues(product as PanelProduct, product.media))
  }, [product, form])

  const save = useMutation({
    mutationFn: (values: ProductFormValues) => {
      const payload: ProductParams = {
        name: values.name,
        description: values.description,
        slug: values.slug || undefined,
        meta_title: values.meta_title ?? undefined,
        meta_description: values.meta_description ?? undefined,
        // Both lists are the whole intent: anything the seller removed is
        // absent here, which is what tells the API to drop it.
        media: (values.media ?? []).map((item) => ({
          id: item.id,
          signed_id: item.signed_id ?? undefined,
          alt: item.alt ?? undefined,
          position: item.position,
          media_type: item.media_type,
          variant_ids: item.variant_ids,
        })),
        variants: (values.variants ?? []).map((variant, index) =>
          variantToWirePayload(variant, index),
        ) as ProductParams['variants'],
      }

      return productId
        ? sellerClient().products.update(productId, payload)
        : sellerClient().products.create(payload)
    },
    onSuccess: (saved) => {
      void queryClient.invalidateQueries({ queryKey: ['seller-products'] })
      queryClient.setQueryData(['seller', sellerId, 'product', saved.id], saved)
      toastManager.add({ type: 'success', title: t('products.saved') })
      if (!productId) {
        navigate({
          to: '/$sellerId/products/$productId',
          params: { sellerId, productId: saved.id },
        })
      }
    },
  })

  async function onSubmit(values: ProductFormValues) {
    try {
      await save.mutateAsync(values)
    } catch (err) {
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        toastManager.add({
          type: 'error',
          title: err instanceof Error ? err.message : t('common.error'),
        })
      }
    }
  }

  if (mode === 'edit' && isLoading) return <CenteredMessage>{t('common.loading')}</CenteredMessage>
  if (mode === 'edit' && isError) return <RetryableError onRetry={() => refetch()} />
  if (mode === 'edit' && !product)
    return <CenteredMessage>{t('products.not_found')}</CenteredMessage>

  return (
    <FormProvider {...form}>
      <form
        onSubmit={form.handleSubmit(onSubmit, (errors) => {
          // A schema rejection otherwise does nothing visible: the fields at
          // fault may be in a card the seller cannot see.
          toastManager.add({
            type: 'error',
            title: t('common.error'),
            description: Object.keys(errors).join(', '),
          })
        })}
      >
        {form.formState.errors.root?.message && (
          <p className="text-destructive text-sm" role="alert">
            {form.formState.errors.root.message}
          </p>
        )}
        <ResourceLayout
          header={
            <PageHeader
              title={product?.name ?? t('products.new_title')}
              backTo="products"
              badges={
                product?.status ? (
                  <StatusBadge
                    status={product.status}
                    label={t(`products.statuses.${product.status}`)}
                  />
                ) : undefined
              }
              actions={<FormActions form={form} saveLabel={t('common.save')} />}
            />
          }
          main={
            <>
              <GeneralCard form={form} />
              <VariantsCard form={form} />
              <MediaCard productId={productId} variants={product?.variants ?? []} form={form} />
              <PricesCard
                form={form}
                productName={product?.name ?? ''}
                currencies={profile?.supported_currencies}
                defaultCurrency={profile?.default_currency}
              />
              <InventoryCard form={form} />
            </>
          }
          sidebar={
            <>
              {productId && product && (
                <ProductStatusCard
                  product={product}
                  onDone={() => {
                    void queryClient.invalidateQueries({ queryKey: productKey })
                    void queryClient.invalidateQueries({ queryKey: ['seller-products'] })
                  }}
                />
              )}
            </>
          }
        />
      </form>
    </FormProvider>
  )
}
