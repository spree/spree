import { ImageUploadField } from '@spree/dashboard-core'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { CategoryFormValues } from '@/schemas/category'

type ImageKind = 'image' | 'square_image'

/**
 * Thin category-form adapter over the reusable {@link ImageUploadField}. Maps
 * the form's `<kind>_signed_id` / `_preview_url` / `_cleared` triple onto the
 * generic controlled `ImageUploadValue`, and supplies the category-specific
 * labels.
 */
export function CategoryImageField({
  form,
  kind,
  serverUrl,
  square = false,
}: {
  form: UseFormReturn<CategoryFormValues>
  kind: ImageKind
  serverUrl: string | null
  square?: boolean
}) {
  const { t } = useTranslation()

  const signedIdField = `${kind}_signed_id` as const
  const previewField = `${kind}_preview_url` as const
  const clearedField = `${kind}_cleared` as const

  return (
    <ImageUploadField
      square={square}
      serverUrl={serverUrl}
      label={
        square ? t('admin.categories.images.square_label') : t('admin.categories.images.label')
      }
      help={square ? t('admin.categories.images.square_help') : t('admin.categories.images.help')}
      value={{
        signedId: form.watch(signedIdField),
        previewUrl: form.watch(previewField),
        cleared: form.watch(clearedField),
      }}
      onChange={(next) => {
        form.setValue(signedIdField, next.signedId, { shouldDirty: true })
        form.setValue(previewField, next.previewUrl, { shouldDirty: true })
        form.setValue(clearedField, next.cleared, { shouldDirty: true })
      }}
    />
  )
}
