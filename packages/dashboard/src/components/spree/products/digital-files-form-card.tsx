import { formatFileSize, type ProductFormValues, useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  FileTypeIcon,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { FileIcon, Loader2Icon, UploadIcon, XIcon } from 'lucide-react'
import { useCallback, useRef, useState } from 'react'
import type { UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

interface PendingUpload {
  id: string
  name: string
}

/**
 * Create-time digital files: buffers uploads to private storage and stages them
 * in the product form's `digital_assets` field, so a new product ships its
 * downloadable files in the same POST. The edit page uses the live, API-driven
 * {@link DigitalAssetsCard} instead — this card is for products that don't exist
 * yet, so it can't issue per-asset requests.
 */
export function DigitalFilesFormCard({
  form,
}: {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  form: UseFormReturn<ProductFormValues, any, any>
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  // Files are only ever served through an authorized, signed link, so they go
  // to private storage — never the public bucket.
  const directUpload = useDirectUpload({ private: true })
  const [pending, setPending] = useState<PendingUpload[]>([])
  const fileInputRef = useRef<HTMLInputElement>(null)

  const items = form.watch('digital_assets') ?? []

  const handleFiles = useCallback(
    async (files: FileList | File[]) => {
      const fileArray = Array.from(files)
      for (const file of fileArray) {
        const uploadId = crypto.randomUUID()
        setPending((prev) => [...prev, { id: uploadId, name: file.name }])
        try {
          const { signedId } = await directUpload.mutateAsync(file)
          const current = form.getValues('digital_assets') ?? []
          form.setValue(
            'digital_assets',
            [
              ...current,
              { signed_id: signedId, filename: file.name, byteSize: file.size, uploadId },
            ],
            { shouldDirty: true },
          )
        } catch (err) {
          const message = err instanceof Error ? err.message : t('admin.errors.unexpected')
          toastManager.add({
            type: 'error',
            title: t('admin.digital_assets.upload_failed', { name: file.name, message }),
          })
        } finally {
          setPending((prev) => prev.filter((p) => p.id !== uploadId))
        }
      }
    },
    [directUpload, form, t],
  )

  function handleFileInput(event: React.ChangeEvent<HTMLInputElement>) {
    const files = event.target.files
    event.target.value = ''
    if (files) void handleFiles(files)
  }

  function handleDrop(event: React.DragEvent) {
    event.preventDefault()
    if (event.dataTransfer.files.length > 0) void handleFiles(event.dataTransfer.files)
  }

  async function handleRemove(index: number) {
    const current = form.getValues('digital_assets') ?? []
    const entry = current[index]
    const confirmed = await confirm({
      title: t('admin.digital_assets.delete_title'),
      message: t('admin.digital_assets.delete_description', {
        name: entry?.filename ?? t('admin.digital_assets.untitled'),
      }),
      variant: 'destructive',
    })
    if (!confirmed) return
    form.setValue(
      'digital_assets',
      current.filter((_, i) => i !== index),
      { shouldDirty: true },
    )
  }

  const empty = items.length === 0 && pending.length === 0

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.digital_assets.title')}</CardTitle>
        {!empty && (
          <CardAction>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => fileInputRef.current?.click()}
            >
              <UploadIcon className="mr-2 size-4" />
              {t('admin.digital_assets.upload')}
            </Button>
          </CardAction>
        )}
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        <p className="text-muted-foreground text-sm">{t('admin.digital_assets.description')}</p>

        <input
          ref={fileInputRef}
          type="file"
          multiple
          className="hidden"
          onChange={handleFileInput}
        />

        {empty ? (
          <button
            type="button"
            onDrop={handleDrop}
            onDragOver={(e) => e.preventDefault()}
            onClick={() => fileInputRef.current?.click()}
            className="flex w-full cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border p-6 text-center transition-colors hover:border-foreground/30"
          >
            <FileIcon className="size-8 text-muted-foreground" />
            <p className="text-muted-foreground text-sm">{t('admin.digital_assets.drop_hint')}</p>
          </button>
        ) : (
          <div className="overflow-hidden rounded-md border border-border">
            <Table className="border-collapse [&_td]:rounded-none [&_td]:border [&_th]:border [&_td]:border-border [&_th]:border-border">
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.digital_assets.columns.file')}</TableHead>
                  <TableHead>{t('admin.digital_assets.columns.size')}</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {items.map((entry, index) => (
                  <TableRow key={entry.uploadId ?? entry.signed_id}>
                    <TableCell className="font-medium">
                      <span className="flex items-center gap-2">
                        <FileTypeIcon
                          filename={entry.filename}
                          className="text-muted-foreground size-4 shrink-0"
                        />
                        {entry.filename ?? t('admin.digital_assets.untitled')}
                      </span>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {entry.byteSize != null ? formatFileSize(entry.byteSize) : '—'}
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon-xs"
                        aria-label={t('admin.actions.remove')}
                        onClick={() => handleRemove(index)}
                      >
                        <XIcon className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
                {pending.map((upload) => (
                  <TableRow key={upload.id}>
                    <TableCell className="font-medium">
                      <span className="flex items-center gap-2 text-muted-foreground">
                        <Loader2Icon className="size-4 shrink-0 animate-spin" />
                        {upload.name}
                      </span>
                    </TableCell>
                    <TableCell className="text-muted-foreground">
                      {t('admin.digital_assets.uploading_short')}
                    </TableCell>
                    <TableCell />
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}
      </CardContent>
    </Card>
  )
}
