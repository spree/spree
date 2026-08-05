import type { Collection } from '@spree/admin-sdk'
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  MetadataCard,
  RichTextEditor,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Textarea,
} from '@spree/dashboard-ui'
import type { UseFormReturn } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import {
  COLLECTION_SORT_ORDERS,
  type CollectionFormValues,
  sortOrderLabelKey,
} from '../../../schemas/collection'
import {
  CustomFieldsInlineCard,
  FormBackedCustomFieldsProvider,
} from '../custom-fields/custom-fields-inline'
import { ResourceImageField } from '../resource-image-field'
import { ResourceTranslationsCard } from '../translations/resource-translations-card'
import { CollectionProductsCard } from './collection-products-card'
import { CollectionRulesCard } from './collection-rules-card'

// The shared full-page collection form body, split into the two ResourceLayout
// columns. `collection` is present on edit (drives image previews, the products
// panel and translations); absent on create.

export function CollectionMain({
  form,
  collection,
}: {
  form: UseFormReturn<CollectionFormValues>
  collection?: Collection
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <>
      <Card>
        <CardContent className="pt-6">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="collection-name">{t('admin.fields.name.label')}</FieldLabel>
              <Input
                id="collection-name"
                aria-invalid={!!errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[errors.name]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="collection-description">
                {t('admin.fields.description.label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name="description"
                render={({ field }) => (
                  <RichTextEditor
                    id="collection-description"
                    ariaLabel={t('admin.fields.description.label')}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
              <FieldError errors={[errors.description]} />
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>

      <CollectionRulesCard form={form} />

      {collection && (
        <>
          <CollectionProductsCard
            collectionId={collection.id}
            automatic={collection.automatic ?? false}
          />
          <FormBackedCustomFieldsProvider form={form} resourceType="Spree::Collection">
            <CustomFieldsInlineCard />
          </FormBackedCustomFieldsProvider>
          <ResourceTranslationsCard resourceType="collection" resourceId={collection.id} />
          <MetadataCard
            metadata={collection.metadata}
            title={t('admin.components.metadata_card.title')}
            emptyTitle={t('admin.components.metadata_card.empty_title')}
            emptyDescription={t('admin.components.metadata_card.empty_description')}
          />
        </>
      )}
    </>
  )
}

export function CollectionSidebar({
  form,
  collection,
}: {
  form: UseFormReturn<CollectionFormValues>
  collection?: Collection
}) {
  const { t } = useTranslation()

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.collections.images.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-6">
          <ResourceImageField
            form={form}
            kind="image"
            serverUrl={collection?.image_url ?? null}
            translationNamespace="admin.collections"
          />
          <ResourceImageField
            form={form}
            kind="square_image"
            serverUrl={collection?.square_image_url ?? null}
            square
            translationNamespace="admin.collections"
          />
        </CardContent>
      </Card>

      <CollectionSortOrderCard form={form} />
      <CollectionSEOCard form={form} />
    </>
  )
}

/**
 * The storefront's default product order for this collection. A shopper's own
 * sort choice always overrides it; `manual` means the order the merchant
 * arranged in the products panel.
 */
function CollectionSortOrderCard({ form }: { form: UseFormReturn<CollectionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState

  // Built at render time so labels stay translated — the schema owns values only.
  const sortOrderOptions = COLLECTION_SORT_ORDERS.map((value) => ({
    value,
    label: t(sortOrderLabelKey(value)),
  }))

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.collections.sort_order.title')}</CardTitle>
        <CardDescription>{t('admin.collections.sort_order.description')}</CardDescription>
      </CardHeader>
      <CardContent>
        <Field>
          <FieldLabel htmlFor="collection-sort-order" className="sr-only">
            {t('admin.collections.fields.sort_order.label')}
          </FieldLabel>
          <Controller
            control={form.control}
            name="sort_order"
            render={({ field }) => (
              <Select items={sortOrderOptions} value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id="collection-sort-order">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  {sortOrderOptions.map((option) => (
                    <SelectItem key={option.value} value={option.value}>
                      {option.label}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          <FieldError errors={[errors.sort_order]} />
        </Field>
      </CardContent>
    </Card>
  )
}

function CollectionSEOCard({ form }: { form: UseFormReturn<CollectionFormValues> }) {
  const { t } = useTranslation()
  const { errors } = form.formState
  const name = form.watch('name')
  const permalink = form.watch('permalink')
  const metaTitle = form.watch('meta_title')
  const metaDescription = form.watch('meta_description')

  const previewTitle = metaTitle || name || ''
  const previewSlug = permalink || t('admin.collections.seo.preview_slug_placeholder')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.collections.seo.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="space-y-1 rounded-lg border border-border p-4">
          <p className="truncate text-sm font-medium text-blue-700">{previewTitle}</p>
          <p className="truncate text-xs text-green-700">example.com/c/{previewSlug}</p>
          {metaDescription && (
            <p className="line-clamp-2 text-xs text-muted-foreground">{metaDescription}</p>
          )}
        </div>

        <Field>
          <FieldLabel htmlFor="collection-permalink">{t('admin.fields.slug.label')}</FieldLabel>
          <Input
            id="collection-permalink"
            aria-invalid={!!errors.permalink || undefined}
            {...form.register('permalink')}
          />
          <FieldError errors={[errors.permalink]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="collection-meta-title">
            {t('admin.fields.meta_title.label')}
          </FieldLabel>
          <Input
            id="collection-meta-title"
            aria-invalid={!!errors.meta_title || undefined}
            {...form.register('meta_title')}
          />
          <FieldError errors={[errors.meta_title]} />
        </Field>
        <Field>
          <FieldLabel htmlFor="collection-meta-description">
            {t('admin.fields.meta_description.label')}
          </FieldLabel>
          <Textarea
            id="collection-meta-description"
            rows={3}
            aria-invalid={!!errors.meta_description || undefined}
            {...form.register('meta_description')}
          />
          <FieldError errors={[errors.meta_description]} />
        </Field>
      </CardContent>
    </Card>
  )
}
