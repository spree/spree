import { useMemo } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { ImageFieldsFor } from '../lib/attachment-image-form'
import { ImageUploadField } from './image-upload-field'

interface ConcreteImageFields {
  image_signed_id: string | null
  image_preview_url: string | null
  image_cleared: boolean
}

/**
 * Form adapter over {@link ImageUploadField} for the signed_id / preview_url /
 * cleared triple. Used anywhere a resource form carries one attachment field
 * without the admin media library picker.
 */
export function FormImageField<Name extends string, T extends ImageFieldsFor<Name>>({
  form,
  kind,
  serverUrl,
  square = false,
  translationNamespace,
  labelKey,
  helpKey,
}: {
  form: UseFormReturn<T>
  kind: Name
  serverUrl: string | null
  square?: boolean
  translationNamespace: string
  labelKey?: string
  helpKey?: string
}) {
  const { t } = useTranslation()
  const imageForm = useMemo(() => form as unknown as UseFormReturn<ConcreteImageFields>, [form])

  const signedIdField = `${kind}_signed_id` as 'image_signed_id'
  const previewField = `${kind}_preview_url` as 'image_preview_url'
  const clearedField = `${kind}_cleared` as 'image_cleared'

  const resolvedLabelKey = labelKey ?? (square ? 'square_label' : 'label')
  const resolvedHelpKey = helpKey ?? (square ? 'square_help' : 'help')

  return (
    <ImageUploadField
      square={square}
      serverUrl={serverUrl}
      label={t(`${translationNamespace}.images.${resolvedLabelKey}`)}
      help={t(`${translationNamespace}.images.${resolvedHelpKey}`)}
      value={{
        signedId: imageForm.watch(signedIdField),
        previewUrl: imageForm.watch(previewField),
        cleared: imageForm.watch(clearedField),
      }}
      onChange={(next) => {
        imageForm.setValue(signedIdField, next.signedId, { shouldDirty: true })
        imageForm.setValue(previewField, next.previewUrl, { shouldDirty: true })
        imageForm.setValue(clearedField, next.cleared, { shouldDirty: true })
      }}
    />
  )
}
