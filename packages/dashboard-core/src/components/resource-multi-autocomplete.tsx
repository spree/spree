import {
  type AutocompleteOption,
  ResourceMultiAutocomplete as HeadlessResourceMultiAutocomplete,
  type ResourceMultiAutocompleteProps as HeadlessResourceMultiAutocompleteProps,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useCallback, useEffect, useMemo, useState } from 'react'

export type { AutocompleteOption } from '@spree/dashboard-ui'

export interface ResourceMultiAutocompleteProps<T extends AutocompleteOption>
  extends Pick<
    HeadlessResourceMultiAutocompleteProps<T>,
    | 'value'
    | 'onChange'
    | 'onResolvedOptionsChange'
    | 'getOptionLabel'
    | 'placeholder'
    | 'emptyText'
    | 'disabled'
  > {
  /**
   * Server-side search. Receives the trimmed query string. Should return
   * `{ data: T[] }`. Called any time the user types (with debouncing
   * provided by the caller's queryClient if needed).
   */
  search: (query: string) => Promise<{ data: T[] }>

  /**
   * Hydration query for the IDs in `value` that we don't yet have
   * details for. Called once per `idsToHydrate` change. Should return
   * the listed records, in any order — they're keyed by `id`.
   */
  hydrate: (ids: string[]) => Promise<{ data: T[] }>

  /** Stable cache key for this picker instance — e.g. `'rule-products'`. */
  queryKey: string
}

/**
 * Search-driven multi-select for a remote resource. Wraps
 * `@spree/dashboard-ui`'s headless `<ResourceMultiAutocomplete>` with
 * TanStack Query: `search` fires as the user types; `hydrate` resolves any
 * selected IDs not yet in the cache so chips render with labels even after
 * a deep-link reload.
 *
 * Most callsites use this convenience wrapper. Reach for the headless
 * version in `@spree/dashboard-ui` when the data flow doesn't match this
 * shape (custom caching layer, local-only filtering, externally-managed
 * query state).
 */
export function ResourceMultiAutocomplete<T extends AutocompleteOption>({
  value,
  onChange,
  onResolvedOptionsChange,
  search,
  hydrate,
  queryKey,
  getOptionLabel,
  placeholder,
  emptyText,
  disabled,
}: ResourceMultiAutocompleteProps<T>) {
  const [inputValue, setInputValue] = useState('')

  // id → option cache. Survives across search queries so chips don't
  // flicker when `value` changes. Stored as a `Map` in state so we never
  // miss a render — TanStack Query's settle re-renders the component,
  // which re-derives `selectedOptions`/`items` from this.
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

  // Hydrate any selected ID not yet in the cache. Recomputed when `value`
  // or `cache` changes; the query key only contains the missing ids so
  // re-toggling a known id doesn't refetch.
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

  return (
    <HeadlessResourceMultiAutocomplete
      value={value}
      onChange={onChange}
      onResolvedOptionsChange={onResolvedOptionsChange}
      items={items}
      selectedOptions={selectedOptions}
      inputValue={inputValue}
      onInputChange={setInputValue}
      getOptionLabel={getOptionLabel}
      placeholder={placeholder}
      emptyText={emptyText}
      isFetching={isFetching}
      disabled={disabled}
    />
  )
}
