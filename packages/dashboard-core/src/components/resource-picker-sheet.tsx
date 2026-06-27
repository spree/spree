import {
  Avatar,
  AvatarFallback,
  AvatarImage,
  Button,
  Checkbox,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  Sheet,
  SheetContent,
  SheetDescription,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { ImageIcon, Loader2Icon, SearchIcon, XIcon } from 'lucide-react'
import { useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

export interface PickerOption {
  id: string
}

export interface ResourcePickerSheetProps<T extends PickerOption> {
  open: boolean
  onOpenChange: (open: boolean) => void
  /** IDs already chosen (e.g. products already in the category). Pre-checked & not re-addable. */
  selectedIds: string[]
  /** Called with the freshly-picked IDs (excludes `selectedIds`) when the user confirms. */
  onConfirm: (ids: string[], options: T[]) => void | Promise<void>
  /** Paginated async search. Called with the trimmed query (empty = initial list). */
  search: (query: string) => Promise<{ data: T[] }>
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
}: ResourcePickerSheetProps<T>) {
  const { t } = useTranslation()

  const [input, setInput] = useState('')
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()

  // Staging selection (ids picked in this session) + a label cache so the
  // "selected" chips keep their text even after the search results change.
  const [staged, setStaged] = useState<Map<string, T>>(new Map())
  const alreadyIn = useMemo(() => new Set(selectedIds), [selectedIds])
  const [submitting, setSubmitting] = useState(false)

  const { data, isFetching } = useQuery({
    queryKey: [queryKey, 'picker-search', trimmedQuery],
    queryFn: () => search(trimmedQuery),
    enabled: open,
    staleTime: 30_000,
  })

  const results = data?.data ?? []

  function toggle(option: T) {
    if (alreadyIn.has(option.id)) return
    setStaged((prev) => {
      const next = new Map(prev)
      if (next.has(option.id)) next.delete(option.id)
      else next.set(option.id, option)
      return next
    })
  }

  async function confirm() {
    if (staged.size === 0) return
    setSubmitting(true)
    try {
      await onConfirm(Array.from(staged.keys()), Array.from(staged.values()))
      setStaged(new Map())
      setInput('')
      onOpenChange(false)
    } finally {
      setSubmitting(false)
    }
  }

  function handleOpenChange(next: boolean) {
    if (!next) {
      setStaged(new Map())
      setInput('')
    }
    onOpenChange(next)
  }

  return (
    <Sheet open={open} onOpenChange={handleOpenChange}>
      <SheetContent className="w-full gap-0 p-0 sm:max-w-lg">
        <SheetHeader>
          <SheetTitle>{title ?? t('admin.resource_picker.title')}</SheetTitle>
          {description && <SheetDescription>{description}</SheetDescription>}
        </SheetHeader>

        <div className="border-b border-border p-4">
          <InputGroup>
            <InputGroupAddon>
              <SearchIcon className="size-4 text-muted-foreground" />
            </InputGroupAddon>
            <InputGroupInput
              type="search"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              // Enter has no action here; swallow it so it can't submit a host form.
              onKeyDown={(e) => e.key === 'Enter' && e.preventDefault()}
              placeholder={searchPlaceholder ?? t('admin.resource_picker.search_placeholder')}
            />
          </InputGroup>
          {staged.size > 0 && (
            <p className="mt-2 text-muted-foreground text-xs">
              {t('admin.resource_picker.selected_count', { count: staged.size })}
            </p>
          )}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto">
          {isFetching && results.length === 0 ? (
            <div className="flex items-center justify-center py-10 text-muted-foreground">
              <Loader2Icon className="size-5 animate-spin" />
            </div>
          ) : results.length === 0 ? (
            <p className="p-6 text-center text-muted-foreground text-sm">
              {t('admin.resource_picker.empty')}
            </p>
          ) : (
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
                      className="flex w-full items-center gap-3 px-4 py-2.5 text-left hover:bg-muted/50 disabled:cursor-not-allowed disabled:opacity-60"
                    >
                      <Checkbox
                        checked={checked}
                        disabled={inList}
                        className="pointer-events-none"
                      />
                      {getOptionImageUrl && (
                        <Avatar className="size-9 rounded-md">
                          {imageUrl ? (
                            <AvatarImage src={imageUrl} alt="" className="object-cover" />
                          ) : null}
                          <AvatarFallback className="rounded-md bg-muted">
                            <ImageIcon className="size-4 text-muted-foreground" />
                          </AvatarFallback>
                        </Avatar>
                      )}
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
          )}
        </div>

        <SheetFooter className="flex-row items-center justify-between border-t border-border">
          <Button type="button" variant="ghost" onClick={() => handleOpenChange(false)}>
            <XIcon className="size-4" />
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
