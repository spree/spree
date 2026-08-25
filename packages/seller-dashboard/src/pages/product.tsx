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

const STATUSES = ['draft', 'active', 'archived'] as const

interface ProductFormValues {
  name: string
  description: string
  status: string
  amount: string
}

/**
 * One product, created or edited.
 *
 * The same form either way: a seller filling in a new listing and a seller
 * correcting an old one are doing the same thing, and two screens would drift.
 */
export function ProductPage({ mode }: { mode: 'new' | 'edit' }) {
  const { t } = useTranslation()
  const { sellerId } = useParams({ from: '/_authenticated/$sellerId' })
  const params = useParams({ strict: false }) as { productId?: string }
  const productId = mode === 'edit' ? params.productId : undefined
  const navigate = useNavigate()
  const queryClient = useQueryClient()

  const {
    data: product,
    isLoading,
    isError,
    refetch,
  } = useQuery({
    queryKey: ['seller', sellerId, 'product', productId],
    queryFn: () => sellerClient().products.get(productId as string),
    enabled: !!productId,
  })

  const form = useForm<ProductFormValues>({
    defaultValues: { name: '', description: '', status: 'draft', amount: '' },
  })

  // Reset once the record arrives, so the inputs show what was last saved
  // rather than the blank defaults the form mounted with.
  useEffect(() => {
    if (!product) return

    form.reset({
      name: product.name ?? '',
      description: product.description ?? '',
      status: product.status ?? 'draft',
      amount: product.price?.amount ?? '',
    })
  }, [product, form])

  const save = useMutation({
    mutationFn: (values: ProductFormValues) => {
      const payload: ProductParams = {
        name: values.name,
        description: values.description,
        status: values.status,
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
  // Same distinction as the order page: a failed request is not a missing
  // product, and only one of the two is worth retrying.
  if (mode === 'edit' && isError) {
    return (
      <CenteredMessage>
        {t('common.error')}{' '}
        <Button variant="outline" onClick={() => refetch()}>
          {t('common.retry')}
        </Button>
      </CenteredMessage>
    )
  }
  if (mode === 'edit' && !product)
    return <CenteredMessage>{t('products.not_found')}</CenteredMessage>

  const { errors, isSubmitting } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="flex flex-col gap-4">
      <div className="flex items-center justify-between gap-4">
        <h1 className="font-medium text-2xl">
          {productId ? product?.name : t('products.new_title')}
        </h1>
        <Button type="submit" disabled={isSubmitting}>
          {isSubmitting ? t('common.saving') : t('common.save')}
        </Button>
      </div>

      {errors.root?.message && (
        <p className="text-destructive text-sm" role="alert">
          {errors.root.message}
        </p>
      )}

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
              <Textarea id="description" rows={5} {...form.register('description')} />
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

            <Field>
              <FieldLabel htmlFor="status">{t('products.fields.status')}</FieldLabel>
              <Select
                value={form.watch('status')}
                onValueChange={(value) => form.setValue('status', value, { shouldDirty: true })}
              >
                <SelectTrigger id="status">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {STATUSES.map((status) => (
                    <SelectItem key={status} value={status}>
                      {t(`products.statuses.${status}`)}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>
    </form>
  )
}
