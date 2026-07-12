import { useTranslation } from 'react-i18next'
import { FileUploadField, type FileUploadValue } from './file-upload-field'

/** @deprecated Use {@link FileUploadValue} — same shape, universal name. */
export type ImageUploadValue = FileUploadValue

export interface ImageUploadFieldProps {
  value: ImageUploadValue
  onChange: (value: ImageUploadValue) => void
  /** URL of the already-persisted image, shown until the user replaces/removes it. */
  serverUrl?: string | null
  label?: string
  /** Helper text under the dropzone. */
  help?: string
  /** Square preview (avatars); default is a wider logo-friendly box. */
  square?: boolean
  /** Accepted MIME types. Defaults to PNG/JPEG/WebP. */
  accept?: string
  disabled?: boolean
}

/**
 * Single-image preset of {@link FileUploadField} — logos, avatars, category
 * images. Kept as a named export so existing call sites stay drop-in.
 */
export function ImageUploadField({
  value,
  onChange,
  serverUrl,
  label,
  help,
  square = false,
  accept = 'image/png,image/jpeg,image/webp',
  disabled = false,
}: ImageUploadFieldProps) {
  const { t } = useTranslation()

  return (
    <FileUploadField
      variant="image"
      value={value}
      onChange={onChange}
      accept={accept}
      serverUrl={serverUrl}
      label={label}
      help={help}
      disabled={disabled}
      dropLabel={t('admin.components.file_upload.drop_image_label')}
      browseLabel={t('admin.image_upload.upload_cta')}
      mediaClassName={square ? 'size-16' : 'h-16 w-28'}
    />
  )
}
