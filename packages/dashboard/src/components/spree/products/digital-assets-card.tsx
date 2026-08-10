import type { DigitalAsset, Variant } from '@spree/admin-sdk'
import { formatFileSize, useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Input,
  Pagination,
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

type LimitField = 'authorized_clicks' | 'authorized_days'

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
  const [page, setPage] = useState(1)

  // Digital files live on private storage: they are only ever served through an
  // authorized, signed link, never from the public bucket.
  const directUpload = useDirectUpload({ private: true })
  const { data, isLoading } = useDigitalAssets(productId ?? '', page, Boolean(productId))
  const createAsset = useCreateDigitalAsset(productId ?? '')
  const updateAsset = useUpdateDigitalAsset(productId ?? '')
  const deleteAsset = useDeleteDigitalAsset(productId ?? '')

  const assets: DigitalAsset[] = data?.data ?? []
  const meta = data?.meta
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
      setPage(1)
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

  // Blank means "use the store setting", so an empty box is a real value.
  function handleLimitChange(asset: DigitalAsset, field: LimitField, raw: string) {
    const parsed = raw.trim() === '' ? null : Number(raw)
    if (parsed !== null && (!Number.isFinite(parsed) || parsed < 1)) return

    updateAsset.mutate({ id: asset.id, [field]: parsed })
  }

  function LimitCell({
    asset,
    field,
    effective,
  }: {
    asset: DigitalAsset
    field: LimitField
    effective: number
  }) {
    const label = t(
      field === 'authorized_clicks'
        ? 'admin.digital_assets.columns.downloads'
        : 'admin.digital_assets.columns.days',
    )

    return (
      <Input
        type="number"
        min={1}
        className="w-24"
        defaultValue={asset[field] ?? ''}
        placeholder={String(effective)}
        aria-label={label}
        onBlur={(e) => handleLimitChange(asset, field, e.target.value)}
      />
    )
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
                      {asset.byte_size ? formatFileSize(asset.byte_size) : '—'}
                    </TableCell>
                    <TableCell>
                      <LimitCell
                        asset={asset}
                        field="authorized_clicks"
                        effective={asset.effective_authorized_clicks}
                      />
                    </TableCell>
                    <TableCell>
                      <LimitCell
                        asset={asset}
                        field="authorized_days"
                        effective={asset.effective_authorized_days}
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
            {meta && <Pagination meta={meta} onPageChange={setPage} />}
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
