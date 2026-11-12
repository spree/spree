import {
  Button,
  Checkbox,
  cn,
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuTrigger,
  SearchInput,
} from '@spree/dashboard-ui'
import {
  ChevronsUpDownIcon,
  ImageIcon,
  LayoutGridIcon,
  ListIcon,
  Loader2Icon,
  PlayIcon,
  UploadIcon,
} from '@spree/dashboard-ui/icons'
import { useQuery } from '@tanstack/react-query'
import {
  type DragEvent,
  type ReactNode,
  useCallback,
  useDeferredValue,
  useRef,
  useState,
} from 'react'
import { useTranslation } from 'react-i18next'
import { useTenantId } from '../providers/tenant-provider'
import { SortMenu } from './table-toolbar'

/** The shape the picker needs; a full Media record satisfies it. */
export interface MediaPickerOption {
  id: string
  alt?: string | null
  filename?: string | null
  media_type?: string
  small_url?: string | null
  poster_url?: string | null
  original_url?: string | null
  /** Blob signed id, for handing a picked file to a plain attachment field. */
  signed_id?: string | null
  created_at?: string | null
  byte_size?: number | null
}

/** The picker's own controls, handed to `search` alongside the query. */
export interface MediaPickerSearchOptions {
  sort: { field: 'created_at' | 'filename' | 'byte_size'; direction: 'asc' | 'desc' }
  mediaType: 'all' | 'image' | 'video'
  usage: 'all' | 'used' | 'unused'
}

/**
 * Turns the picker's query and controls into media list params, for callers
 * that search the Admin API's media endpoint:
 * `search={(query, options) => adminClient.media.list({ limit: 48, ...mediaPickerListParams(query, options) })}`.
 */
export function mediaPickerListParams(query: string, options?: MediaPickerSearchOptions) {
  return {
    ...(query ? { filename_cont: query } : {}),
    sort: options
      ? (`${options.sort.direction === 'desc' ? '-' : ''}${options.sort.field}` as const)
      : ('-created_at' as const),
    ...(options?.mediaType === 'image' ? { media_type_eq: 'image' as const } : {}),
    ...(options?.mediaType === 'video'
      ? { media_type_in: ['video' as const, 'external_video' as const] }
      : {}),
    ...(options?.usage === 'used' ? { attached: true } : {}),
    ...(options?.usage === 'unused' ? { unattached: true } : {}),
  }
}

export interface MediaPickerDialogProps<T extends MediaPickerOption> {
  open: boolean
  onOpenChange: (open: boolean) => void
  /**
   * Paginated search over the library, called with the trimmed query and the
   * picker's sort and filters. `mediaPickerListParams` maps both to the media
   * endpoint's params.
   */
  search: (query: string, options: MediaPickerSearchOptions) => Promise<{ data: T[] }>
  /** Called with the picked files when the user confirms. */
  onConfirm: (media: T[]) => void | Promise<void>
  /** Uploads a file and returns the created library row. */
  onUpload?: (file: File) => Promise<T>
  /** One file only — the picker confirms as soon as a file is clicked. */
  multiple?: boolean
  /** Cache-isolation key, one per picker instance. */
  queryKey: string
  /** File types the upload accepts. A list naming video also offers the Type filter. */
  accept?: string
  title?: string
  description?: string
  confirmLabel?: string
  onConfirmError?: (error: unknown) => void
  /**
   * Files ticked when the picker opens — what the host already has. Records,
   * not ids, so one outside the loaded page or the current filter still
   * counts and survives Done.
   */
  initialSelection?: T[]
  /**
   * Lets Done confirm with nothing ticked, for a host where the picked set is
   * the whole answer (un-ticking every file clears it).
   */
  allowEmptyConfirm?: boolean
  /**
   * Sort and the library filters. Off for a short, local list — a product's
   * own images — where they would narrow nothing; search and view stay.
   */
  browseControls?: boolean
  /**
   * Labels the first ticked file in list order — what a host derives from
   * that order, such as a variant's thumbnail — and moves as files are ticked.
   */
  firstSelectedBadge?: string
}

export type MediaView = 'grid' | 'list'
const VIEW_STORAGE_KEY = 'spree-media-view'

function readView(): MediaView {
  try {
    return localStorage.getItem(VIEW_STORAGE_KEY) === 'list' ? 'list' : 'grid'
  } catch {
    return 'grid'
  }
}

/**
 * Grid or list for browsing media, remembered per browser and shared by the
 * media library page and the picker, so one choice holds in both.
 */
export function useMediaView(): [MediaView, (view: MediaView) => void] {
  const [view, setView] = useState<MediaView>(readView)
  const change = useCallback((next: MediaView) => {
    setView(next)
    try {
      localStorage.setItem(VIEW_STORAGE_KEY, next)
    } catch {
      // A blocked store only means the choice is not remembered.
    }
  }, [])
  return [view, change]
}

/**
 * The grid/list switch, sized and styled as the sort button beside it — the
 * resource table toolbar's controls — rather than a segmented control.
 */
export function MediaViewMenu({
  view,
  onViewChange,
}: {
  view: MediaView
  onViewChange: (view: MediaView) => void
}) {
  const { t } = useTranslation()
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="h-11 lg:h-[2.125rem]"
          aria-label={t('admin.media_picker.view')}
        >
          {view === 'grid' ? (
            <LayoutGridIcon className="size-4" />
          ) : (
            <ListIcon className="size-4" />
          )}
          <ChevronsUpDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="min-w-40">
        {/* A two-way switch, so a pick closes the menu — unlike the sort
            menu, where a field and a direction are often picked together. */}
        <DropdownMenuRadioGroup
          value={view}
          onValueChange={(next) => onViewChange(next as MediaView)}
        >
          <DropdownMenuRadioItem value="grid" closeOnClick>
            <LayoutGridIcon className="size-4" />
            {t('admin.media_picker.view_grid')}
          </DropdownMenuRadioItem>
          <DropdownMenuRadioItem value="list" closeOnClick>
            <ListIcon className="size-4" />
            {t('admin.media_picker.view_list')}
          </DropdownMenuRadioItem>
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}

/** "18.1 kB", "2.4 MB" — in the admin's own number format. */
export function formatMediaBytes(bytes: number | null | undefined, language: string): string {
  if (bytes == null) return ''
  const [value, unit] =
    bytes >= 1_000_000 ? [bytes / 1_000_000, 'megabyte'] : [bytes / 1_000, 'kilobyte']
  return new Intl.NumberFormat(language, {
    style: 'unit',
    unit,
    unitDisplay: 'short',
    maximumFractionDigits: 1,
  }).format(value)
}

/** "JPG", "MP4" — from the file's extension, falling back to its media type. */
export function mediaFileTypeLabel(media: MediaPickerOption): string {
  const extension = media.filename?.split('.').pop()
  if (extension && extension !== media.filename) return extension.toUpperCase()
  if (media.media_type === 'external_video') return 'URL'
  return media.media_type?.toUpperCase() ?? ''
}

function acceptsFile(accept: string, file: File): boolean {
  return accept.split(',').some((rule) => {
    const type = rule.trim()
    return type.endsWith('/*') ? file.type.startsWith(type.slice(0, -1)) : file.type === type
  })
}

/**
 * Browse the store's media library and pick files from it.
 *
 * A dialog rather than a side sheet: choosing a picture means looking at it,
 * so the library gets the width for a real grid, with search, sort, filters, a
 * list view for finding a file by name, and a drop zone for adding new ones.
 *
 * Headless — the caller supplies `search` and `onUpload`, so the same dialog
 * serves the product media card (which places files on a product) and plain
 * image fields (which take the picked file's blob).
 */
export function MediaPickerDialog<T extends MediaPickerOption>({
  open,
  onOpenChange,
  search,
  onConfirm,
  onUpload,
  multiple = true,
  queryKey,
  accept = 'image/png,image/jpeg,image/webp,image/gif',
  title,
  description,
  confirmLabel,
  onConfirmError,
  initialSelection,
  allowEmptyConfirm = false,
  browseControls = true,
  firstSelectedBadge,
}: MediaPickerDialogProps<T>) {
  const { t } = useTranslation()
  const tenantId = useTenantId()

  const [input, setInput] = useState('')
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()
  const [sort, setSort] = useState<MediaPickerSearchOptions['sort']>({
    field: 'created_at',
    direction: 'desc',
  })
  const [mediaType, setMediaType] = useState<MediaPickerSearchOptions['mediaType']>('all')
  const [usage, setUsage] = useState<MediaPickerSearchOptions['usage']>('all')
  const [view, changeView] = useMediaView()
  const [staged, setStaged] = useState<Map<string, T>>(new Map())
  const [submitting, setSubmitting] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [dragging, setDragging] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)
  // Bumped whenever the dialog closes. An upload started in an earlier session
  // must not confirm into a host that has already moved on — closing mid-upload
  // would otherwise still set the field the merchant cancelled.
  const sessionRef = useRef(0)

  const offersVideo = accept.includes('video')
  const options: MediaPickerSearchOptions = { sort, mediaType, usage }

  // The tenant id is part of the key: a library is one tenant's, and without
  // it reopening the picker after a store or seller switch serves the previous
  // tenant's files from cache — whose ids the new tenant's API would reject.
  const { data, isFetching, refetch } = useQuery({
    queryKey: [
      queryKey,
      'media-picker',
      tenantId,
      trimmedQuery,
      sort.field,
      sort.direction,
      mediaType,
      usage,
    ],
    queryFn: () => search(trimmedQuery, options),
    enabled: open,
    staleTime: 30_000,
  })

  const results = data?.data ?? []
  // Tick what the host already has, once per opening — a later render must
  // not undo what the merchant changed since.
  const [seeded, setSeeded] = useState(false)
  if (!open && seeded) setSeeded(false)
  if (open && !seeded && initialSelection?.length) {
    setSeeded(true)
    setStaged(new Map(initialSelection.map((media) => [media.id, media])))
  }
  const filtered = !!trimmedQuery || mediaType !== 'all' || usage !== 'all'
  // Only over the whole list: a search or filter hides files, and the first
  // ticked one left showing need not be the first in the host's order.
  const firstSelectedId =
    firstSelectedBadge && !filtered ? results.find((media) => staged.has(media.id))?.id : undefined

  async function pick(option: T) {
    if (!multiple) {
      await submit([option])
      return
    }

    setStaged((prev) => {
      const next = new Map(prev)
      if (next.has(option.id)) next.delete(option.id)
      else next.set(option.id, option)
      return next
    })
  }

  async function submit(media: T[]) {
    if (media.length === 0 && !allowEmptyConfirm) return
    setSubmitting(true)
    try {
      await onConfirm(media)
      reset()
      onOpenChange(false)
    } catch (error) {
      // The mutation shows its own error; keep the dialog open with the
      // selection intact so the merchant can retry.
      onConfirmError?.(error)
    } finally {
      setSubmitting(false)
    }
  }

  async function handleUpload(files: File[]) {
    if (!files.length || !onUpload) return

    const session = sessionRef.current
    setUploading(true)
    try {
      const uploaded: T[] = []
      for (const file of files) {
        uploaded.push(await onUpload(file))
      }
      // The file is in the library either way — only the confirmation is
      // abandoned, so nothing the merchant uploaded is lost.
      if (session !== sessionRef.current) return

      await refetch()

      if (multiple) {
        setStaged((prev) => {
          const next = new Map(prev)
          for (const media of uploaded) next.set(media.id, media)
          return next
        })
      } else {
        await submit(uploaded.slice(0, 1))
      }
    } catch (error) {
      onConfirmError?.(error)
    } finally {
      setUploading(false)
      if (fileInputRef.current) fileInputRef.current.value = ''
    }
  }

  function handleDrop(event: DragEvent) {
    event.preventDefault()
    setDragging(false)
    const files = Array.from(event.dataTransfer.files).filter((file) => acceptsFile(accept, file))
    void handleUpload(multiple ? files : files.slice(0, 1))
  }

  function reset() {
    setStaged(new Map())
    setInput('')
  }

  function handleOpenChange(next: boolean) {
    if (!next) {
      sessionRef.current += 1
      reset()
    }
    onOpenChange(next)
  }

  return (
    <Dialog open={open} onOpenChange={handleOpenChange}>
      <DialogContent className="h-[min(860px,calc(100dvh-2rem))] gap-0 p-0 sm:max-w-5xl">
        <DialogHeader>
          <DialogTitle>{title ?? t('admin.media_picker.title')}</DialogTitle>
          <DialogDescription>
            {description ?? t('admin.media_picker.description')}
          </DialogDescription>
        </DialogHeader>

        <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-4">
          <div className="flex flex-col gap-3">
            <div className="flex items-center gap-2">
              <SearchInput
                value={input}
                onValueChange={setInput}
                // Enter has no action here; swallow it so it can't submit a host form.
                onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
                placeholder={t('admin.media_picker.search_placeholder')}
                aria-label={t('admin.media_picker.search_placeholder')}
                clearLabel={t('admin.common.clear')}
                className="h-11 max-w-xl flex-1 lg:h-[2.125rem]"
              />
              <div className="ms-auto flex items-center gap-2">
                {browseControls && (
                  <SortMenu
                    columns={[
                      { key: 'created_at', label: t('admin.media_picker.sort_date_added') },
                      { key: 'filename', label: t('admin.media_picker.sort_file_name') },
                      { key: 'byte_size', label: t('admin.media_picker.sort_file_size') },
                    ]}
                    sort={sort}
                    onSortChange={(next) => setSort(next as MediaPickerSearchOptions['sort'])}
                  />
                )}
                <MediaViewMenu view={view} onViewChange={changeView} />
              </div>
            </div>

            {browseControls && (
              <div className="flex flex-wrap items-center gap-2">
                {offersVideo && (
                  <MediaFilterChip
                    label={t('admin.media_picker.filter_type')}
                    value={mediaType}
                    onChange={(next) => setMediaType(next as MediaPickerSearchOptions['mediaType'])}
                    options={[
                      { value: 'all', label: t('admin.media_picker.any') },
                      { value: 'image', label: t('admin.media_picker.type_image') },
                      { value: 'video', label: t('admin.media_picker.type_video') },
                    ]}
                  />
                )}
                <MediaFilterChip
                  label={t('admin.media_picker.filter_usage')}
                  value={usage}
                  onChange={(next) => setUsage(next as MediaPickerSearchOptions['usage'])}
                  options={[
                    { value: 'all', label: t('admin.media_picker.any') },
                    { value: 'used', label: t('admin.media_picker.usage_used') },
                    { value: 'unused', label: t('admin.media_picker.usage_unused') },
                  ]}
                />
              </div>
            )}
          </div>

          {onUpload && (
            // biome-ignore lint/a11y/noStaticElementInteractions: a drop target; the button inside is the keyboard way in
            <div
              onDragOver={(event) => {
                event.preventDefault()
                setDragging(true)
              }}
              onDragLeave={() => setDragging(false)}
              onDrop={handleDrop}
              className={cn(
                'flex flex-col items-center justify-center gap-2 rounded-card border border-dashed border-border px-4 py-6 text-center transition-colors',
                dragging && 'border-blue-500 bg-blue-50/70 dark:bg-blue-500/10',
              )}
            >
              <input
                ref={fileInputRef}
                type="file"
                accept={accept}
                multiple={multiple}
                className="hidden"
                onChange={(e) => handleUpload(Array.from(e.target.files ?? []))}
              />
              <Button
                type="button"
                variant="outline"
                disabled={uploading}
                onClick={() => fileInputRef.current?.click()}
              >
                {uploading ? (
                  <Loader2Icon className="size-4 animate-spin" />
                ) : (
                  <UploadIcon className="size-4" />
                )}
                <span>{t('admin.media_picker.upload')}</span>
              </Button>
              <p className="text-muted-foreground text-base">
                {offersVideo
                  ? t('admin.media_picker.drop_hint_media')
                  : t('admin.media_picker.drop_hint_images')}
              </p>
            </div>
          )}

          {isFetching && results.length === 0 ? (
            <div className="flex items-center justify-center py-10 text-muted-foreground">
              <Loader2Icon className="size-5 animate-spin" />
            </div>
          ) : results.length === 0 ? (
            <p className="p-6 text-center text-muted-foreground text-base">
              {filtered ? t('admin.media_picker.no_results') : t('admin.media_picker.empty')}
            </p>
          ) : view === 'grid' ? (
            <ul className="grid grid-cols-2 gap-2 sm:grid-cols-4 lg:grid-cols-6">
              {results.map((media) => (
                <li key={media.id}>
                  <GridTile
                    media={media}
                    checked={staged.has(media.id)}
                    onPick={() => pick(media)}
                    badge={media.id === firstSelectedId ? firstSelectedBadge : undefined}
                  />
                </li>
              ))}
            </ul>
          ) : (
            <div>
              <MediaListHeader withCheckbox />
              <ul className={mediaListClassName}>
                {results.map((media) => (
                  <li key={media.id}>
                    <ListRow
                      media={media}
                      checked={staged.has(media.id)}
                      onPick={() => pick(media)}
                      badge={media.id === firstSelectedId ? firstSelectedBadge : undefined}
                    />
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>

        {multiple && (
          <DialogFooter className="items-center sm:justify-between">
            <span className="text-muted-foreground text-base">
              {t('admin.media_picker.selected_count', { count: staged.size })}
            </span>
            <div className="flex gap-2">
              <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
                {t('admin.actions.cancel')}
              </Button>
              <Button
                type="button"
                disabled={(staged.size === 0 && !allowEmptyConfirm) || submitting}
                onClick={() => submit(Array.from(staged.values()))}
              >
                {submitting && <Loader2Icon className="size-4 animate-spin" />}
                <span>{confirmLabel ?? t('admin.media_picker.confirm')}</span>
              </Button>
            </div>
          </DialogFooter>
        )}
      </DialogContent>
    </Dialog>
  )
}

function Thumbnail({ media, className }: { media: MediaPickerOption; className?: string }) {
  const src = media.small_url ?? media.poster_url ?? media.original_url
  const label = media.alt || media.filename || ''
  return (
    <span
      className={cn(
        'relative flex items-center justify-center overflow-hidden bg-muted',
        className,
      )}
    >
      {src ? (
        <img src={src} alt={label} loading="lazy" className="size-full object-cover" />
      ) : (
        <ImageIcon className="size-6 text-muted-foreground" />
      )}
      {!!media.media_type && media.media_type !== 'image' && (
        <span className="absolute right-1.5 bottom-1.5 rounded-full bg-black/60 p-1 text-white">
          <PlayIcon className="size-3" />
        </span>
      )}
    </span>
  )
}

/** The button classes of a media grid tile; `selected` gives it the grey fill. */
export function mediaTileClassName(selected = false) {
  return cn(
    'group flex w-full flex-col gap-2 rounded-xl p-2 text-center outline-none transition-colors hover:bg-accent/60 focus-visible:shadow-field-focus',
    selected && 'bg-accent hover:bg-accent',
  )
}

/**
 * A file as a tile: the picture framed on its own, its name and type below.
 * Picked, the whole tile takes a grey fill and its box is ticked — a quiet
 * state the eye still finds, rather than a heavy ring around every pick.
 * `checkbox` overlays the frame's corner where the host selects.
 */
export function MediaTileBody({
  media,
  checkbox,
  badge,
}: {
  media: MediaPickerOption
  checkbox?: ReactNode
  /** A short label over the frame's foot, such as "Thumbnail". */
  badge?: ReactNode
}) {
  return (
    <>
      <span className="relative block">
        <Thumbnail
          media={media}
          className="aspect-square w-full rounded-lg border border-card-edge bg-card shadow-card-lift"
        />
        {checkbox}
        {badge && (
          <span className="absolute bottom-2 left-2 rounded-md bg-black/70 px-1.5 py-0.5 font-medium text-white text-xs">
            {badge}
          </span>
        )}
      </span>
      <span className="flex min-w-0 flex-col">
        <span className="truncate text-base">{media.alt || media.filename}</span>
        <span className="text-muted-foreground text-xs">{mediaFileTypeLabel(media)}</span>
      </span>
    </>
  )
}

/**
 * The button classes of a media list row; `selected` gives it the grey fill.
 * Rows look like a resource table's: a rounded fill on hover or selection,
 * on a list framed by `mediaListClassName` and headed by `MediaListHeader`.
 */
export function mediaRowClassName(selected = false) {
  return cn(
    'flex w-full items-center gap-3 rounded-[10px] px-3 py-2 text-left outline-none transition-colors hover:bg-muted focus-visible:shadow-field-focus data-popup-open:bg-accent-strong/40',
    selected && 'bg-accent-strong/75 hover:bg-accent-strong-hover',
  )
}

/**
 * The `<ul>` of a media list: no frame, a faint divider between rows, and a
 * 2px gap above each so a filled row stands clear of its neighbours. A filled
 * row (hovered, selected, menu open) hides the dividers either side of it.
 */
export const mediaListClassName = cn(
  'flex flex-col [&>li]:relative [&>li]:pt-0.5',
  "[&>li+li]:before:absolute [&>li+li]:before:inset-x-0 [&>li+li]:before:top-0 [&>li+li]:before:h-px [&>li+li]:before:bg-border-subtle [&>li+li]:before:content-['']",
  '[&>li:is(:hover,:has([aria-pressed=true]),:has([data-popup-open]))]:before:bg-transparent [&>li:is(:hover,:has([aria-pressed=true]),:has([data-popup-open]))+li]:before:bg-transparent',
)

/**
 * The column labels over a media list, as a resource table's header band.
 * The spacers line the labels up with `MediaRowBody`'s columns; pass the
 * trailing column's width classes when the rows carry one.
 */
export function MediaListHeader({
  withCheckbox = false,
  trailingClassName,
}: {
  withCheckbox?: boolean
  trailingClassName?: string
}) {
  const { t } = useTranslation()
  return (
    <div
      aria-hidden
      className="flex h-10 items-center gap-3 rounded-[10px] bg-muted px-3 font-medium text-muted-foreground text-xs"
    >
      {withCheckbox && <span className="w-4 shrink-0" />}
      <span className="w-10 shrink-0" />
      <span className="min-w-0 flex-1">{t('admin.media_picker.sort_file_name')}</span>
      <span className="hidden w-14 shrink-0 sm:block">{t('admin.media_picker.filter_type')}</span>
      <span className="hidden w-20 shrink-0 text-right sm:block">
        {t('admin.media_picker.sort_file_size')}
      </span>
      <span className="w-24 shrink-0 text-right">{t('admin.media_picker.sort_date_added')}</span>
      {trailingClassName && <span className={trailingClassName} />}
    </div>
  )
}

/**
 * A file as a row, for finding one by name in a long library: thumbnail, name
 * and file name, then type, size and date added — what tells two similar
 * files apart once the picture is too small to. `leading` goes first (a
 * checkbox), `trailing` after the details (a status).
 */
export function MediaRowBody({
  media,
  leading,
  trailing,
  badge,
}: {
  media: MediaPickerOption
  leading?: ReactNode
  trailing?: ReactNode
  /** A short label beside the name, such as "Thumbnail". */
  badge?: ReactNode
}) {
  const { i18n } = useTranslation()
  return (
    <>
      {leading}
      <Thumbnail media={media} className="size-10 shrink-0 rounded-md border border-card-edge" />
      <span className="min-w-0 flex-1">
        <span className="flex items-center gap-2 text-base">
          <span className="truncate">{media.alt || media.filename}</span>
          {badge && (
            <span className="shrink-0 rounded-md bg-accent px-1.5 py-0.5 font-medium text-xs">
              {badge}
            </span>
          )}
        </span>
        {media.alt && media.filename && media.alt !== media.filename && (
          <span className="block truncate text-muted-foreground text-xs">{media.filename}</span>
        )}
      </span>
      <span className="hidden w-14 shrink-0 text-muted-foreground text-xs sm:block">
        {mediaFileTypeLabel(media)}
      </span>
      <span className="hidden w-20 shrink-0 text-right text-muted-foreground text-xs tabular-nums sm:block">
        {formatMediaBytes(media.byte_size, i18n.language)}
      </span>
      <span className="w-24 shrink-0 text-right text-muted-foreground text-xs tabular-nums">
        {media.created_at
          ? new Date(media.created_at).toLocaleDateString(i18n.language, {
              day: 'numeric',
              month: 'short',
              year: 'numeric',
            })
          : ''}
      </span>
      {trailing}
    </>
  )
}

function GridTile({
  media,
  checked,
  onPick,
  badge,
}: {
  media: MediaPickerOption
  checked: boolean
  onPick: () => void
  badge?: ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onPick}
      aria-pressed={checked}
      className={mediaTileClassName(checked)}
    >
      <MediaTileBody
        media={media}
        badge={badge}
        checkbox={
          <Checkbox
            checked={checked}
            tabIndex={-1}
            aria-hidden
            className={cn(
              'pointer-events-none absolute top-2 left-2 transition-opacity',
              !checked && 'opacity-0 group-hover:opacity-100 group-focus-visible:opacity-100',
            )}
          />
        }
      />
    </button>
  )
}

function ListRow({
  media,
  checked,
  onPick,
  badge,
}: {
  media: MediaPickerOption
  checked: boolean
  onPick: () => void
  badge?: ReactNode
}) {
  return (
    <button
      type="button"
      onClick={onPick}
      aria-pressed={checked}
      className={mediaRowClassName(checked)}
    >
      <MediaRowBody
        media={media}
        badge={badge}
        leading={
          <Checkbox checked={checked} tabIndex={-1} aria-hidden className="pointer-events-none" />
        }
      />
    </button>
  )
}

/** A filter as a chip showing its current value, opening a one-choice menu. */
export function MediaFilterChip({
  label,
  value,
  onChange,
  options,
}: {
  label: string
  value: string
  onChange: (value: string) => void
  options: { value: string; label: string }[]
}) {
  const current = options.find((option) => option.value === value)
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <Button
          type="button"
          variant="outline"
          size="sm"
          className="h-11 font-normal lg:h-[2.125rem]"
        >
          <span className="text-muted-foreground">{label}</span>
          <span className="font-medium">{current?.label}</span>
          <ChevronsUpDownIcon className="size-3.5 text-muted-foreground" />
        </Button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start">
        <DropdownMenuRadioGroup value={value} onValueChange={(next) => onChange(String(next))}>
          {options.map((option) => (
            <DropdownMenuRadioItem key={option.value} value={option.value}>
              {option.label}
            </DropdownMenuRadioItem>
          ))}
        </DropdownMenuRadioGroup>
      </DropdownMenuContent>
    </DropdownMenu>
  )
}
