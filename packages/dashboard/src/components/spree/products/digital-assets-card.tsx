import type { DigitalAsset, Variant } from '@spree/admin-sdk'
import { useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
  useConfirm,
} from '@spree/dashboard-ui'
import { FileIcon, Trash2Icon, UploadIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateDigitalAsset,
  useDeleteDigitalAsset,
  useDigitalAssets,
  useUpdateDigitalAsset,
} from '../../../hooks/use-digital-assets'

function formatFileSize(bytes: number | null | undefined): string {
  if (!bytes) return '—'
  const units = ['B', 'KB', 'MB', 'GB']
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit++
  }
  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
}

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
  const [uploadingName, setUploadingName] = useState<string | null>(null)
  const [selectedVariantId, setSelectedVariantId] = useState<string>('')

  // Digital files live on private storage: they are only ever served through an
  // authorized, signed link, never from the public bucket.
  const directUpload = useDirectUpload({ private: true })
  const { data, isLoading } = useDigitalAssets(productId ?? '', Boolean(productId))
  const createAsset = useCreateDigitalAsset(productId ?? '')
  const updateAsset = useUpdateDigitalAsset(productId ?? '')
  const deleteAsset = useDeleteDigitalAsset(productId ?? '')

  const assets: DigitalAsset[] = data?.data ?? []
  const hasVariants = (variants?.length ?? 0) > 1

  async function handleFileSelected(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]
    event.target.value = ''
    if (!file || !productId) return

    setUploadingName(file.name)
    try {
      const { signedId } = await directUpload.mutateAsync(file)
      await createAsset.mutateAsync({
        signed_id: signedId,
        ...(selectedVariantId ? { variant_id: selectedVariantId } : {}),
      })
    } finally {
      setUploadingName(null)
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

  function handleLimitChange(asset: DigitalAsset, field: 'clicks' | 'days', raw: string) {
    const parsed = raw.trim() === '' ? null : Number(raw)
    if (parsed !== null && (!Number.isFinite(parsed) || parsed < 1)) return

    updateAsset.mutate({
      id: asset.id,
      ...(field === 'clicks' ? { authorized_clicks: parsed } : { authorized_days: parsed }),
    })
  }

  if (!productId) return null

  return (
    <Card>
      <CardHeader>
        <CardTitle>{t('admin.digital_assets.title')}</CardTitle>
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
          <div className="overflow-x-auto">
            <Table>
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
                      {asset.filename ?? t('admin.digital_assets.untitled')}
                    </TableCell>
                    {hasVariants && (
                      <TableCell className="text-muted-foreground">
                        {variants?.find((v) => v.id === asset.variant_id)?.options_text ?? '—'}
                      </TableCell>
                    )}
                    <TableCell className="tabular-nums">
                      {formatFileSize(asset.byte_size)}
                    </TableCell>
                    <TableCell>
                      <Input
                        type="number"
                        min={1}
                        className="w-24"
                        defaultValue={asset.authorized_clicks ?? ''}
                        placeholder={String(asset.effective_authorized_clicks)}
                        aria-label={t('admin.digital_assets.columns.downloads')}
                        onBlur={(e) => handleLimitChange(asset, 'clicks', e.target.value)}
                      />
                    </TableCell>
                    <TableCell>
                      <Input
                        type="number"
                        min={1}
                        className="w-24"
                        defaultValue={asset.authorized_days ?? ''}
                        placeholder={String(asset.effective_authorized_days)}
                        aria-label={t('admin.digital_assets.columns.days')}
                        onBlur={(e) => handleLimitChange(asset, 'days', e.target.value)}
                      />
                    </TableCell>
                    <TableCell className="text-right">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        aria-label={t('admin.common.delete')}
                        onClick={() => handleDelete(asset)}
                      >
                        <Trash2Icon className="size-4" />
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </div>
        )}

        <div className="flex flex-wrap items-center gap-2">
          {hasVariants && (
            <Select value={selectedVariantId} onValueChange={setSelectedVariantId}>
              <SelectTrigger className="w-56">
                <SelectValue placeholder={t('admin.digital_assets.all_variants')}>
                  {(value) =>
                    variants?.find((v) => v.id === value)?.options_text ??
                    t('admin.digital_assets.all_variants')
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {variants?.map((variant) => (
                  <SelectItem key={variant.id} value={variant.id}>
                    {variant.options_text || variant.sku}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
          )}

          <Button
            type="button"
            variant="outline"
            disabled={Boolean(uploadingName)}
            onClick={() => fileInputRef.current?.click()}
          >
            <UploadIcon className="mr-2 size-4" />
            {uploadingName
              ? t('admin.digital_assets.uploading', { name: uploadingName })
              : t('admin.digital_assets.upload')}
          </Button>

          <input ref={fileInputRef} type="file" className="hidden" onChange={handleFileSelected} />
        </div>

        <p className="text-muted-foreground text-xs">{t('admin.digital_assets.limits_help')}</p>
      </CardContent>
    </Card>
  )
}
