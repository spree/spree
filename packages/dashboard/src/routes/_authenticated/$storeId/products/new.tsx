import { zodResolver } from '@hookform/resolvers/zod'
import { mapSpreeErrorsToForm, PageHeader } from '@spree/dashboard-core'
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
  ResourceLayout,
  Textarea,
} from '@spree/dashboard-ui'
import { createFileRoute, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useChannels } from '@/hooks/use-channels'
import { useCreateProduct } from '@/hooks/use-product'
import { productFormSchema } from '@/schemas/product'

export const Route = createFileRoute('/_authenticated/$storeId/products/new')({
  component: NewProductPage,
})

type CreateValues = { name: string; description?: string }

function NewProductPage() {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const navigate = useNavigate()
  const create = useCreateProduct()
  const { data: channelsResponse } = useChannels()
  // Pre-select the store's default channel so a freshly-created product is
  // visible on the storefront without the merchant having to open the
  // Publishing card. Mirrors Shopify's autoPublish behavior on the Online
  // Store channel — the merchant can untick channels post-create.
  const defaultChannelId = channelsResponse?.data.find((c) => c.default)?.id

  const form = useForm<CreateValues>({
    resolver: zodResolver(productFormSchema.pick({ name: true, description: true })),
    defaultValues: { name: '', description: '' },
  })

  async function onSubmit(values: CreateValues) {
    try {
      const payload: Record<string, unknown> = { ...values }
      if (defaultChannelId) {
        payload.product_publications = [{ channel_id: defaultChannelId }]
      }
      const product = await create.mutateAsync(payload)
      navigate({
        to: '/$storeId/products/$productId',
        params: { storeId, productId: product.id },
      })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      toast.error(t('admin.pages.products.new.create_failed'))
    }
  }

  const { errors } = form.formState

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <ResourceLayout
        header={
          <PageHeader
            title={t('admin.pages.products.new.title')}
            description={t('admin.pages.products.new.description')}
            backTo="products"
            actions={
              <Button type="submit" size="sm" disabled={form.formState.isSubmitting}>
                {t('admin.pages.products.new.save_label')}
              </Button>
            }
          />
        }
        main={
          <Card>
            <CardHeader>
              <CardTitle>{t('admin.pages.products.section_basics')}</CardTitle>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="name">{t('admin.fields.product.name.label')}</FieldLabel>
                  <Input
                    id="name"
                    autoFocus
                    placeholder={t('admin.fields.product.name.placeholder')}
                    aria-invalid={!!errors.name || undefined}
                    {...form.register('name')}
                  />
                  <FieldError errors={[errors.name]} />
                </Field>
                <Field>
                  <FieldLabel htmlFor="description">
                    {t('admin.fields.product.description.label')}
                  </FieldLabel>
                  <Textarea
                    id="description"
                    rows={5}
                    placeholder={t('admin.fields.product.description.placeholder')}
                    {...form.register('description')}
                  />
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>
        }
      />
    </form>
  )
}
