import type { Category } from '@spree/admin-sdk'
import { ResourceCombobox } from '@spree/dashboard-core'
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
  Input,
  RichTextEditor,
  Textarea,
} from '@spree/dashboard-ui'
import type { UseFormReturn } from 'react-hook-form'
import { Controller } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { categoryAutocompleteProps } from '@/hooks/use-categories'
import type { CategoryFormValues } from '@/schemas/category'
import { CategoryImageField } from './category-image-field'
import { CategoryProductsCard } from './category-products-card'

// Build the parent-picker filter for the edited category: a category can't be
// its own parent. On create (`category` undefined) every option is selectable.
function excludeSelf(category?: Category) {
  if (!category) return undefined
  return (option: Category) => option.id !== category.id
}

// The shared full-page category form body, split into the two ResourceLayout
// columns. `category` is present on edit (drives image previews + the products
// panel); absent on create. Rendered directly as JSX by the routes —
// `<CategoryMain />` / `<CategorySidebar />` — like every other detail page.

export function CategoryMain({
  form,
  category,
}: {
  form: UseFormReturn<CategoryFormValues>
  category?: Category
}) {
  const { t } = useTranslation()
  const { errors } = form.formState

  return (
    <>
      <Card>
        <CardContent className="pt-6">
          <FieldGroup>
            <Field>
              <FieldLabel htmlFor="category-name">{t('admin.fields.name.label')}</FieldLabel>
              <Input
                id="category-name"
                aria-invalid={!!errors.name || undefined}
                {...form.register('name')}
              />
              <FieldError errors={[errors.name]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="category-description">
                {t('admin.fields.description.label')}
              </FieldLabel>
              <Controller
                control={form.control}
                name="description"
                render={({ field }) => (
                  <RichTextEditor
                    id="category-description"
                    ariaLabel={t('admin.fields.description.label')}
                    value={field.value}
                    onChange={field.onChange}
                  />
                )}
              />
            </Field>
          </FieldGroup>
        </CardContent>
      </Card>

      {category && <CategoryProductsCard categoryId={category.id} />}
    </>
  )
}

export function CategorySidebar({
  form,
  category,
}: {
  form: UseFormReturn<CategoryFormValues>
  category?: Category
}) {
  const { t } = useTranslation()

  return (
    <>
      <Card>
        <CardHeader>
          <CardTitle>{t('admin.categories.images.title')}</CardTitle>
        </CardHeader>
        <CardContent className="flex flex-col gap-6">
          <CategoryImageField form={form} kind="image" serverUrl={category?.image_url ?? null} />
          <CategoryImageField
            form={form}
            kind="square_image"
            serverUrl={category?.square_image_url ?? null}
            square
          />
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>{t('admin.categories.navigation.title')}</CardTitle>
        </CardHeader>
        <CardContent>
          <Field>
            <FieldLabel>{t('admin.categories.fields.parent.label')}</FieldLabel>
            <Controller
              control={form.control}
              name="parent_id"
              render={({ field }) => (
                <ResourceCombobox<Category>
                  {...categoryAutocompleteProps('category-parent-picker')}
                  value={field.value ?? undefined}
                  onChange={(id) => field.onChange(id ?? null)}
                  placeholder={t('admin.categories.fields.parent.placeholder')}
                  // A category can't be its own parent — hide it from the picker.
                  filterOption={excludeSelf(category)}
                />
              )}
            />
          </Field>
        </CardContent>
      </Card>

      <CategorySEOCard form={form} />
    </>
  )
}

function CategorySEOCard({ form }: { form: UseFormReturn<CategoryFormValues> }) {
  const { t } = useTranslation()
  const name = form.watch('name')
  const permalink = form.watch('permalink')
  const metaTitle = form.watch('meta_title')
  const metaDescription = form.watch('meta_description')

  const previewTitle = metaTitle || name || ''
  const previewSlug = permalink || t('admin.categories.seo.preview_slug_placeholder')

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.categories.seo.title')}</CardTitle>
      </CardHeader>
      <CardContent className="flex flex-col gap-4">
        <div className="space-y-1 rounded-lg border border-border p-4">
          <p className="truncate text-sm font-medium text-blue-700">{previewTitle}</p>
          <p className="truncate text-xs text-green-700">example.com/t/{previewSlug}</p>
          {metaDescription && (
            <p className="line-clamp-2 text-xs text-muted-foreground">{metaDescription}</p>
          )}
        </div>

        <Field>
          <FieldLabel htmlFor="category-permalink">{t('admin.fields.slug.label')}</FieldLabel>
          <Input id="category-permalink" {...form.register('permalink')} />
        </Field>
        <Field>
          <FieldLabel htmlFor="category-meta-title">
            {t('admin.fields.meta_title.label')}
          </FieldLabel>
          <Input id="category-meta-title" {...form.register('meta_title')} />
        </Field>
        <Field>
          <FieldLabel htmlFor="category-meta-description">
            {t('admin.fields.meta_description.label')}
          </FieldLabel>
          <Textarea
            id="category-meta-description"
            rows={3}
            {...form.register('meta_description')}
          />
        </Field>
      </CardContent>
    </Card>
  )
}
