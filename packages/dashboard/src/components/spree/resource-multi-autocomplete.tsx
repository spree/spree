import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  useComboboxAnchor,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useState } from 'react'

/**
 * Anything we can pick. Items must have a stable string `id`. The label
 * (and any other rendering) is up to the caller via `getOptionLabel`.
 */
export type AutocompleteOption = { id: string }

export interface ResourceMultiAutocompleteProps<T extends AutocompleteOption> {
  /** Currently selected IDs (controlled). */
  value: string[]
  onChange: (next: string[]) => void
  /**
   * Optional companion callback fired alongside `onChange` carrying the
   * resolved option records (search results + cache lookups) for the
   * selected IDs. Use this to stamp display labels on the parent state
   * without re-fetching. IDs whose record isn't yet hydrated will be
   * absent from this list.
   *
   * Split from `onChange` so the picker's generic `T` can still be
   * inferred from `search`/`hydrate`/`getOptionLabel` without
   * contravariance from the callback parameter widening it.
   */
  onResolvedOptionsChange?: (options: T[]) => void

  /**
   * Server-side search. Receives the trimmed query string. Should return
   * `{ data: T[] }`. Called any time the user types (with debouncing
   * provided by the caller's queryClient if needed). Returning an empty
   * array on an empty query is a fine default — pass `enabled` via
   * `searchEnabled` if you want to gate it.
   */
  search: (query: string) => Promise<{ data: T[] }>

  /**
   * Hydration query for the IDs in `value` that we don't yet have
   * details for. Called once per `idsToHydrate` change. Should return
   * the listed records, in any order — they're keyed by `id`.
   *
   * If your endpoint can't bulk-fetch by ID, return what you can —
   * unmatched IDs render with their raw ID until the user picks them
   * from a search.
   */
  hydrate: (ids: string[]) => Promise<{ data: T[] }>

  /** Stable cache key for this picker instance — e.g. `'rule-products'`. */
  queryKey: string

  /** Renders the chip and dropdown row label. */
  getOptionLabel: (option: T) => string

  /** Placeholder for the search input. */
  placeholder?: string

  /** Empty state text shown in the dropdown when search returns nothing. */
  emptyText?: string

  /** Disable the whole picker. */
  disabled?: boolean
}

/**
 * Search-driven multi-select for a remote resource (products, taxons,
 * users, etc.). Mirrors the `<TagCombobox>` UX but with a server-driven
 * option list and lazy hydration of currently-selected IDs.
 *
 * Why this exists: every promotion rule that picks records (`Product`,
 * `Taxon`, `User`, `CustomerGroup`, `Country`, …) needs the same shape
 * — search + chips + hydration on first render. Centralising it here
 * keeps each rule editor down to ~30 lines of glue.
 */
export function ResourceMultiAutocomplete<T extends AutocompleteOption>({
  value,
  onChange,
  onResolvedOptionsChange,
  search,
  hydrate,
  queryKey,
  getOptionLabel,
  placeholder = 'Search…',
  emptyText = 'No results',
  disabled,
}: ResourceMultiAutocompleteProps<T>) {
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  // id → option cache. Survives across search queries so chips don't
  // flicker when `value` changes. Stored as a `Map` in state so we
  // never miss a render — TanStack Query's settle re-renders the
  // component, which re-derives `selectedOptions`/`items` from this.
  const [cache, setCache] = useState<Map<string, T>>(() => new Map())

  const cacheItems = useCallback((items: T[]) => {
    setCache((prev) => {
      let next: Map<string, T> | null = null
      for (const item of items) {
        if (prev.get(item.id) === item) continue
        next ??= new Map(prev)
        next.set(item.id, item)
      }
      return next ?? prev
    })
  }, [])

  // Hydrate any selected ID not yet in the cache. Recomputed when
  // `value` or `cache` changes; the query key only contains the
  // missing ids so re-toggling a known id doesn't refetch.
  const idsToHydrate = useMemo(() => value.filter((id) => !cache.has(id)), [value, cache])

  const { data: hydrateData } = useQuery({
    queryKey: [queryKey, 'hydrate', idsToHydrate],
    queryFn: () => hydrate(idsToHydrate),
    enabled: idsToHydrate.length > 0,
    staleTime: Number.POSITIVE_INFINITY,
  })

  const trimmedInput = inputValue.trim()

  const { data: searchData, isFetching } = useQuery({
    queryKey: [queryKey, 'search', trimmedInput],
    queryFn: () => search(trimmedInput),
    enabled: trimmedInput.length > 0,
  })

  // Mirror query results into the local id→option cache via an effect, not
  // inside `queryFn`. When the picker remounts (filter panel reopens) with
  // `staleTime: Infinity`, TanStack Query returns the cached result without
  // re-running `queryFn`, so writes inside `queryFn` are skipped. Reading
  // `data` here re-fires on every remount.
  useEffect(() => {
    if (hydrateData?.data?.length) cacheItems(hydrateData.data)
  }, [hydrateData, cacheItems])

  useEffect(() => {
    if (searchData?.data?.length) cacheItems(searchData.data)
  }, [searchData, cacheItems])

  // Dropdown items — search results, then any selected IDs not in
  // results so the user can deselect chips via the dropdown.
  const items = useMemo<T[]>(() => {
    const seen = new Set<string>()
    const list: T[] = []
    for (const item of searchData?.data ?? []) {
      if (seen.has(item.id)) continue
      seen.add(item.id)
      list.push(item)
    }
    for (const id of value) {
      if (seen.has(id)) continue
      const cached = cache.get(id)
      if (cached) {
        seen.add(id)
        list.push(cached)
      }
    }
    return list
  }, [searchData, value, cache])

  // Stub-fallback so chips show their ID until hydration lands.
  const selectedOptions = useMemo<T[]>(
    () => value.map((id) => cache.get(id) ?? ({ id } as T)),
    [value, cache],
  )

  const handleChange = useCallback(
    (next: T[]) => {
      onChange(next.map((o) => o.id))
      // Filter out stub `{id}` placeholders for un-hydrated IDs — callers
      // typically stamp these on parent state and stubs would overwrite
      // earlier real records.
      onResolvedOptionsChange?.(next.filter((o) => Object.keys(o).length > 1))
      setInputValue('')
    },
    [onChange, onResolvedOptionsChange],
  )

  return (
    <Combobox
      multiple
      items={items}
      value={selectedOptions}
      onValueChange={handleChange as never}
      itemToStringLabel={(o) => getOptionLabel(o as T)}
      itemToStringValue={(o) => (o as T).id}
      isItemEqualToValue={(a, b) => (a as T).id === (b as T).id}
      // Filtering is server-side: `search(query)` already narrows the result
      // set. Disable Base UI's client filter so it doesn't hide rows whose
      // label doesn't substring-match the typed query (the typed query is
      // often shorter than the actual label — partial email, first name
      // only, etc.).
      filter={null}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selected: T[]) =>
            selected.map((opt) => <ComboboxChip key={opt.id}>{getOptionLabel(opt)}</ComboboxChip>)
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder={placeholder}
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{isFetching ? 'Searching…' : emptyText}</ComboboxEmpty>
        <ComboboxList>
          {(option: T) => (
            <ComboboxItem key={option.id} value={option}>
              {getOptionLabel(option)}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
