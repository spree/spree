import {
  type ComboboxOption,
  ResourceCombobox as HeadlessResourceCombobox,
  type ResourceComboboxProps as HeadlessResourceComboboxProps,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { type ReactNode, useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'

export type { ComboboxOption } from '@spree/dashboard-ui'

export interface ResourceComboboxProps<T extends ComboboxOption>
  extends Pick<
    HeadlessResourceComboboxProps<T>,
    | 'value'
    | 'onChange'
    | 'getOptionLabel'
    | 'renderOption'
    | 'placeholder'
    | 'emptyText'
    | 'disabled'
  > {
  /**
   * Server-side search. Called as the user types (debounced via React's
   * `useDeferredValue`). Receives the trimmed query string — returning
   * `{ data: [] }` for empty queries is a fine default, as is showing
   * "recent records".
   */
  search: (query: string) => Promise<{ data: T[] }>

  /**
   * Hydrate the currently-selected ID into a record so the trigger can show
   * its label (e.g. on first render after deep-link reload). Called once
   * per `value` change. Should return the record listed by ID.
   */
  hydrate: (ids: string[]) => Promise<{ data: T[] }>

  /** Stable cache prefix — e.g. `'gift-card-customer-picker'`. */
  queryKey: string

  /** Optional richer item renderer (re-exposed; kept here for symmetry). */
  renderOption?: (option: T) => ReactNode
}

/**
 * Search-driven single-select for a remote resource (customers, variants,
 * stores, …). Wraps `@spree/dashboard-ui`'s pure `<ResourceCombobox>` with
 * TanStack Query: `search` is called as the user types, `hydrate` resolves
 * the currently-selected ID into a record on first render.
 *
 * Most callsites use this convenience wrapper. Reach for the headless version
 * in `@spree/dashboard-ui` when the data flow doesn't match this shape
 * (custom caching layer, local-only filtering, an externally-managed query).
 */
export function ResourceCombobox<T extends ComboboxOption>({
  value,
  onChange,
  search,
  hydrate,
  queryKey,
  getOptionLabel,
  renderOption,
  placeholder,
  emptyText,
  disabled,
}: ResourceComboboxProps<T>) {
  const { t } = useTranslation()
  const placeholderLabel = placeholder ?? t('admin.common.search_placeholder')
  const emptyLabel = emptyText ?? t('admin.common.no_results')

  // Base UI's Combobox owns the input element so it can write the selected
  // option's label into it on pick. We observe the typed query via
  // `onInputChange` on the Root rather than controlling
  // `<ComboboxInput value>` directly — controlling the input blocks Base UI
  // from updating it on selection.
  const [input, setInput] = useState('')
  // Defer the search query so a fast typist doesn't fire one request per
  // keystroke — React batches the search to the next idle paint.
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()

  const { data: searchData } = useQuery({
    queryKey: [queryKey, 'search', trimmedQuery],
    queryFn: () => search(trimmedQuery),
    staleTime: 30_000,
  })

  // Hydrate the currently selected ID into a record so the trigger shows
  // its label after a deep-link reload (before the user types anything).
  // Skipped when the search results already include the ID.
  const searchHasValue = !!(value && searchData?.data.some((r) => r.id === value))
  const { data: hydratedData } = useQuery({
    queryKey: [queryKey, 'hydrate', value],
    queryFn: () => hydrate([value as string]),
    enabled: !!value && !searchHasValue,
    staleTime: 60_000,
  })

  // Merge: prefer the (possibly fresher) search result if both have the ID.
  const items = useMemo(() => {
    const map = new Map<string, T>()
    for (const r of hydratedData?.data ?? []) map.set(r.id, r)
    for (const r of searchData?.data ?? []) map.set(r.id, r)
    return Array.from(map.values())
  }, [searchData, hydratedData])

  return (
    <HeadlessResourceCombobox
      value={value}
      onChange={onChange}
      items={items}
      onInputChange={setInput}
      getOptionLabel={getOptionLabel}
      renderOption={renderOption}
      placeholder={placeholderLabel}
      emptyText={emptyLabel}
      disabled={disabled}
    />
  )
}
