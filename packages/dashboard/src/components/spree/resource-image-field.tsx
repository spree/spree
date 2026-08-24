import type { Media } from '@spree/admin-sdk'
import {
  adminClient,
  ImageUploadField,
  MediaPickerSheet,
  useDirectUpload,
} from '@spree/dashboard-core'
import { Button } from '@spree/dashboard-ui'
import { LibraryIcon } from 'lucide-react'
import { useMemo, useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { useCreateMediaLibraryFile } from '../../hooks/use-media-library'

/**
 * The form fields backing one image: a freshly direct-uploaded blob
 * (`<name>_signed_id`), a transient object URL for the just-picked file
 * (`<name>_preview_url`), and a flag marking the persisted attachment for
 * removal (`<name>_cleared`). Together they form the three-state machine the
 * API expects — see the `imageParam` mapper in the schema files.
 *
 * The triple is keyed by the attachment's own name, so a resource carrying
 * `logo`/`cover_photo` composes exactly like one carrying `image`.
 */
export type ImageFieldsFor<Name extends string> = {
  [K in `${Name}_signed_id` | `${Name}_preview_url`]: K extends `${string}_signed_id`
    ? string | null
    : string | null
} & { [K in `${Name}_cleared`]: boolean }

/** The pair categories and collections carry. */
export type ImageFieldsShape = ImageFieldsFor<'image'> & ImageFieldsFor<'square_image'>

/**
 * Erased shape used inside the adapter only. The public API stays generic over
 * the attachment name; this is what the three field paths are resolved against.
 */
interface ConcreteImageFields {
  image_signed_id: string | null
  image_preview_url: string | null
  image_cleared: boolean
}

/**
 * Form adapter over the reusable {@link ImageUploadField}, shared by every
 * resource whose form carries the image triple (categories, collections,
 * sellers). Maps the triple onto the generic controlled `ImageUploadValue`
 * and resolves labels from the owning resource's locale namespace.
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
  /** The attachment's name on the model, e.g. `image`, `logo`, `cover_photo`. */
  kind: Name
  serverUrl: string | null
  square?: boolean
  /** Locale namespace holding the `images.*` copy, e.g. `admin.collections`. */
  translationNamespace: string
  /**
   * Copy keys within `<translationNamespace>.images`. Default to the legacy
   * `label`/`square_label` pair the two-image resources use; a resource with
   * more than two attachments names them per field instead.
   */
  labelKey?: string
  helpKey?: string
}) {
  const { t } = useTranslation()
  const [picking, setPicking] = useState(false)
  const directUpload = useDirectUpload()
  const createLibraryFile = useCreateMediaLibraryFile()

  // The adapter only ever touches this one image triple, and always by the
  // three names derived from `kind`. Narrow to a concrete triple so the
  // field-path operations type-check: RHF's `Path<T>` cannot resolve a
  // template-literal key against a generic mapped type, and `UseFormReturn`
  // is invariant in its field-values type either way.
  const imageForm = useMemo(() => form as unknown as UseFormReturn<ConcreteImageFields>, [form])

  const signedIdField = `${kind}_signed_id` as 'image_signed_id'
  const previewField = `${kind}_preview_url` as 'image_preview_url'
  const clearedField = `${kind}_cleared` as 'image_cleared'

  const resolvedLabelKey = labelKey ?? (square ? 'square_label' : 'label')
  const resolvedHelpKey = helpKey ?? (square ? 'square_help' : 'help')

  return (
    <div className="space-y-2">
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
        // Picking hands over the file's own blob, so this field and the library
        // row point at one file — no upload, no second copy in storage.
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
