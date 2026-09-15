import { ImageUploadField } from '@spree/dashboard-core'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import type { ProfileFormValues } from '../schemas/profile'

type ImageKind = 'logo' | 'square_logo' | 'cover_photo'

interface ConcreteImageFields {
  logo_signed_id: string | null
  logo_preview_url: string | null
  logo_cleared: boolean
}

export function ProfileImageField({
  form,
  kind,
  serverUrl,
  square = false,
  labelKey,
  helpKey,
}: {
  form: UseFormReturn<ProfileFormValues>
  kind: ImageKind
  serverUrl: string | null
  square?: boolean
  labelKey: string
  helpKey: string
}) {
  const { t } = useTranslation()

  const signedIdField = `${kind}_signed_id` as 'logo_signed_id'
  const previewField = `${kind}_preview_url` as 'logo_preview_url'
  const clearedField = `${kind}_cleared` as 'logo_cleared'

  const imageForm = form as unknown as UseFormReturn<ConcreteImageFields>

  return (
    <ImageUploadField
      square={square}
      serverUrl={serverUrl}
      label={t(`profile.images.${labelKey}`)}
      help={t(`profile.images.${helpKey}`)}
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
