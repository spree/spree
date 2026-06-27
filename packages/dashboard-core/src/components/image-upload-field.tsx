import { Button, cn, Field, FieldDescription, FieldLabel } from '@spree/dashboard-ui'
import { ImageIcon, UploadCloudIcon } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useDirectUpload } from '../hooks/use-direct-upload'

/**
 * Controlled upload state. A field is in exactly one of three states:
 * - untouched: `signedId == null && !cleared` → caller omits it on save
 * - uploaded:  `signedId` set                → caller sends the signed_id
 * - cleared:   `cleared == true`             → caller sends null to purge
 *
 * `previewUrl` is a transient object URL for the just-picked file; it's only
 * meaningful while `signedId` is set.
 */
export interface ImageUploadValue {
  signedId: string | null
  previewUrl: string | null
  cleared: boolean
}

export interface ImageUploadFieldProps {
  /** Current upload state. */
  value: ImageUploadValue
  onChange: (value: ImageUploadValue) => void
  /** URL of the already-persisted image, shown until the user replaces/removes it. */
  serverUrl?: string | null
  label?: string
  /** Helper text under the buttons. */
  help?: string
  /** Square preview + crop hint (e.g. avatars, logos). Defaults to a 16:9-ish box. */
  square?: boolean
  /** Accepted MIME types. Defaults to PNG/JPEG/WebP. */
  accept?: string
  disabled?: boolean
}

/**
 * Reusable single-image upload field backed by ActiveStorage direct upload.
 * Fully controlled — it owns the upload/preview/remove UX and reports state via
 * `onChange`; the consumer maps `ImageUploadValue` onto its form and decides how
 * to serialize it (send `signed_id`, send `null` to clear, or omit). Use for
 * category images, store logo, brand assets, etc.
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
  const directUpload = useDirectUpload()
  const fileInputRef = useRef<HTMLInputElement | null>(null)
  const [uploading, setUploading] = useState(false)

  // Show the just-picked file, else the persisted image — unless the user
  // cleared it (then show the empty placeholder even if a serverUrl exists).
  const currentPreview = value.previewUrl ?? (value.cleared ? null : (serverUrl ?? null))
  const hasImage = !!currentPreview

  // Revoke the previous object URL when it changes / on unmount.
  const previewUrlRef = useRef<string | null>(null)
  useEffect(() => {
    const previous = previewUrlRef.current
    if (previous && previous !== value.previewUrl) URL.revokeObjectURL(previous)
    previewUrlRef.current = value.previewUrl ?? null
  }, [value.previewUrl])
  useEffect(() => {
    return () => {
      if (previewUrlRef.current) URL.revokeObjectURL(previewUrlRef.current)
    }
  }, [])

  async function onFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0]
    if (!file) return
    setUploading(true)
    try {
      const result = await directUpload.mutateAsync(file)
      if (value.previewUrl) URL.revokeObjectURL(value.previewUrl)
      onChange({ signedId: result.signedId, previewUrl: result.previewUrl, cleared: false })
    } catch (err) {
      toast.error(err instanceof Error ? err.message : t('admin.image_upload.upload_failed'))
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  function clear() {
    if (value.previewUrl) URL.revokeObjectURL(value.previewUrl)
    onChange({ signedId: null, previewUrl: null, cleared: true })
  }

  return (
    <Field>
      {label && <FieldLabel>{label}</FieldLabel>}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:gap-6">
        <div
          className={cn(
            'flex shrink-0 items-center justify-center overflow-hidden rounded-md border border-border border-dashed bg-muted transition-colors',
            square ? 'size-24' : 'h-24 w-44',
          )}
        >
          {hasImage ? (
            <img src={currentPreview} alt="" className="size-full object-contain" />
          ) : (
            <div className="flex flex-col items-center gap-2 text-muted-foreground">
              {uploading ? (
                <UploadCloudIcon className="size-6 animate-pulse" />
              ) : (
                <ImageIcon className="size-6" />
              )}
            </div>
          )}
        </div>
        <div className="flex flex-col gap-2">
          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
              disabled={uploading || disabled}
            >
              {uploading
                ? t('admin.image_upload.uploading')
                : hasImage
                  ? t('admin.image_upload.replace_cta')
                  : t('admin.image_upload.upload_cta')}
            </Button>
            {hasImage && (
              <Button
                type="button"
                variant="ghost"
                size="sm"
                onClick={clear}
                disabled={uploading || disabled}
              >
                {t('admin.image_upload.remove_cta')}
              </Button>
            )}
          </div>
          {help && <FieldDescription>{help}</FieldDescription>}
        </div>
        <input
          ref={fileInputRef}
          type="file"
          accept={accept}
          className="hidden"
          onChange={onFileChange}
        />
      </div>
    </Field>
  )
}
