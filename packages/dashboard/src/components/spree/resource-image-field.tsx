import { ImageUploadField } from '@spree/dashboard-core'
import { useMemo } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

/**
 * The form fields backing one image: a freshly direct-uploaded blob
 * (`*_signed_id`), a transient object URL for the just-picked file
 * (`*_preview_url`), and a flag marking the persisted attachment for removal
 * (`*_cleared`). Together they form the three-state machine the API expects —
 * see the `imageParam` mapper in the schema files.
 */
export interface ImageFieldsShape {
  image_signed_id: string | null
  image_preview_url: string | null
  image_cleared: boolean
  square_image_signed_id: string | null
  square_image_preview_url: string | null
  square_image_cleared: boolean
}

type ImageKind = 'image' | 'square_image'

/**
 * Form adapter over the reusable {@link ImageUploadField}, shared by every
 * resource whose form carries the {@link ImageFieldsShape} triple (categories,
 * collections). Maps the triple onto the generic controlled `ImageUploadValue`
 * and resolves labels from the owning resource's locale namespace.
 */
export function ResourceImageField<T extends ImageFieldsShape>({
  form,
  kind,
  serverUrl,
  square = false,
  translationNamespace,
}: {
  form: UseFormReturn<T>
  kind: ImageKind
  serverUrl: string | null
  square?: boolean
  /** Locale namespace holding the `images.*` copy, e.g. `admin.collections`. */
  translationNamespace: string
}) {
  const { t } = useTranslation()

  // The adapter only ever touches the image triple; narrow to the shared shape
  // so the field-path operations type-check regardless of the concrete form `T`
  // (`UseFormReturn` is invariant in its field-values type).
  const imageForm = useMemo(() => form as unknown as UseFormReturn<ImageFieldsShape>, [form])

  const signedIdField = `${kind}_signed_id` as const
  const previewField = `${kind}_preview_url` as const
  const clearedField = `${kind}_cleared` as const

  return (
    <ImageUploadField
      square={square}
      serverUrl={serverUrl}
      label={t(`${translationNamespace}.images.${square ? 'square_label' : 'label'}`)}
      help={t(`${translationNamespace}.images.${square ? 'square_help' : 'help'}`)}
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
