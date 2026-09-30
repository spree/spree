import type { Media } from '@spree/admin-sdk'
import {
  adminClient,
  FormImageField,
  type ImageFieldsFor,
  MediaPickerSheet,
  useDirectUpload,
} from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { LibraryIcon } from '@spree/dashboard-ui/icons'
import { useMemo, useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCreateMediaLibraryFile } from '../../hooks/use-media-library'

export type { ImageFieldsFor } from '@spree/dashboard-core'

/** The pair categories and collections carry. */
export type ImageFieldsShape = ImageFieldsFor<'image'> & ImageFieldsFor<'square_image'>

/**
 * Admin form adapter for one image triple, with a media-library picker on top
 * of the direct-upload field the seller panel also uses.
 */
export function ResourceImageField<Name extends string, T extends ImageFieldsFor<Name>>({
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
  const [picking, setPicking] = useState(false)
  const directUpload = useDirectUpload()
  const createLibraryFile = useCreateMediaLibraryFile()

  interface ConcreteImageFields {
    image_signed_id: string | null
    image_preview_url: string | null
    image_cleared: boolean
  }

  const imageForm = useMemo(() => form as unknown as UseFormReturn<ConcreteImageFields>, [form])
  const signedIdField = `${kind}_signed_id` as 'image_signed_id'
  const previewField = `${kind}_preview_url` as 'image_preview_url'
  const clearedField = `${kind}_cleared` as 'image_cleared'

  return (
    <div className="space-y-2">
      <FormImageField
        form={form}
        kind={kind}
        serverUrl={serverUrl}
        square={square}
        translationNamespace={translationNamespace}
        labelKey={labelKey}
        helpKey={helpKey}
      />

      <Button type="button" variant="outline" size="sm" onClick={() => setPicking(true)}>
        <LibraryIcon className="size-4" />
        {t('admin.media_library.choose_from_library')}
      </Button>

      <MediaPickerSheet<Media>
        open={picking}
        onOpenChange={setPicking}
        multiple={false}
        queryKey={`image-field-${kind}`}
        search={(query) =>
          adminClient.media.list({
            limit: 48,
            media_type_eq: 'image',
            ...(query ? { filename_cont: query } : {}),
          })
        }
        onUpload={async (file) => {
          const upload = await directUpload.mutateAsync(file)
          return createLibraryFile.mutateAsync({ signed_id: upload.signedId, alt: file.name })
        }}
        onConfirm={(picked) => {
          const media = picked[0]
          if (!media?.signed_id) return

          imageForm.setValue(signedIdField, media.signed_id, { shouldDirty: true })
          imageForm.setValue(previewField, media.small_url ?? media.original_url ?? null, {
            shouldDirty: true,
          })
          imageForm.setValue(clearedField, false, { shouldDirty: true })
        }}
      />
    </div>
  )
}
