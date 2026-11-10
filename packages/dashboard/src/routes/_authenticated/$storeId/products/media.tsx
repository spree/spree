import type { Media, MediaUsageReference } from '@spree/admin-sdk'
import { MEDIA_TYPES } from '@spree/core'
import {
  adminClient,
  Can,
  extensionFormValues,
  extensionSubmitValues,
  formatMediaBytes,
  ImageUploadField,
  MediaEditorDialog,
  MediaEditorSection,
  MediaFilterChip,
  MediaListHeader,
  MediaRowBody,
  MediaTileBody,
  MediaViewMenu,
  mapSpreeErrorsToForm,
  mediaFileTypeLabel,
  mediaListClassName,
  mediaRowClassName,
  mediaTileClassName,
  PageHeader,
  Slot,
  SortMenu,
  Subject,
  useFileUpload,
  useMediaView,
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
  cn,
  Field,
  FieldLabel,
  Input,
  MediaPreview,
  Pagination,
  SearchInput,
  toastManager,
  useConfirm,
} from '@spree/dashboard-ui'
import {
  DownloadIcon,
  ImageIcon,
  InfoIcon,
  Loader2Icon,
  PencilIcon,
  TrashIcon,
  UploadIcon,
} from '@spree/dashboard-ui/icons'
import { createFileRoute, Link, useNavigate } from '@tanstack/react-router'
import {
  type ReactElement,
  type ReactNode,
  useDeferredValue,
  useEffect,
  useRef,
  useState,
} from 'react'
import { FormProvider, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod'
import {
  DraftCustomFieldsCard,
  useCustomFieldsDraft,
} from '../../../../components/spree/custom-fields/custom-fields-inline'
import {
  mediaPreviewUrl,
  useCreateMediaLibraryFile,
  useDeleteMediaLibraryFile,
  useMediaLibrary,
  useMediaUsage,
  useUpdateMediaLibraryFile,
} from '../../../../hooks/use-media-library'

const PLACEMENT_FILTERS = ['all', 'attached', 'unattached'] as const
type PlacementFilter = (typeof PLACEMENT_FILTERS)[number]

const TYPE_FILTERS = ['all', ...MEDIA_TYPES] as const
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
  sort: z.enum(['created_at', 'filename', 'byte_size']).optional().default('created_at'),
  direction: z.enum(['asc', 'desc']).optional().default('desc'),
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

  const { page, limit: perPage, placement, type: mediaType, sort, direction } = searchParams
  const [view, setView] = useMediaView()
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

  const fileUpload = useFileUpload()
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
    sort: `${direction === 'desc' ? '-' : ''}${sort}` as const,
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
          const upload = await fileUpload.mutateAsync(file)
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
      {/* The same shell `ResourceTable` builds: the page's own header on the
          sheet, the controls under it, and the card holding only the content. */}
      <div className="flex flex-col gap-3">
        <PageHeader
          sticky={false}
          title={t('admin.media_library.title')}
          description={t('admin.media_library.description')}
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
                <span>{t('admin.media_library.upload')}</span>
              </Button>
            </Can>
          }
        />

        {/* The media picker's toolbar, so the library reads the same on its
            page and in the dialog: search, sort and view on one row, the
            filters as chips under it. */}
        <div className="flex flex-col gap-3">
          <div className="flex items-center gap-2">
            <SearchInput
              value={searchInput}
              onValueChange={(value) => {
                setSearchInput(value)
                patchSearch({ search: value || undefined }, true)
              }}
              placeholder={t('admin.media_library.search_placeholder')}
              clearLabel={t('admin.common.clear')}
              className="h-11 max-w-xl flex-1 lg:h-[2.125rem]"
            />
            <div className="ms-auto flex items-center gap-2">
              <SortMenu
                columns={[
                  { key: 'created_at', label: t('admin.media_picker.sort_date_added') },
                  { key: 'filename', label: t('admin.media_picker.sort_file_name') },
                  { key: 'byte_size', label: t('admin.media_picker.sort_file_size') },
                ]}
                sort={{ field: sort, direction }}
                onSortChange={(next) =>
                  patchSearch({
                    sort: next.field as typeof sort,
                    direction: next.direction,
                  })
                }
              />
              <MediaViewMenu view={view} onViewChange={setView} />
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <MediaFilterChip
              label={t('admin.media_picker.filter_type')}
              value={mediaType}
              onChange={(value) => patchSearch({ type: value as TypeFilter })}
              options={TYPE_FILTERS.map((value) => ({
                value,
                label: t(`admin.media_library.type.${value}`),
              }))}
            />
            <MediaFilterChip
              label={t('admin.media_picker.filter_usage')}
              value={placement}
              onChange={(value) => patchSearch({ placement: value as PlacementFilter })}
              options={PLACEMENT_FILTERS.map((value) => ({
                value,
                label: t(`admin.media_library.placement.${value}`),
              }))}
            />
          </div>
        </div>

        {/* No card around the grid: each tile already carries its own frame, so
            boxing them drew a second border around a set of borders. The sheet
            is the surface they sit on. */}
        <div>
          {query.isLoading ? (
            <div className="flex items-center justify-center py-16 text-muted-foreground">
              <Loader2Icon className="size-5 animate-spin" />
            </div>
          ) : files.length === 0 ? (
            <p className="py-16 text-center text-muted-foreground text-base">
              {deferredSearch.trim() || placement !== 'all' || mediaType !== 'all'
                ? t('admin.media_library.no_results')
                : t('admin.media_library.empty')}
            </p>
          ) : (
            <div>
              {view === 'list' && <MediaListHeader trailingClassName={USAGE_COLUMN} />}
              <ul
                className={
                  view === 'grid'
                    ? 'grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-6'
                    : mediaListClassName
                }
              >
                {files.map((media) => (
                  <li key={media.id}>
                    <MediaFileMenu
                      media={media}
                      canWrite={canWrite}
                      onEdit={() => setSelected(media)}
                      onDelete={() => handleDeleteFromGrid(media)}
                      trigger={
                        <button
                          type="button"
                          onClick={() => setSelected(media)}
                          className={view === 'grid' ? mediaTileClassName() : mediaRowClassName()}
                        />
                      }
                    >
                      {view === 'grid' ? (
                        <MediaTileBody media={media} />
                      ) : (
                        <MediaRowBody
                          media={media}
                          trailing={
                            <span
                              className={cn(
                                USAGE_COLUMN,
                                'text-right text-muted-foreground text-xs',
                              )}
                            >
                              {t(
                                `admin.media_library.placement.${media.attached ? 'attached' : 'unattached'}`,
                              )}
                            </span>
                          }
                        />
                      )}
                    </MediaFileMenu>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {meta && files.length > 0 && (
          <Pagination
            meta={meta}
            pageSizeOptions={PAGE_SIZES}
            onPageChange={(next) => patchSearch({ page: next })}
            onPageSizeChange={(size) => patchSearch({ limit: size })}
          />
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

/**
 * A file's right-click menu, around whichever shape the view draws it in. A
 * shortcut to what the detail panel already offers — right-click is
 * undiscoverable and absent on touch.
 */
// The media page's own column after `MediaRowBody`'s: where the file is used.
const USAGE_COLUMN = 'hidden w-24 shrink-0 md:block'

function MediaFileMenu({
  media,
  canWrite,
  onEdit,
  onDelete,
  trigger,
  children,
}: {
  media: Media
  canWrite: boolean
  onEdit: () => void
  onDelete: () => void
  trigger: ReactElement
  children: ReactNode
}) {
  const { t } = useTranslation()
  return (
    <ContextMenu>
      <ContextMenuTrigger render={trigger}>{children}</ContextMenuTrigger>
      <ContextMenuContent>
        <ContextMenuItem onClick={onEdit}>
          <PencilIcon />
          {t('admin.actions.edit')}
        </ContextMenuItem>
        {media.download_url && (
          // A click rather than an anchor: Base UI's `render` replaces the
          // item, and the URL already carries a Content-Disposition
          // attachment header, so navigating to it downloads.
          <ContextMenuItem
            onClick={() => {
              window.location.href = media.download_url as string
            }}
          >
            <DownloadIcon />
            {t('admin.media_library.download')}
          </ContextMenuItem>
        )}
        <Slot name="media.context_menu" context={{ media, canWrite }} />
        {canWrite && (
          <>
            <ContextMenuSeparator />
            <ContextMenuItem variant="destructive" onClick={onDelete}>
              <TrashIcon />
              {t('admin.actions.delete')}
            </ContextMenuItem>
          </>
        )}
      </ContextMenuContent>
    </ContextMenu>
  )
}

interface MediaDetailFormValues {
  alt: string
}

function mediaDetailFormValues(media: Media): MediaDetailFormValues {
  return { alt: media.alt ?? '', ...extensionFormValues('media', media) }
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
  const { t, i18n } = useTranslation()
  const { storeId } = Route.useParams()
  const confirm = useConfirm()
  const updateFile = useUpdateMediaLibraryFile()
  const usage = useMediaUsage(media?.id ?? null)
  // A host form for `media.form_fields` widgets: what they bind saves with the
  // sheet's Save, alongside the alt text.
  const form = useForm<MediaDetailFormValues>({ defaultValues: { alt: '' } })
  const [poster, setPoster] = useState<{
    signedId: string | null
    previewUrl: string | null
    cleared: boolean
  }>({ signedId: null, previewUrl: null, cleared: false })

  // Seeded from the record each time a different file is opened, so typing is
  // not overwritten by a background refetch of the same row.
  // Cleared on close, so reopening the same file drops what was discarded.
  const [seededFor, setSeededFor] = useState<string | null>(null)
  if (!media && seededFor !== null) setSeededFor(null)
  if (media && seededFor !== media.id) {
    setSeededFor(media.id)
    setPoster({ signedId: null, previewUrl: null, cleared: false })
  }
  // biome-ignore lint/correctness/useExhaustiveDependencies: keyed on the file, not on each refetch of it
  useEffect(() => {
    if (media) form.reset(mediaDetailFormValues(media))
  }, [seededFor, form])

  const references = usage.data?.data ?? []

  const customFields = useCustomFieldsDraft('media', media?.id ?? '')
  const isDirty = !!media && (form.formState.isDirty || customFields.isDirty)

  // An explicit save, not save-on-blur: blur is invisible, so a merchant had
  // no way to tell whether their edit stuck.
  async function save(values: MediaDetailFormValues) {
    if (!media || !isDirty) return

    try {
      if (form.formState.isDirty) {
        const submitted = form.getValues()
        await updateFile.mutateAsync({
          id: media.id,
          alt: values.alt,
          ...extensionSubmitValues('media', form),
        })
        // Re-baselined against what was just saved, not the record the sheet
        // opened with: that snapshot never refreshes, so after a save every
        // close would otherwise ask to discard. Also keeps a retry after a
        // failed custom field save from re-sending the file. An edit typed
        // while the request was out stays on screen and stays unsaved.
        form.reset(submitted, { keepValues: true })
      }
      if (await customFields.save()) {
        toastManager.add({ type: 'success', title: t('admin.messages.saved') })
      }
    } catch (error) {
      if (!mapSpreeErrorsToForm(error, form.setError)) {
        toastManager.add({ type: 'error', title: t('admin.errors.failed_to_save') })
      }
    }
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

  // The poster saves on the spot — picking a file is already an explicit act.
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

  if (!media) return null

  const details = [mediaFileTypeLabel(media), formatMediaBytes(media.byte_size, i18n.language)]
    .filter(Boolean)
    .join(' · ')

  return (
    <FormProvider {...form}>
      <MediaEditorDialog
        open
        onOpenChange={handleOpenChange}
        title={media.filename || t('admin.media_library.file')}
        description={
          media.attached
            ? t('admin.media_library.placement.attached')
            : t('admin.media_library.placement.unattached')
        }
        // A form, so Enter in any field saves, like any single-field form.
        onSubmit={form.handleSubmit(save)}
        actions={
          canWrite && (
            // Deleting a file is not editing it — that lives in the grid's
            // context menu, away from the field a merchant is typing in.
            <>
              <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button type="submit" disabled={!isDirty || form.formState.isSubmitting}>
                {form.formState.isSubmitting && <Loader2Icon className="size-4 animate-spin" />}
                <span>{t('admin.actions.save')}</span>
              </Button>
            </>
          )
        }
        preview={
          <MediaPreview
            fit="stage"
            mediaType={media.media_type}
            previewUrl={mediaPreviewUrl(media)}
            videoUrl={media.video_url}
            embedUrl={media.video_embed_url}
            alt={form.watch('alt')}
          />
        }
      >
        <MediaEditorSection icon={<InfoIcon />} title={t('admin.media_editor.information')}>
          {form.formState.errors.root?.message && (
            <p className="text-destructive text-base" role="alert">
              {form.formState.errors.root.message}
            </p>
          )}

          <Field>
            <FieldLabel htmlFor="media-alt">{t('admin.fields.media.alt.label')}</FieldLabel>
            <Input
              id="media-alt"
              disabled={!canWrite}
              placeholder={t('admin.fields.media.alt.placeholder')}
              {...form.register('alt')}
            />
          </Field>

          <Slot name="media.form_fields" context={{ media, canWrite }} />

          <div className="flex flex-col gap-1 text-base">
            <span className="font-medium">{t('admin.media_editor.details')}</span>
            {details && <span className="text-muted-foreground">{details}</span>}
            <span className="text-muted-foreground">
              {t('admin.media_editor.added', {
                date: new Date(media.created_at).toLocaleDateString(i18n.language, {
                  day: 'numeric',
                  month: 'short',
                  year: 'numeric',
                }),
              })}
            </span>
          </div>

          <div className="flex flex-col gap-1.5 text-base">
            <span className="font-medium">{t('admin.media_library.usage.title')}</span>
            {usage.isLoading ? (
              <Loader2Icon className="size-4 animate-spin text-muted-foreground" />
            ) : references.length === 0 ? (
              <span className="text-muted-foreground">{t('admin.media_library.usage.empty')}</span>
            ) : (
              <ul className="space-y-1.5">
                {references.map((reference) => {
                  const target = usageLink(reference)

                  return (
                    <li
                      key={`${reference.kind}-${reference.owner_type}-${reference.owner_id}-${reference.field}`}
                      className="flex items-center justify-between gap-2"
                    >
                      {target ? (
                        <Link
                          to={target.to}
                          params={{ storeId, ...target.params }}
                          className="truncate text-link underline-offset-4 hover:underline"
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
        </MediaEditorSection>

        {/* A video needs a still for gallery tiles, emails and every listing
            that renders an <img>. YouTube supplies one; an upload or a Vimeo
            link does not. */}
        {media.media_type !== 'image' && canWrite && (
          <MediaEditorSection icon={<ImageIcon />} title={t('admin.fields.media.poster.label')}>
            <ImageUploadField
              help={t('admin.fields.media.poster.help')}
              serverUrl={media.poster_url}
              value={poster}
              onChange={savePoster}
            />
          </MediaEditorSection>
        )}

        {canWrite && <DraftCustomFieldsCard draft={customFields} hideWhenEmpty />}
      </MediaEditorDialog>
    </FormProvider>
  )
}

const USAGE_OWNER_LABELS = new Set(['product', 'variant', 'category', 'collection'])

// A placement's badge names what kind of place it is — a category placement
// labeled "Product" would be wrong. Non-placement kinds (a bare image field, a
// description embed) keep their kind label.
function usageBadgeLabel(reference: MediaUsageReference, t: (key: string) => string): string {
  if (reference.kind === 'media') {
    if (USAGE_OWNER_LABELS.has(reference.owner_type)) {
      return t(`admin.media_library.usage.owner.${reference.owner_type}`)
    }
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
    case 'product':
      return {
        to: '/$storeId/products/$productId',
        params: { productId: reference.owner_id },
      }
    case 'variant':
      return null
    case 'category':
      return {
        to: '/$storeId/products/categories/$categoryId',
        params: { categoryId: reference.owner_id },
      }
    case 'collection':
      return {
        to: '/$storeId/products/collections/$collectionId',
        params: { collectionId: reference.owner_id },
      }
    case 'seller':
      return {
        to: '/$storeId/sellers/$sellerId',
        params: { sellerId: reference.owner_id },
      }
    default:
      return null
  }
}
