import type { DigitalAsset, Variant } from '@spree/admin-sdk'
import { formatFileSize, useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  FileTypeIcon,
  Pagination,
  RowActions,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { DownloadIcon, FileIcon, UploadIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateDigitalAsset,
  useDeleteDigitalAsset,
  useDigitalAssets,
} from '../../../hooks/use-digital-assets'
import { DigitalAssetEditSheet } from './digital-asset-edit-sheet'

export function DigitalAssetsCard({
  productId,
  variants,
}: {
  productId?: string
  variants?: Variant[]
}) {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const fileInputRef = useRef<HTMLInputElement>(null)
  const [uploading, setUploading] = useState(false)
  const [page, setPage] = useState(1)
  const [editing, setEditing] = useState<DigitalAsset | null>(null)

  // Digital files live on private storage: they are only ever served through an
  // authorized, signed link, never from the public bucket.
  const directUpload = useDirectUpload({ private: true })
  const { data, isLoading } = useDigitalAssets(productId ?? '', page, Boolean(productId))
  const createAsset = useCreateDigitalAsset(productId ?? '')
  const deleteAsset = useDeleteDigitalAsset(productId ?? '')

  const assets: DigitalAsset[] = data?.data ?? []
  const meta = data?.meta
  const hasVariants = (variants?.length ?? 0) > 1

  async function handleFileSelected(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file || !productId) return

    setUploading(true)
    try {
      const { signedId } = await directUpload.mutateAsync(file)
      await createAsset.mutateAsync({ signed_id: signedId })
      setPage(1)
    } finally {
      setUploading(false)
    }
  }

  async function handleDelete(asset: DigitalAsset) {
    const confirmed = await confirm({
      title: t('admin.digital_assets.delete_title'),
      message: t('admin.digital_assets.delete_description', {
        name: asset.filename ?? t('admin.digital_assets.untitled'),
      }),
      variant: 'destructive',
    })
    if (confirmed) await deleteAsset.mutateAsync(asset.id)
  }

  // A blank limit means the store's setting applies — show the number actually
  // in force rather than an empty cell.
  function limitLabel(own: number | null | undefined, effective: number) {
    return own == null ? t('admin.digital_assets.store_default', { count: effective }) : String(own)
  }

  if (!productId) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.digital_assets.title')}</CardTitle>
        <CardAction>
          <Button
            type="button"
            variant="outline"
            size="sm"
            disabled={uploading}
            onClick={() => fileInputRef.current?.click()}
          >
            <UploadIcon className="mr-2 size-4" />
            {uploading
              ? t('admin.digital_assets.uploading_short')
              : t('admin.digital_assets.upload')}
          </Button>
          <input ref={fileInputRef} type="file" className="hidden" onChange={handleFileSelected} />
        </CardAction>
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        <p className="text-muted-foreground text-sm">{t('admin.digital_assets.description')}</p>

        {isLoading ? (
          <Skeleton className="h-24 w-full" />
        ) : assets.length === 0 ? (
          <div className="flex flex-col items-center gap-2 rounded-md border border-dashed p-6 text-center">
            <FileIcon className="text-muted-foreground size-6" />
            <p className="text-muted-foreground text-sm">{t('admin.digital_assets.empty')}</p>
          </div>
        ) : (
          <div className="overflow-hidden rounded-md border border-border">
            <Table className="border-collapse [&_td]:rounded-none [&_td]:border [&_th]:border [&_td]:border-border [&_th]:border-border">
              <TableHeader>
                <TableRow>
                  <TableHead>{t('admin.digital_assets.columns.file')}</TableHead>
                  {hasVariants && (
                    <TableHead>{t('admin.digital_assets.columns.variant')}</TableHead>
                  )}
                  <TableHead>{t('admin.digital_assets.columns.size')}</TableHead>
                  <TableHead>{t('admin.digital_assets.columns.downloads')}</TableHead>
                  <TableHead>{t('admin.digital_assets.columns.days')}</TableHead>
                  <TableHead />
                </TableRow>
              </TableHeader>
              <TableBody>
                {assets.map((asset) => (
                  <TableRow key={asset.id}>
                    <TableCell className="font-medium">
                      <span className="flex items-center gap-2">
                        <FileTypeIcon
                          filename={asset.filename}
                          contentType={asset.content_type}
                          className="text-muted-foreground size-4 shrink-0"
                        />
                        {asset.download_url ? (
                          <a
                            href={asset.download_url}
                            target="_blank"
                            rel="noreferrer"
                            className="hover:underline"
                          >
                            {asset.filename ?? t('admin.digital_assets.untitled')}
                          </a>
                        ) : (
                          (asset.filename ?? t('admin.digital_assets.untitled'))
                        )}
                      </span>
                    </TableCell>
                    {hasVariants && (
                      <TableCell className="text-muted-foreground">
                        {variants?.find((v) => v.id === asset.variant_id)?.options_text ?? '—'}
                      </TableCell>
                    )}
                    <TableCell className="tabular-nums">
                      {asset.byte_size ? formatFileSize(asset.byte_size) : '—'}
                    </TableCell>
                    <TableCell className="tabular-nums">
                      {limitLabel(asset.authorized_clicks, asset.effective_authorized_clicks)}
                    </TableCell>
                    <TableCell className="tabular-nums">
                      {limitLabel(asset.authorized_days, asset.effective_authorized_days)}
                    </TableCell>
                    <TableCell className="text-right">
                      <RowActions
                        actions={[
                          {
                            key: 'download',
                            label: t('admin.digital_assets.download'),
                            icon: <DownloadIcon className="size-4" />,
                            visible: Boolean(asset.download_url),
                            onSelect: () => window.open(asset.download_url ?? '', '_blank'),
                          },
                          { key: 'edit', onSelect: () => setEditing(asset) },
                          {
                            key: 'delete',
                            destructive: true,
                            onSelect: () => handleDelete(asset),
                          },
                        ]}
                      />
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
            {meta && <Pagination meta={meta} onPageChange={setPage} />}
          </div>
        )}
      </CardContent>

      <DigitalAssetEditSheet
        productId={productId}
        asset={editing}
        variants={variants}
        open={Boolean(editing)}
        onOpenChange={(open) => !open && setEditing(null)}
      />
    </Card>
  )
}
