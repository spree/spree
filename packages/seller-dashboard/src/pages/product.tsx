import { mapSpreeErrorsToForm } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  StatusBadge,
  Textarea,
  toastManager,
} from '@spree/dashboard-ui'
import type { ProductParams } from '@spree/seller-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useNavigate, useParams } from '@tanstack/react-router'
import { useEffect } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'
import { CenteredMessage } from '../components/centered-message'
import { ProductCustomFields } from '../components/product-custom-fields'
import { ProductStatusCard } from '../components/product-status-card'
import { RetryableError } from '../components/retryable-error'

interface ProductFormValues {
  name: string
  description: string
  amount: string
  slug: string
  meta_title: string
  meta_description: string
  meta_keywords: string
  product_type_id: string
  custom_fields: Record<string, string>
}

const EMPTY_VALUES: ProductFormValues = {
  name: '',
  description: '',
  amount: '',
  slug: '',
  meta_title: '',
  meta_description: '',
  meta_keywords: '',
  product_type_id: '',
  custom_fields: {},
}

/**
 * One product, created or edited.
 *
 * The same form either way: a seller filling in a new listing and a seller
 * correcting an old one are doing the same thing, and two screens would drift.
 *
 * Status is deliberately absent from the form. A seller does not choose
 * whether their product is on sale — they submit it and the marketplace
 * decides, which is what the status card does instead
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
    queryFn: () => sellerClient().products.get(productId as string),
    enabled: !!productId,
  })

  // The types a seller may list against, with the custom fields each asks for.
  const { data: productTypes } = useQuery({
    queryKey: ['seller', sellerId, 'product-types'],
    queryFn: () => sellerClient().productTypes.list({ per_page: 100 }),
  })

  const form = useForm<ProductFormValues>({ defaultValues: EMPTY_VALUES })

  // Reset once the record arrives, so the inputs show what was last saved
  // rather than the blank defaults the form mounted with.
  useEffect(() => {
    if (!product) return

    form.reset({
      ...EMPTY_VALUES,
      name: product.name ?? '',
      description: product.description ?? '',
      amount: product.price?.amount ?? '',
      slug: product.slug ?? '',
      meta_title: product.meta_title ?? '',
      meta_description: product.meta_description ?? '',
      meta_keywords: product.meta_keywords ?? '',
      product_type_id: product.product_type_id ?? '',
      custom_fields: (product.metadata ?? {}) as Record<string, string>,
    })
  }, [product, form])

  const selectedTypeId = form.watch('product_type_id')
  const selectedType = productTypes?.data.find((type) => type.id === selectedTypeId)

  const save = useMutation({
    mutationFn: (values: ProductFormValues) => {
      const payload: ProductParams = {
        name: values.name,
        description: values.description,
        slug: values.slug || undefined,
        meta_title: values.meta_title,
        meta_description: values.meta_description,
        meta_keywords: values.meta_keywords,
        product_type_id: values.product_type_id || undefined,
        metadata: values.custom_fields,
      }
      // Only sent when the seller typed one: an empty box means "leave the
      // price alone", not "price this at nothing".
      if (values.amount.trim()) {
        // No currency on a new listing: the server prices it in the store's,
        // which is the only place that knows it. Guessing here can persist a
        // price in the wrong currency and drop the right one.
        const currency = product?.price?.currency
        payload.prices = [{ amount: values.amount.trim(), ...(currency ? { currency } : {}) }]
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

  const { errors, isSubmitting } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-3">
          <h1 className="font-medium text-2xl">
            {productId ? product?.name : t('products.new_title')}
          </h1>
          {product?.status && <StatusBadge status={product.status} />}
        </div>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? t('common.saving') : t('common.save')}
        </Button>
      </div>

      {errors.root?.message && (
        <p className="text-destructive text-sm" role="alert">
          {errors.root.message}
        </p>
      )}

      <div className="grid gap-4 lg:grid-cols-3">
        <div className="flex flex-col gap-4 lg:col-span-2">
          <Card>
            <CardHeader>
              <CardTitle>{t('products.details')}</CardTitle>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="name">{t('products.fields.name')}</FieldLabel>
                  <Input
                    id="name"
                    aria-invalid={!!errors.name || undefined}
                    {...form.register('name', { required: true })}
                  />
                  <FieldError errors={[errors.name]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="description">{t('products.fields.description')}</FieldLabel>
                  <Textarea id="description" rows={6} {...form.register('description')} />
                  <FieldError errors={[errors.description]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="amount">{t('products.fields.price')}</FieldLabel>
                  <Input
                    id="amount"
                    inputMode="decimal"
                    placeholder={t('products.fields.price_placeholder')}
                    {...form.register('amount')}
                  />
                  <FieldError errors={[errors.amount]} />
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>

          {selectedType && (
            <ProductCustomFields
              definitions={selectedType.custom_field_definitions ?? []}
              register={form.register}
              control={form.control}
            />
          )}

          <Card>
            <CardHeader>
              <CardTitle>{t('products.seo')}</CardTitle>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="slug">{t('products.fields.slug')}</FieldLabel>
                  <Input id="slug" {...form.register('slug')} />
                  <FieldError errors={[errors.slug]} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="meta_title">{t('products.fields.meta_title')}</FieldLabel>
                  <Input id="meta_title" {...form.register('meta_title')} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="meta_description">
                    {t('products.fields.meta_description')}
                  </FieldLabel>
                  <Textarea id="meta_description" rows={3} {...form.register('meta_description')} />
                </Field>

                <Field>
                  <FieldLabel htmlFor="meta_keywords">
                    {t('products.fields.meta_keywords')}
                  </FieldLabel>
                  <Input id="meta_keywords" {...form.register('meta_keywords')} />
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>
        </div>

        <div className="flex flex-col gap-4">
          {productId && product && (
            <ProductStatusCard
              product={product}
              onDone={() => {
                void queryClient.invalidateQueries({ queryKey: productKey })
                void queryClient.invalidateQueries({ queryKey: ['seller-products'] })
              }}
            />
          )}

          <Card>
            <CardHeader>
              <CardTitle>{t('products.organization')}</CardTitle>
            </CardHeader>
            <CardContent>
              <Field>
                <FieldLabel htmlFor="product_type_id">
                  {t('products.fields.product_type')}
                </FieldLabel>
                <Select
                  value={selectedTypeId}
                  onValueChange={(value) =>
                    form.setValue('product_type_id', value, { shouldDirty: true })
                  }
                >
                  <SelectTrigger id="product_type_id">
                    <SelectValue placeholder={t('products.fields.product_type_placeholder')}>
                      {(value) =>
                        productTypes?.data.find((type) => type.id === value)?.name ??
                        t('products.fields.product_type_placeholder')
                      }
                    </SelectValue>
                  </SelectTrigger>
                  <SelectContent>
                    {productTypes?.data.map((type) => (
                      <SelectItem key={type.id} value={type.id}>
                        {type.name}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </Field>
            </CardContent>
          </Card>
        </div>
      </div>
    </form>
  )
}
