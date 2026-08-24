import type { Media, MediaUsageReference } from '@spree/admin-sdk'
import {
  adminClient,
  Can,
  ImageUploadField,
  PageHeader,
  Subject,
  useDirectUpload,
  usePermissions,
} from '@spree/dashboard-core'
import {
  Badge,
  Button,
  ContextMenu,
  ContextMenuContent,
  ContextMenuItem,
  ContextMenuSeparator,
  ContextMenuTrigger,
  Field,
  FieldLabel,
  Input,
  MediaPreview,
  Pagination,
  SearchInput,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import {
  DownloadIcon,
  FilmIcon,
  ImageIcon,
  Loader2Icon,
  PencilIcon,
  PlayIcon,
  TrashIcon,
  UploadIcon,
} from 'lucide-react'
import { useDeferredValue, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import {
  mediaPreviewUrl,
  mediaThumbnailUrl,
  useCreateMediaLibraryFile,
  useDeleteMediaLibraryFile,
  useMediaLibrary,
  useMediaUsage,
  useUpdateMediaLibraryFile,
} from '../../../../hooks/use-media-library'

const PLACEMENT_FILTERS = ['all', 'attached', 'unattached'] as const
type PlacementFilter = (typeof PLACEMENT_FILTERS)[number]

const TYPE_FILTERS = ['all', 'image', 'video', 'external_video'] as const
type TypeFilter = (typeof TYPE_FILTERS)[number]

// Multiples of the widest grid (6 columns at lg), so a full page always ends
// on a complete row rather than a ragged one.
const PAGE_SIZES = [12, 24, 48]

// Page, search and filters live in the URL like every other list page, so
// refresh, the back button and a shared link land on the same view.
const mediaSearchSchema = z.object({
  page: z.coerce.number().optional().default(1),
  limit: z.coerce.number().optional().default(24),
  search: z.string().optional(),
  placement: z.enum(PLACEMENT_FILTERS).optional().default('all'),
  type: z.enum(TYPE_FILTERS).optional().default('all'),
})

export const Route = createFileRoute('/_authenticated/$storeId/products/media')({
  validateSearch: mediaSearchSchema,
  component: MediaLibraryPage,
})

function MediaLibraryPage() {
  const { t } = useTranslation()
  const confirm = useConfirm()
  const { permissions } = usePermissions()
  const searchParams = Route.useSearch()
  const navigate = useNavigate({ from: Route.fullPath })

  const { page, limit: perPage, placement, type: mediaType } = searchParams
  // The input is local so typing is instant; the URL carries the committed
  // value. `replace` keeps keystrokes from piling up as history entries.
  const [searchInput, setSearchInput] = useState(searchParams.search ?? '')
  const deferredSearch = useDeferredValue(searchParams.search ?? '')

  // Follow the URL when history navigation changes it out from under the
  // input; typing is a no-op here because patchSearch already synced them.
  const urlSearch = searchParams.search ?? ''
  const [lastUrlSearch, setLastUrlSearch] = useState(urlSearch)
  if (urlSearch !== lastUrlSearch) {
    setLastUrlSearch(urlSearch)
    setSearchInput(urlSearch)
  }

  const [selected, setSelected] = useState<Media | null>(null)
  const [uploading, setUploading] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  const directUpload = useDirectUpload()
  const createFile = useCreateMediaLibraryFile()
  const deleteFile = useDeleteMediaLibraryFile()

  function patchSearch(patch: Partial<z.infer<typeof mediaSearchSchema>>, replace = false) {
    // Narrowing the set can leave the current page past the end of it, so any
    // filter change starts over unless the patch is itself a page move.
    navigate({ search: (prev) => ({ ...prev, page: 1, ...patch }), replace })
  }

  // Flat Ransack keys — transformListParams wraps them into q[...] itself; a
  // nested `q` object would be stringified into q[q]=[object Object].
  const query = useMediaLibrary({
    page,
    limit: perPage,
    ...(deferredSearch.trim() ? { filename_cont: deferredSearch.trim() } : {}),
    ...(placement === 'all' ? {} : { [placement]: true }),
    ...(mediaType === 'all' ? {} : { media_type_eq: mediaType }),
  })

  const files = query.data?.data ?? []
  const meta = query.data?.meta
  const canWrite = permissions.can('update', Subject.Media)

  async function handleUpload(fileList: FileList | null) {
    if (!fileList?.length) return

    const files = Array.from(fileList)
    setUploading(true)
    let uploaded = 0

    try {
      for (const file of files) {
        // Per file, so one bad file doesn't discard the ones that worked and
        // the merchant is told which failed.
        try {
          const upload = await directUpload.mutateAsync(file)
          await createFile.mutateAsync({
            signed_id: upload.signedId,
            alt: file.name,
            media_type: file.type.startsWith('video/') ? 'video' : 'image',
          })
          uploaded += 1
        } catch {
          toastManager.add({
            type: 'error',
            title: t('admin.media_library.upload_failed', { name: file.name }),
          })
        }
      }

      if (uploaded > 0) {
        toastManager.add({
          type: 'success',
          title: t('admin.media_library.upload_succeeded', { count: uploaded }),
        })
      }
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  // The detail panel already has the usage loaded; the grid's context menu
  // does not, so it fetches on demand rather than every tile paying for it.
  async function handleDeleteFromGrid(media: Media) {
    const { data } = await adminClient.media.usage(media.id).catch(() => ({ data: [] }))
    await handleDelete(media, data)
  }

  async function handleDelete(media: Media, references: MediaUsageReference[]) {
    const name = media.alt || media.filename || ''
    const ok = await confirm({
      title: t('admin.media_library.delete_confirm.title'),
      // A file in use is deletable, but the merchant confirms knowing it
      // disappears from every place listed in the panel.
      message:
        references.length > 0
          ? t('admin.media_library.delete_confirm.in_use_message', {
              name,
              count: references.length,
            })
          : t('admin.media_library.delete_confirm.message', { name }),
      variant: 'destructive',
      confirmLabel: t('admin.actions.delete'),
    })
    if (!ok) return

    try {
      await deleteFile.mutateAsync({ id: media.id, detach: references.length > 0 })
      toastManager.add({ type: 'success', title: t('admin.media_library.deleted') })
      setSelected(null)
    } catch {
      // The panel stays open on failure so the merchant can see the usage and
      // retry rather than wondering whether it worked.
      toastManager.add({ type: 'error', title: t('admin.media_library.delete_failed') })
    }
  }

  return (
    <>
      <PageHeader
        title={t('admin.media_library.title')}
        subtitle={t('admin.media_library.description')}
        actions={
          <Can I="update" a={Subject.Media}>
            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept="image/png,image/jpeg,image/webp,image/gif,video/mp4,video/webm"
              className="hidden"
              onChange={(e) => handleUpload(e.target.files)}
            />
            <Button
              type="button"
              disabled={uploading}
              onClick={() => fileInputRef.current?.click()}
            >
              {uploading ? (
                <Loader2Icon className="size-4 animate-spin" />
              ) : (
                <UploadIcon className="size-4" />
              )}
              {t('admin.media_library.upload')}
            </Button>
          </Can>
        }
      />

      <div className="flex flex-col gap-3 px-4 pb-4 sm:flex-row sm:items-center">
        <SearchInput
          value={searchInput}
          onValueChange={(value) => {
            setSearchInput(value)
            patchSearch({ search: value || undefined }, true)
          }}
          placeholder={t('admin.media_library.search_placeholder')}
          clearLabel={t('admin.common.clear')}
          className="sm:max-w-xs"
        />

        <Select
          items={PLACEMENT_FILTERS.map((value) => ({
            value,
            label: t(`admin.media_library.placement.${value}`),
          }))}
          value={placement}
          onValueChange={(value) => patchSearch({ placement: value as PlacementFilter })}
        >
          <SelectTrigger className="sm:w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {PLACEMENT_FILTERS.map((value) => (
              <SelectItem key={value} value={value}>
                {t(`admin.media_library.placement.${value}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>

        <Select
          items={TYPE_FILTERS.map((value) => ({
            value,
            label: t(`admin.media_library.type.${value}`),
          }))}
          value={mediaType}
          onValueChange={(value) => patchSearch({ type: value as TypeFilter })}
        >
          <SelectTrigger className="sm:w-44">
            <SelectValue />
          </SelectTrigger>
          <SelectContent>
            {TYPE_FILTERS.map((value) => (
              <SelectItem key={value} value={value}>
                {t(`admin.media_library.type.${value}`)}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>

      <div className="px-4 pb-8">
        {query.isLoading ? (
          <div className="flex items-center justify-center py-16 text-muted-foreground">
            <Loader2Icon className="size-5 animate-spin" />
          </div>
        ) : files.length === 0 ? (
          <p className="py-16 text-center text-muted-foreground text-sm">
            {deferredSearch.trim() || placement !== 'all' || mediaType !== 'all'
              ? t('admin.media_library.no_results')
              : t('admin.media_library.empty')}
          </p>
        ) : (
          <ul className="grid grid-cols-2 gap-4 sm:grid-cols-4 lg:grid-cols-6">
            {files.map((media) => (
              <li key={media.id}>
                <ContextMenu>
                  <ContextMenuTrigger
                    render={
                      <button
                        type="button"
                        onClick={() => setSelected(media)}
                        className="block w-full overflow-hidden rounded-md border border-border text-left transition-colors hover:border-muted-foreground"
                      />
                    }
                  >
                    <MediaTile media={media} />
                    <span className="block truncate px-2 py-1.5 text-xs">
                      {media.alt || media.filename || ''}
                    </span>
                  </ContextMenuTrigger>

                  {/* A shortcut to what the detail panel already offers —
                      right-click is undiscoverable and absent on touch. */}
                  <ContextMenuContent>
                    <ContextMenuItem onClick={() => setSelected(media)}>
                      <PencilIcon />
                      {t('admin.actions.edit')}
                    </ContextMenuItem>
                    {media.download_url && (
                      // A click rather than an anchor: Base UI's `render`
                      // replaces the item, and the URL already carries a
                      // Content-Disposition attachment header, so navigating
                      // to it downloads rather than opening a page.
                      <ContextMenuItem
                        onClick={() => {
                          window.location.href = media.download_url as string
                        }}
                      >
                        <DownloadIcon />
                        {t('admin.media_library.download')}
                      </ContextMenuItem>
                    )}
                    {canWrite && (
                      <>
                        <ContextMenuSeparator />
                        <ContextMenuItem
                          variant="destructive"
                          onClick={() => handleDeleteFromGrid(media)}
                        >
                          <TrashIcon />
                          {t('admin.actions.delete')}
                        </ContextMenuItem>
                      </>
                    )}
                  </ContextMenuContent>
                </ContextMenu>
              </li>
            ))}
          </ul>
        )}

        {meta && files.length > 0 && (
          <div className="pt-4">
            <Pagination
              meta={meta}
              pageSizeOptions={PAGE_SIZES}
              onPageChange={(next) => patchSearch({ page: next })}
              onPageSizeChange={(size) => patchSearch({ limit: size })}
            />
          </div>
        )}
      </div>

      <MediaDetailSheet
        media={selected}
        onOpenChange={(open) => !open && setSelected(null)}
        canWrite={canWrite}
      />
    </>
  )
}

// One cell of the grid: a still, never a player — dozens of video elements in
// one view is not a gallery. The detail panel uses MediaPreview, which plays.
function MediaTile({ media }: { media: Media }) {
  const thumbnail = mediaThumbnailUrl(media)

  return (
    <span className="relative flex aspect-square items-center justify-center bg-muted">
      {thumbnail ? (
        <img
          src={thumbnail}
          alt={media.alt ?? ''}
          loading="lazy"
          className="size-full object-cover"
        />
      ) : (
        // A video with no poster has no still to show — say so with the film
        // icon rather than a broken-image placeholder.
        <MediaPlaceholderIcon media={media} />
      )}
      {media.media_type !== 'image' && (
        <span className="absolute top-1.5 left-1.5 rounded bg-black/60 p-1 text-white">
          <PlayIcon className="size-3" />
        </span>
      )}
    </span>
  )
}

function MediaPlaceholderIcon({ media }: { media: Media }) {
  const Icon = media.media_type === 'image' ? ImageIcon : FilmIcon

  return <Icon className="size-6 text-muted-foreground" />
}

function MediaDetailSheet({
  media,
  onOpenChange,
  canWrite,
}: {
  media: Media | null
  onOpenChange: (open: boolean) => void
  canWrite: boolean
}) {
  const { t } = useTranslation()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const updateFile = useUpdateMediaLibraryFile()
  const usage = useMediaUsage(media?.id ?? null)
  const [alt, setAlt] = useState('')
  const [poster, setPoster] = useState<{
    signedId: string | null
    previewUrl: string | null
    cleared: boolean
  }>({ signedId: null, previewUrl: null, cleared: false })

  // Seeded from the record each time a different file is opened, so typing is
  // not overwritten by a background refetch of the same row.
  const [seededFor, setSeededFor] = useState<string | null>(null)
  if (media && seededFor !== media.id) {
    setSeededFor(media.id)
    setAlt(media.alt ?? '')
    setPoster({ signedId: null, previewUrl: null, cleared: false })
  }

  const references = usage.data?.data ?? []

  const isDirty = !!media && alt !== (media.alt ?? '')

  // An explicit save, not save-on-blur: blur is invisible, so a merchant had
  // no way to tell whether their edit stuck.
  function saveAlt() {
    if (!media || !isDirty) return

    updateFile.mutate(
      { id: media.id, alt },
      {
        onSuccess: () => toastManager.add({ type: 'success', title: t('admin.messages.saved') }),
        onError: () => toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') }),
      },
    )
  }

  // Closing with an unsaved edit would drop it silently, so ask first.
  async function handleOpenChange(open: boolean) {
    if (open || !isDirty) return onOpenChange(open)

    const discard = await confirm({
      title: t('admin.media_library.discard_confirm.title'),
      message: t('admin.media_library.discard_confirm.message'),
      variant: 'destructive',
      confirmLabel: t('admin.media_library.discard_confirm.confirm'),
    })
    if (discard) onOpenChange(false)
  }

  // The poster saves on the spot — picking a file is already an explicit act,
  // and there is no surrounding form to carry it.
  function savePoster(value: {
    signedId: string | null
    previewUrl: string | null
    cleared: boolean
  }) {
    if (!media) return

    setPoster(value)
    // '' drops the poster; undefined would fall out of the body and leave it.
    updateFile.mutate({
      id: media.id,
      poster_signed_id: value.cleared ? '' : (value.signedId ?? undefined),
    })
  }

  return (
    <Sheet open={!!media} onOpenChange={handleOpenChange}>
      <SheetContent className="w-full sm:max-w-md">
        {media && (
          <>
            <SheetHeader>
              <SheetTitle>{media.filename || t('admin.media_library.file')}</SheetTitle>
              <SheetDescription>
                {media.attached
                  ? t('admin.media_library.placement.attached')
                  : t('admin.media_library.placement.unattached')}
              </SheetDescription>
            </SheetHeader>

            <div className="flex-1 space-y-5 overflow-y-auto p-4">
              <MediaPreview
                mediaType={media.media_type}
                previewUrl={mediaPreviewUrl(media)}
                videoUrl={media.video_url}
                embedUrl={media.video_embed_url}
                alt={media.alt ?? ''}
              />

              {/* A video needs a still for gallery tiles, emails and every
                  listing that renders an <img>. YouTube supplies one; an
                  upload or a Vimeo link does not. */}
              {media.media_type !== 'image' && canWrite && (
                <ImageUploadField
                  label={t('admin.fields.media.poster.label')}
                  help={t('admin.fields.media.poster.help')}
                  serverUrl={media.poster_url}
                  value={poster}
                  onChange={savePoster}
                />
              )}

              <Field>
                <FieldLabel htmlFor="media-alt">{t('admin.fields.media.alt.label')}</FieldLabel>
                <Input
                  id="media-alt"
                  value={alt}
                  disabled={!canWrite}
                  onChange={(e) => setAlt(e.target.value)}
                  // Enter saves, like any single-field form.
                  onKeyDown={(e) => {
                    if (e.key === 'Enter' && isDirty) {
                      e.preventDefault()
                      saveAlt()
                    }
                  }}
                  placeholder={t('admin.fields.media.alt.placeholder')}
                />
              </Field>

              <dl className="space-y-2 text-sm">
                <FileFact label={t('admin.media_library.facts.type')} value={media.content_type} />
                <FileFact
                  label={t('admin.media_library.facts.size')}
                  value={formatBytes(media.byte_size)}
                />
              </dl>

              <div>
                <h3 className="mb-2 font-medium text-sm">{t('admin.media_library.usage.title')}</h3>
                {usage.isLoading ? (
                  <Loader2Icon className="size-4 animate-spin text-muted-foreground" />
                ) : references.length === 0 ? (
                  <p className="text-muted-foreground text-sm">
                    {t('admin.media_library.usage.empty')}
                  </p>
                ) : (
                  <ul className="space-y-1.5">
                    {references.map((reference) => {
                      const target = usageLink(reference)

                      return (
                        <li
                          key={`${reference.kind}-${reference.owner_type}-${reference.owner_id}-${reference.field}`}
                          className="flex items-center justify-between gap-2 text-sm"
                        >
                          {target ? (
                            <Link
                              to={target.to}
                              params={{ storeId, ...target.params }}
                              className="truncate underline-offset-4 hover:underline"
                            >
                              {reference.name}
                            </Link>
                          ) : (
                            <span className="truncate">{reference.name}</span>
                          )}
                          <Badge variant="secondary">{usageBadgeLabel(reference, t)}</Badge>
                        </li>
                      )
                    })}
                  </ul>
                )}
              </div>
            </div>

            {canWrite && (
              // Cancel / Save, matching the product gallery's edit sheet.
              // Deleting a file is not editing it — that lives in the grid's
              // context menu, away from the field a merchant is typing in.
              <SheetFooter className="flex-row justify-end">
                <Button type="button" variant="outline" onClick={() => onOpenChange(false)}>
                  {t('admin.actions.cancel')}
                </Button>
                <Button type="button" disabled={!isDirty || updateFile.isPending} onClick={saveAlt}>
                  {updateFile.isPending && <Loader2Icon className="size-4 animate-spin" />}
                  {t('admin.actions.save')}
                </Button>
              </SheetFooter>
            )}
          </>
        )}
      </SheetContent>
    </Sheet>
  )
}

const USAGE_OWNER_LABELS: Record<string, string> = {
  'Spree::Product': 'product',
  'Spree::Variant': 'variant',
  'Spree::Taxon': 'category',
  'Spree::Category': 'category',
  'Spree::Collection': 'collection',
}

// A placement's badge names what kind of place it is — a category placement
// labeled "Product" would be wrong. Non-placement kinds (a bare image field, a
// description embed) keep their kind label.
function usageBadgeLabel(reference: MediaUsageReference, t: (key: string) => string): string {
  if (reference.kind === 'media') {
    const owner = USAGE_OWNER_LABELS[reference.owner_type]
    if (owner) return t(`admin.media_library.usage.owner.${owner}`)
  }

  return t(`admin.media_library.usage.kind.${reference.kind}`)
}

// Where a usage reference points in the dashboard. Anything without an edit
// screen of its own — or missing an id — stays plain text rather than a link
// that goes nowhere.
function usageLink(
  reference: MediaUsageReference,
): { to: string; params: Record<string, string> } | null {
  if (!reference.owner_id) return null

  switch (reference.owner_type) {
    case 'Spree::Product':
      return {
        to: '/$storeId/products/$productId',
        params: { productId: reference.owner_id },
      }
    case 'Spree::Variant':
      return null
    case 'Spree::Taxon':
    case 'Spree::Category':
      return {
        to: '/$storeId/products/categories/$categoryId',
        params: { categoryId: reference.owner_id },
      }
    case 'Spree::Collection':
      return {
        to: '/$storeId/products/collections/$collectionId',
        params: { collectionId: reference.owner_id },
      }
    case 'Spree::Seller':
      return {
        to: '/$storeId/sellers/$sellerId',
        params: { sellerId: reference.owner_id },
      }
    default:
      return null
  }
}

function FileFact({ label, value }: { label: string; value?: string | null }) {
  if (!value) return null

  return (
    <div className="flex items-center justify-between gap-2">
      <dt className="text-muted-foreground">{label}</dt>
      <dd className="truncate">{value}</dd>
    </div>
  )
}

function formatBytes(bytes?: number | null): string | null {
  if (!bytes) return null

  const units = ['B', 'KB', 'MB', 'GB']
  let value = bytes
  let unit = 0
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024
    unit += 1
  }

  return `${value.toFixed(unit === 0 ? 0 : 1)} ${units[unit]}`
}
