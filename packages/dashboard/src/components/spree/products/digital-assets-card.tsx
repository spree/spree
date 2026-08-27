import type { DigitalAsset, DigitalAssetProvider, Variant } from '@spree/admin-sdk'
import { formatFileSize, useDirectUpload } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardAction,
  CardContent,
  CardHeader,
  CardTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
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
import { ChevronDownIcon, DownloadIcon, FileIcon, PlusIcon, UploadIcon } from 'lucide-react'
import { useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  useCreateDigitalAsset,
  useDeleteDigitalAsset,
  useDigitalAssetProviders,
  useDigitalAssets,
} from '../../../hooks/use-digital-assets'
import { DigitalAssetEditSheet } from './digital-asset-edit-sheet'
import { DigitalAssetProviderSheet } from './digital-asset-provider-sheet'

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
  // The provider whose settings sheet is open, before its asset is created.
  const [configuring, setConfiguring] = useState<DigitalAssetProvider | null>(null)

  // Digital files live on private storage: they are only ever served through an
  // authorized, signed link, never from the public bucket.
  const directUpload = useDirectUpload({ private: true })
  const { data, isLoading } = useDigitalAssets(productId ?? '', page, Boolean(productId))
  const { data: providersData } = useDigitalAssetProviders(productId ?? '', Boolean(productId))
  const createAsset = useCreateDigitalAsset(productId ?? '')
  const deleteAsset = useDeleteDigitalAsset(productId ?? '')

  const assets: DigitalAsset[] = data?.data ?? []
  const meta = data?.meta
  const hasVariants = (variants?.length ?? 0) > 1
  const providers = providersData?.data ?? []
  // Only providers that resolve their own deliverable go in the source menu;
  // the file default is the plain upload button. With none of these, the card
  // keeps its today behaviour — a single "Add file" button.
  const sourceProviders = providers.filter((p) => !p.requires_attachment)

  async function handleFiles(files: FileList | File[]) {
    const list = Array.from(files)
    if (list.length === 0 || !productId) return

    setUploading(true)
    try {
      for (const file of list) {
        const { signedId } = await directUpload.mutateAsync(file)
        await createAsset.mutateAsync({ signed_id: signedId })
      }
      setPage(1)
    } finally {
      setUploading(false)
    }
  }

  function handleFileInput(event: React.ChangeEvent<HTMLInputElement>) {
    // `event.target.files` is a live FileList — clearing the input's value
    // empties it, so snapshot to a real array before resetting the input
    // (the reset lets the same file be re-selected later).
    const files = Array.from(event.target.files ?? [])
    event.target.value = ''
    if (files.length > 0) void handleFiles(files)
  }

  function handleDrop(event: React.DragEvent) {
    event.preventDefault()
    if (event.dataTransfer.files.length > 0) void handleFiles(event.dataTransfer.files)
  }

  // A provider with settings opens a sheet to collect them; one without
  // creates its asset immediately, exactly like the file default.
  async function handleAddProvider(provider: DigitalAssetProvider) {
    if (provider.settings_schema.length > 0) {
      setConfiguring(provider)
      return
    }
    await createAsset.mutateAsync({ provider_type: provider.type })
    setPage(1)
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
        {/* The header action only appears once files exist — an empty card
            invites the first upload through its dropzone, not a button. */}
        {assets.length > 0 && (
          <CardAction>
            {sourceProviders.length === 0 ? (
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
            ) : (
              <DropdownMenu>
                <DropdownMenuTrigger asChild>
                  <Button type="button" variant="outline" size="sm" disabled={uploading}>
                    <PlusIcon className="mr-2 size-4" />
                    {uploading
                      ? t('admin.digital_assets.uploading_short')
                      : t('admin.digital_assets.add')}
                    <ChevronDownIcon className="ml-2 size-4" />
                  </Button>
                </DropdownMenuTrigger>
                <DropdownMenuContent align="end">
                  <DropdownMenuItem onClick={() => fileInputRef.current?.click()}>
                    <UploadIcon className="mr-2 size-4" />
                    {t('admin.digital_assets.source.upload')}
                  </DropdownMenuItem>
                  {sourceProviders.map((provider) => (
                    <DropdownMenuItem
                      key={provider.type}
                      onClick={() => handleAddProvider(provider)}
                    >
                      {provider.name}
                    </DropdownMenuItem>
                  ))}
                </DropdownMenuContent>
              </DropdownMenu>
            )}
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

        {isLoading ? (
          <Skeleton className="h-24 w-full" />
        ) : assets.length === 0 ? (
          <button
            type="button"
            onDrop={handleDrop}
            onDragOver={(e) => e.preventDefault()}
            onClick={() => fileInputRef.current?.click()}
            disabled={uploading}
            className="flex w-full cursor-pointer flex-col items-center justify-center gap-2 rounded-lg border-2 border-dashed border-border p-6 text-center transition-colors hover:border-foreground/30 disabled:pointer-events-none disabled:opacity-60"
          >
            <FileIcon className="size-8 text-muted-foreground" />
            <p className="text-muted-foreground text-sm">
              {uploading
                ? t('admin.digital_assets.uploading_short')
                : t('admin.digital_assets.drop_hint')}
            </p>
          </button>
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
        settingsSchema={
          providers.find((p) => p.type === editing?.provider_type)?.settings_schema ?? []
        }
        open={Boolean(editing)}
        onOpenChange={(open) => !open && setEditing(null)}
      />

      <DigitalAssetProviderSheet
        productId={productId}
        provider={configuring}
        onOpenChange={(open) => !open && setConfiguring(null)}
        onCreated={() => setPage(1)}
      />
    </Card>
  )
}
