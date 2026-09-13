import {
  Button,
  Checkbox,
  type PaginationMeta,
  SearchInput,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
  Thumbnail,
} from '@spree/dashboard-ui'
import { Loader2Icon } from '@spree/dashboard-ui/icons'
import { useInfiniteQuery } from '@tanstack/react-query'
import { useDeferredValue, useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'

export interface PickerOption {
  id: string
}

/** One page of async picker search results, optionally with list pagination metadata. */
export interface ResourcePickerSearchResult<T extends PickerOption> {
  /** Rows returned for the requested page. */
  data: T[]
  /** Total match count and page cursors when the search is paginated. */
  meta?: PaginationMeta
}

export interface ResourcePickerSheetProps<T extends PickerOption> {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** IDs already chosen (e.g. products already in the category). Pre-checked & not re-addable. */
  selectedIds: string[]
  /** Called with the freshly-picked IDs (excludes `selectedIds`) when the user confirms. */
  onConfirm: (ids: string[], options: T[]) => void | Promise<void>
  /** Paginated async search. Called with the trimmed query (empty = initial list) and page. */
  search: (query: string, page: number) => Promise<ResourcePickerSearchResult<T>>
  getOptionLabel: (option: T) => string
  /** Optional thumbnail URL shown as an avatar. */
  getOptionImageUrl?: (option: T) => string | null | undefined
  /** Optional secondary line under the label. */
  getOptionSubtitle?: (option: T) => string | null | undefined
  /** Cache-isolation key (one per picker instance / resource type). */
  queryKey: string
  title?: string
  description?: string
  searchPlaceholder?: string
  confirmLabel?: string
  /** Called if `onConfirm` rejects. The sheet stays open with the staged selection. */
  onConfirmError?: (error: unknown) => void
}

/**
 * Universal multi-select resource picker rendered in a Sheet. Designed to be
 * reused across products-in-category, products-in-collection, products-in-
 * price-list, etc. — pass `search`/`getOptionLabel` for the resource.
 *
 * Why a sheet (not an inline combobox): with hundreds of rows an inline
 * autocomplete is unusable and re-renders the host form on every keystroke.
 * Here the search list loads async inside the sheet, the staging selection is
 * local, and the host form only hears about the result once, on confirm.
 */
export function ResourcePickerSheet<T extends PickerOption>({
  open,
  onOpenChange,
  selectedIds,
  onConfirm,
  search,
  getOptionLabel,
  getOptionImageUrl,
  getOptionSubtitle,
  queryKey,
  title,
  description,
  searchPlaceholder,
  confirmLabel,
  onConfirmError,
}: ResourcePickerSheetProps<T>) {
  const { t } = useTranslation()

  const [input, setInput] = useState('')
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()

  const [selectAllMeta, setSelectAllMeta] = useState<PaginationMeta | undefined>()
  const selectAllGenerationRef = useRef(0)
  const selectAllSessionRef = useRef({ query: trimmedQuery, open })

  if (
    selectAllSessionRef.current.query !== trimmedQuery ||
    (selectAllSessionRef.current.open && !open)
  ) {
    selectAllGenerationRef.current += 1
    selectAllSessionRef.current = { query: trimmedQuery, open }
  }

  // Staging selection (ids picked in this session) + a label cache so the
  // "selected" chips keep their text even after the search results change.
  const [staged, setStaged] = useState<Map<string, T>>(new Map())
  const alreadyIn = useMemo(() => new Set(selectedIds), [selectedIds])
  const [submitting, setSubmitting] = useState(false)
  const [selectingAll, setSelectingAll] = useState(false)

  // The accumulated pages live in the query cache rather than in local state.
  // Mirroring them into state via an effect broke reopening the sheet: the
  // cached page came back reference-identical, so the effect that filled the
  // local list never re-ran and the sheet rendered "no results" over a cache
  // that held plenty.
  const { data, isFetching, isFetchingNextPage, fetchNextPage } = useInfiniteQuery({
    queryKey: [queryKey, 'picker-search', trimmedQuery],
    queryFn: ({ pageParam }) => search(trimmedQuery, pageParam),
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) =>
      lastPage.meta?.next != null ? allPages.length + 1 : undefined,
    enabled: open,
    staleTime: 30_000,
  })

  const results = useMemo(() => {
    const seen = new Set<string>()
    const flattened: T[] = []
    for (const loadedPage of data?.pages ?? []) {
      for (const option of loadedPage.data) {
        if (seen.has(option.id)) continue
        seen.add(option.id)
        flattened.push(option)
      }
    }
    return flattened
  }, [data])

  const lastPage = data?.pages.at(-1)
  const meta = selectAllMeta ?? lastPage?.meta
  const hasMore = lastPage?.meta?.next != null
  const matchCount = meta?.count ?? results.length
  const currentPageResults = lastPage?.data ?? []
  const selectableOnPage = currentPageResults.filter((option) => !alreadyIn.has(option.id))
  const allOnPageSelected =
    selectableOnPage.length > 0 && selectableOnPage.every((option) => staged.has(option.id))

  function toggle(option: T) {
    if (alreadyIn.has(option.id)) return
    setStaged((prev) => {
      const next = new Map(prev)
      if (next.has(option.id)) next.delete(option.id)
      else next.set(option.id, option)
      return next
    })
  }

  function togglePageSelection() {
    setStaged((prev) => {
      const next = new Map(prev)
      if (allOnPageSelected) {
        for (const option of selectableOnPage) next.delete(option.id)
      } else {
        for (const option of selectableOnPage) next.set(option.id, option)
      }
      return next
    })
  }

  async function selectAllMatching() {
    if (matchCount === 0 || selectingAll) return
    const generation = selectAllGenerationRef.current
    setSelectingAll(true)
    try {
      const collected = new Map<string, T>()
      let nextPage = 1
      let lastMeta: PaginationMeta | undefined

      while (true) {
        const response = await search(trimmedQuery, nextPage)
        if (generation !== selectAllGenerationRef.current) return
        lastMeta = response.meta
        for (const option of response.data) {
          if (!alreadyIn.has(option.id)) collected.set(option.id, option)
        }
        if (!response.meta || nextPage >= response.meta.pages) break
        nextPage += 1
      }

      if (generation !== selectAllGenerationRef.current) return

      setStaged((prev) => {
        const next = new Map(prev)
        for (const [id, option] of collected) next.set(id, option)
        return next
      })
      if (lastMeta) setSelectAllMeta(lastMeta)
    } catch (error) {
      onConfirmError?.(error)
    } finally {
      setSelectingAll(false)
    }
  }

  async function confirm() {
    if (staged.size === 0) return
    setSubmitting(true)
    try {
      await onConfirm(Array.from(staged.keys()), Array.from(staged.values()))
      setStaged(new Map())
      setInput('')
      setSelectAllMeta(undefined)
      onOpenChange(false)
    } catch (error) {
      // The mutation reports its own error toast; swallow so the click handler
      // doesn't reject, and keep the sheet open with the staged selection so the
      // user can retry. Callers can observe failures via onConfirmError.
      onConfirmError?.(error)
    } finally {
      setSubmitting(false)
    }
  }

  function handleOpenChange(next: boolean) {
    if (!next) {
      selectAllGenerationRef.current += 1
      setStaged(new Map())
      setInput('')
      setSelectAllMeta(undefined)
    }
    onOpenChange(next)
  }

  const initialLoading = isFetching && results.length === 0
  const loadingMore = isFetchingNextPage

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent className="w-full gap-0 p-0 sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{title ?? t('admin.resource_picker.title')}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>

        <div className="border-b border-border p-4">
          <SearchInput
            value={input}
            onValueChange={(value) => {
              setInput(value)
              setSelectAllMeta(undefined)
            }}
            // Enter has no action here; swallow it so it can't submit a host form.
            onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
            placeholder={searchPlaceholder ?? t('admin.resource_picker.search_placeholder')}
            clearLabel={t('admin.common.clear')}
          />
          {staged.size > 0 && (
            <p className="mt-2 text-muted-foreground text-xs">
              {t('admin.resource_picker.selected_count', { count: staged.size })}
            </p>
          )}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {initialLoading ? (
            <div className="flex items-center justify-center py-10 text-muted-foreground">
              <Loader2Icon className="size-5 animate-spin" />
            </div>
          ) : results.length === 0 ? (
            <p className="p-6 text-center text-muted-foreground text-sm">
              {t('admin.resource_picker.empty')}
            </p>
          ) : (
            <>
              {matchCount > 0 && (
                <div className="flex items-center justify-between gap-3 border-b border-border px-4 py-2">
                  <button
                    type="button"
                    disabled={selectableOnPage.length === 0 || selectingAll}
                    onClick={togglePageSelection}
                    className="flex min-w-0 flex-1 items-center gap-3 text-left hover:bg-accent/50 disabled:cursor-not-allowed disabled:opacity-60"
                  >
                    <Checkbox
                      checked={allOnPageSelected}
                      disabled={selectableOnPage.length === 0 || selectingAll}
                      className="pointer-events-none"
                    />
                    <span className="truncate text-sm">
                      {t('admin.resource_picker.select_page', { count: selectableOnPage.length })}
                    </span>
                  </button>
                  {matchCount > 0 &&
                  (hasMore || !allOnPageSelected || matchCount > selectableOnPage.length) ? (
                    <Button
                      type="button"
                      variant="link"
                      size="sm"
                      className="h-auto shrink-0 px-0"
                      disabled={selectingAll}
                      onClick={selectAllMatching}
                    >
                      {selectingAll && <Loader2Icon className="size-3.5 animate-spin" />}
                      {t('admin.resource_picker.select_all_matching', { count: matchCount })}
                    </Button>
                  ) : null}
                </div>
              )}
              <ul className="divide-y divide-border">
                {results.map((option) => {
                  const inList = alreadyIn.has(option.id)
                  const checked = inList || staged.has(option.id)
                  const imageUrl = getOptionImageUrl?.(option)
                  const subtitle = getOptionSubtitle?.(option)
                  return (
                    <li key={option.id}>
                      <button
                        type="button"
                        disabled={inList}
                        onClick={() => toggle(option)}
                        className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-accent/50 disabled:cursor-not-allowed disabled:opacity-60"
                      >
                        <Checkbox
                          checked={checked}
                          disabled={inList}
                          className="pointer-events-none"
                        />
                        {getOptionImageUrl && <Thumbnail src={imageUrl} size="sm" />}
                        <span className="min-w-0 flex-1">
                          <span className="block truncate text-sm">{getOptionLabel(option)}</span>
                          {subtitle && (
                            <span className="block truncate text-muted-foreground text-xs">
                              {subtitle}
                            </span>
                          )}
                        </span>
                        {inList && (
                          <span className="shrink-0 text-muted-foreground text-xs">
                            {t('admin.resource_picker.already_added')}
                          </span>
                        )}
                      </button>
                    </li>
                  )
                })}
              </ul>
              {hasMore && (
                <div className="border-t border-border p-4">
                  <Button
                    type="button"
                    variant="outline"
                    className="w-full"
                    disabled={loadingMore}
                    onClick={() => fetchNextPage()}
                  >
                    {loadingMore && <Loader2Icon className="size-4 animate-spin" />}
                    {t('admin.resource_picker.load_more')}
                  </Button>
                </div>
              )}
            </>
          )}
        </div>

        <SheetFooter className="flex-row items-center justify-between border-t border-border">
          <Button type="button" variant="outline" onClick={() => handleOpenChange(false)}>
            {t('admin.actions.cancel')}
          </Button>
          <Button type="button" onClick={confirm} disabled={staged.size === 0 || submitting}>
            {submitting && <Loader2Icon className="size-4 animate-spin" />}
            {confirmLabel ?? t('admin.resource_picker.add_count', { count: staged.size })}
          </Button>
        </SheetFooter>
      </SheetContent>
    </Sheet>
  )
}
