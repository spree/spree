import {
  Button,
  SearchInput,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { CheckIcon, ImageIcon, Loader2Icon, PlayIcon, UploadIcon } from 'lucide-react'
import { useDeferredValue, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useStore } from '../providers/store-provider'

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
}

export interface MediaPickerSheetProps<T extends MediaPickerOption> {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** Paginated search over the library. Called with the trimmed query. */
  search: (query: string) => Promise<{ data: T[] }>
  /** Called with the picked files when the user confirms. */
  onConfirm: (media: T[]) => void | Promise<void>
  /** Uploads a file and returns the created library row, for the upload tab. */
  onUpload?: (file: File) => Promise<T>
  /** One file only — the picker confirms as soon as a tile is clicked. */
  multiple?: boolean
  /** Cache-isolation key, one per picker instance. */
  queryKey: string
  accept?: string
  title?: string
  description?: string
  confirmLabel?: string
  onConfirmError?: (error: unknown) => void
}

/**
 * Browse the store's media library and pick files from it.
 *
 * A grid rather than the row list {@link ResourcePickerSheet} uses: choosing a
 * picture means looking at it, and a filename tells a merchant almost nothing
 * about which photo it is.
 *
 * Headless — the caller supplies `search` and `onUpload`, so the same sheet
 * serves the product media card (which places files on a product) and plain
 * image fields (which take the picked file's blob).
 */
export function MediaPickerSheet<T extends MediaPickerOption>({
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
}: MediaPickerSheetProps<T>) {
  const { t } = useTranslation()
  const { storeId } = useStore()

  const [input, setInput] = useState('')
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()
  const [staged, setStaged] = useState<Map<string, T>>(new Map())
  const [submitting, setSubmitting] = useState(false)
  const [uploading, setUploading] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  // The store id is part of the key: a library is one store's, and without it
  // reopening the picker after a store switch serves the previous store's
  // files from cache — whose ids the new store's API would then reject.
  const { data, isFetching, refetch } = useQuery({
    queryKey: [queryKey, 'media-picker', storeId, trimmedQuery],
    queryFn: () => search(trimmedQuery),
    enabled: open,
    staleTime: 30_000,
  })

  const results = data?.data ?? []

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
    if (media.length === 0) return
    setSubmitting(true)
    try {
      await onConfirm(media)
      reset()
      onOpenChange(false)
    } catch (error) {
      // The mutation shows its own error; keep the sheet open with the
      // selection intact so the merchant can retry.
      onConfirmError?.(error)
    } finally {
      setSubmitting(false)
    }
  }

  async function handleUpload(files: FileList | null) {
    if (!files?.length || !onUpload) return

    setUploading(true)
    try {
      const uploaded: T[] = []
      for (const file of Array.from(files)) {
        uploaded.push(await onUpload(file))
      }
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

  function reset() {
    setStaged(new Map())
    setInput('')
  }

  function handleOpenChange(next: boolean) {
    if (!next) reset()
    onOpenChange(next)
  }

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent className="w-full gap-0 p-0 sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle>{title ?? t('admin.media_picker.title')}</SheetTitle>
          <SheetDescription>{description ?? t('admin.media_picker.description')}</SheetDescription>
        </SheetHeader>

        <div className="flex items-center gap-2 border-b border-border p-4">
          <SearchInput
            value={input}
            onValueChange={setInput}
            // Enter has no action here; swallow it so it can't submit a host form.
            onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
            placeholder={t('admin.media_picker.search_placeholder')}
            clearLabel={t('admin.common.clear')}
            className="flex-1"
          />
          {onUpload && (
            <>
              <input
                ref={fileInputRef}
                type="file"
                accept={accept}
                multiple={multiple}
                className="hidden"
                onChange={(e) => handleUpload(e.target.files)}
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
                {t('admin.media_picker.upload')}
              </Button>
            </>
          )}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto p-4">
          {isFetching && results.length === 0 ? (
            <div className="flex items-center justify-center py-10 text-muted-foreground">
              <Loader2Icon className="size-5 animate-spin" />
            </div>
          ) : results.length === 0 ? (
            <p className="p-6 text-center text-muted-foreground text-sm">
              {trimmedQuery ? t('admin.media_picker.no_results') : t('admin.media_picker.empty')}
            </p>
          ) : (
            <ul className="grid grid-cols-3 gap-3 sm:grid-cols-4">
              {results.map((media) => {
                const checked = staged.has(media.id)
                const thumbnail = media.small_url ?? media.poster_url ?? media.original_url
                const label = media.alt || media.filename || ''

                return (
                  <li key={media.id}>
                    <button
                      type="button"
                      onClick={() => pick(media)}
                      aria-pressed={checked}
                      className={`group relative block w-full overflow-hidden rounded-md border transition-colors ${
                        checked
                          ? 'border-primary ring-2 ring-primary'
                          : 'border-border hover:border-muted-foreground'
                      }`}
                    >
                      <span className="flex aspect-square items-center justify-center bg-muted">
                        {thumbnail ? (
                          <img
                            src={thumbnail}
                            alt={label}
                            loading="lazy"
                            className="size-full object-cover"
                          />
                        ) : (
                          <ImageIcon className="size-6 text-muted-foreground" />
                        )}
                      </span>

                      {media.media_type !== 'image' && (
                        <span className="absolute top-1.5 left-1.5 rounded bg-black/60 p-1 text-white">
                          <PlayIcon className="size-3" />
                        </span>
                      )}

                      {checked && (
                        <span className="absolute top-1.5 right-1.5 rounded-full bg-primary p-1 text-primary-foreground">
                          <CheckIcon className="size-3" />
                        </span>
                      )}

                      {label && (
                        <span className="block truncate px-2 py-1.5 text-left text-xs">
                          {label}
                        </span>
                      )}
                    </button>
                  </li>
                )
              })}
            </ul>
          )}
        </div>

        {multiple && (
          <SheetFooter className="flex-row items-center justify-between border-t border-border">
            <span className="text-muted-foreground text-xs">
              {t('admin.media_picker.selected_count', { count: staged.size })}
            </span>
            <Button
              type="button"
              disabled={staged.size === 0 || submitting}
              onClick={() => submit(Array.from(staged.values()))}
            >
              {submitting && <Loader2Icon className="size-4 animate-spin" />}
              {confirmLabel ?? t('admin.media_picker.confirm')}
            </Button>
          </SheetFooter>
        )}
      </SheetContent>
    </Sheet>
  )
}
