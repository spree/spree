import {
  Attachment,
  AttachmentAction,
  AttachmentActions,
  AttachmentContent,
  AttachmentDescription,
  AttachmentMedia,
  AttachmentTitle,
  cn,
  Field,
  FieldDescription,
  FieldLabel,
} from '@spree/dashboard-ui'
import { FileIcon, UploadCloudIcon, XIcon } from 'lucide-react'
import { type ReactNode, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { toast } from 'sonner'
import { useDirectUpload } from '../hooks/use-direct-upload'

/**
 * Controlled upload state. A field is in exactly one of three states:
 * - untouched: `signedId == null && !cleared` → caller omits it on save
 * - uploaded:  `signedId` set                → caller sends the signed_id
 * - cleared:   `cleared == true`             → caller sends null to purge
 *
 * `previewUrl` is a transient object URL for the just-picked file (image
 * uploads); `filename`/`byteSize` describe the picked file for display.
 */
export interface FileUploadValue {
  signedId: string | null
  previewUrl: string | null
  cleared: boolean
  filename?: string | null
  byteSize?: number | null
}

export const EMPTY_FILE_UPLOAD_VALUE: FileUploadValue = {
  signedId: null,
  previewUrl: null,
  cleared: false,
}

export function formatFileSize(bytes: number): string {
  if (bytes < 1024) return `${bytes} B`
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
}

export interface FileUploadFieldProps {
  /** Current upload state. */
  value: FileUploadValue
  onChange: (value: FileUploadValue) => void
  /** Accepted file types (input `accept` attribute). */
  accept: string
  /** `image` renders a thumbnail preview; `file` renders a type icon. */
  variant?: 'image' | 'file'
  /** Icon shown in the attachment media for the `file` variant. */
  icon?: ReactNode
  /** URL of the already-persisted attachment, shown until replaced/removed. */
  serverUrl?: string | null
  /** Display name for the persisted attachment (file variant). */
  serverFilename?: string | null
  label?: string
  /** Helper text under the dropzone. */
  help?: string
  /** Copy inside the dropzone. Defaults to the generic "drop a file" string. */
  dropLabel?: string
  /** Copy on the browse chip inside the dropzone. */
  browseLabel?: string
  /** Extra classes for the attachment media (e.g. a larger logo preview). */
  mediaClassName?: string
  disabled?: boolean
  /** Re-wrap the picked file before upload (e.g. force a content type). */
  transformFile?: (file: File) => File
}

/**
 * Universal single-file upload field backed by ActiveStorage direct upload.
 * Picking or dropping a file uploads it immediately; the attached file (or
 * the persisted server-side one) renders as an `Attachment` with a remove
 * action. Fully controlled — the consumer maps {@link FileUploadValue} onto
 * its form and decides how to serialize it (send `signed_id`, send `null`
 * to clear, or omit).
 */
export function FileUploadField({
  value,
  onChange,
  accept,
  variant = 'file',
  icon,
  serverUrl,
  serverFilename,
  label,
  help,
  dropLabel,
  browseLabel,
  mediaClassName,
  disabled = false,
  transformFile,
}: FileUploadFieldProps) {
  const { t } = useTranslation()
  const directUpload = useDirectUpload()
  const [pending, setPending] = useState<File | null>(null)

  const isImage = variant === 'image'

  // The input's `accept` only hints the OS picker and does nothing for
  // drag-and-drop — enforce it for both paths. Tokens are extensions
  // (".csv"), exact MIME types ("text/csv") or wildcards ("image/*").
  function matchesAccept(file: File): boolean {
    const tokens = accept
      .split(',')
      .map((token) => token.trim().toLowerCase())
      .filter(Boolean)
    if (tokens.length === 0) return true

    const name = file.name.toLowerCase()
    const type = file.type.toLowerCase()
    return tokens.some((token) => {
      if (token.startsWith('.')) return name.endsWith(token)
      if (token.endsWith('/*')) return type.startsWith(token.slice(0, -1))
      return type === token
    })
  }

  async function handlePicked(picked: File) {
    if (disabled || pending) return
    if (!matchesAccept(picked)) {
      toast.error(t('admin.components.file_upload.invalid_type', { accept }))
      return
    }

    const file = transformFile ? transformFile(picked) : picked
    setPending(file)
    try {
      const result = await directUpload.mutateAsync(file)
      // Revoke a preview we're replacing in-place; the object URL otherwise
      // lives in caller-owned state, so its lifetime is their responsibility
      // (a hidden-then-shown card must not remount with a dead URL).
      if (value.previewUrl) URL.revokeObjectURL(value.previewUrl)
      onChange({
        signedId: result.signedId,
        previewUrl: isImage ? result.previewUrl : null,
        cleared: false,
        filename: file.name,
        byteSize: file.size,
      })
    } catch (err) {
      toast.error(
        t('admin.components.file_upload.upload_failed', {
          message: err instanceof Error ? err.message : String(err),
        }),
      )
    } finally {
      setPending(null)
    }
  }

  function handleRemove() {
    if (value.previewUrl) URL.revokeObjectURL(value.previewUrl)
    onChange({ signedId: null, previewUrl: null, cleared: true, filename: null, byteSize: null })
  }

  // What the attachment row shows: the in-flight pick, the uploaded file, or
  // the persisted server-side attachment (until the user clears it).
  const attached = pending
    ? { state: 'uploading' as const, name: pending.name, size: pending.size, preview: null }
    : value.signedId
      ? {
          state: 'done' as const,
          name: value.filename ?? null,
          size: value.byteSize ?? null,
          preview: value.previewUrl,
        }
      : !value.cleared && (serverUrl || serverFilename)
        ? {
            state: 'done' as const,
            name: serverFilename ?? null,
            size: null,
            preview: serverUrl ?? null,
          }
        : null

  return (
    <Field>
      {label && <FieldLabel>{label}</FieldLabel>}
      <div className="flex flex-col gap-2">
        {/* A <label> wrapping the file input: clicking anywhere opens the
            picker natively. The input is sr-only (not display:none) so it
            stays in the tab order — keyboard users Tab to it and press
            Enter/Space; the label paints a focus ring via has-[:focus-visible]. */}
        <label
          className={cn(
            'flex cursor-pointer flex-col items-center justify-center gap-2 rounded-md border border-border border-dashed bg-muted/40 px-4 py-8 text-center transition-colors hover:bg-muted',
            'has-[:focus-visible]:border-ring has-[:focus-visible]:ring-[3px] has-[:focus-visible]:ring-ring/50',
            (disabled || !!pending) && 'pointer-events-none opacity-60',
          )}
          onDragOver={(e) => e.preventDefault()}
          onDrop={(e) => {
            e.preventDefault()
            const dropped = e.dataTransfer.files?.[0]
            if (dropped) void handlePicked(dropped)
          }}
        >
          <UploadCloudIcon className="size-6 text-muted-foreground" />
          <span className="text-muted-foreground text-sm">
            {dropLabel ?? t('admin.components.file_upload.drop_label')}
          </span>
          <span className="mt-1 inline-flex h-8 items-center rounded-md border border-border bg-background px-3 font-medium text-sm shadow-xs">
            {browseLabel ?? t('admin.components.file_upload.browse')}
          </span>
          <input
            type="file"
            accept={accept}
            className="sr-only"
            disabled={disabled || !!pending}
            onChange={(e) => {
              const picked = e.target.files?.[0]
              if (picked) void handlePicked(picked)
              e.target.value = ''
            }}
          />
        </label>

        {attached && (
          <Attachment className="w-full" state={attached.state}>
            <AttachmentMedia
              variant={isImage && attached.preview ? 'image' : 'icon'}
              className={mediaClassName}
            >
              {isImage && attached.preview ? (
                <img src={attached.preview} alt="" className="size-full object-contain" />
              ) : (
                (icon ?? <FileIcon />)
              )}
            </AttachmentMedia>
            <AttachmentContent>
              <AttachmentTitle>
                {attached.name ?? t('admin.components.file_upload.attached')}
              </AttachmentTitle>
              <AttachmentDescription>
                {attached.state === 'uploading'
                  ? t('admin.components.file_upload.uploading')
                  : attached.size != null
                    ? formatFileSize(attached.size)
                    : null}
              </AttachmentDescription>
            </AttachmentContent>
            <AttachmentActions>
              <AttachmentAction
                aria-label={t('admin.actions.remove')}
                onClick={handleRemove}
                disabled={disabled || !!pending}
              >
                <XIcon />
              </AttachmentAction>
            </AttachmentActions>
          </Attachment>
        )}

        {help && <FieldDescription>{help}</FieldDescription>}
      </div>
    </Field>
  )
}
