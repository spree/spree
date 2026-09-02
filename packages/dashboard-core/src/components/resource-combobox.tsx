import {
  type ComboboxOption,
  ResourceCombobox as HeadlessResourceCombobox,
  type ResourceComboboxProps as HeadlessResourceComboboxProps,
} from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useTenantId } from '../providers/tenant-provider'

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
    | 'id'
  > {
  /**
   * Server-side search. Called as the user types (debounced via React's
   * `useDeferredValue`). Receives the trimmed query string — returning
   * `{ data: [] }` for empty queries is a fine default, as is showing
   * "recent records". When the response includes `meta.count`, rows beyond
   * `data.length` trigger a footer hint so a capped list does not read complete.
   */
  search: (query: string) => Promise<{ data: T[]; meta?: { count: number } }>

  /**
   * Hydrate the currently-selected ID into a record so the trigger can show
   * its label (e.g. on first render after deep-link reload). Called once
   * per `value` change. Should return the record listed by ID.
   */
  hydrate: (ids: string[]) => Promise<{ data: T[] }>

  /** Stable cache prefix — e.g. `'gift-card-customer-picker'`. */
  queryKey: string

  /**
   * Optional client-side predicate applied after fetch/hydrate to hide rows
   * that should never be selectable (e.g. a category can't be its own parent).
   * Returning `false` drops the row from the dropdown.
   */
  filterOption?: (option: T) => boolean
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
  filterOption,
  id,
}: ResourceComboboxProps<T>) {
  const { t } = useTranslation()
  const placeholderLabel = placeholder ?? t('admin.common.search_placeholder')
  const emptyLabel = emptyText ?? t('admin.common.no_results')

  // Base UI's Combobox owns the input element so it can write the selected
  // option's label into it on pick. We observe the typed query via
  // `onInputChange` on the Root rather than controlling
  // `<ComboboxInput value>` directly — controlling the input blocks Base UI
  // from updating it on selection.
  // Scoped here, not at the call site: results are tenant-specific (a store in
  // the dashboard, a seller in the seller panel), and a caller passing a
  // constant key would otherwise serve one tenant's records in another.
  const tenantId = useTenantId()
  const [input, setInput] = useState('')
  // Defer the search query so a fast typist doesn't fire one request per
  // keystroke — React batches the search to the next idle paint.
  const deferredInput = useDeferredValue(input)
  const trimmedQuery = deferredInput.trim()

  const { data: searchData } = useQuery({
    queryKey: [queryKey, tenantId, 'search', trimmedQuery],
    queryFn: () => search(trimmedQuery),
    staleTime: 30_000,
  })

  // Hydrate the currently selected ID into a record so the trigger shows
  // its label after a deep-link reload (before the user types anything).
  // Skipped when the search results already include the ID.
  const searchHasValue = !!(value && searchData?.data.some((r) => r.id === value))
  const { data: hydratedData } = useQuery({
    queryKey: [queryKey, tenantId, 'hydrate', value],
    queryFn: () => hydrate([value as string]),
    enabled: !!value && !searchHasValue,
    staleTime: 60_000,
  })

  // Merge: prefer the (possibly fresher) search result if both have the ID.
  const items = useMemo(() => {
    const map = new Map<string, T>()
    for (const r of hydratedData?.data ?? []) map.set(r.id, r)
    for (const r of searchData?.data ?? []) map.set(r.id, r)
    const merged = Array.from(map.values())
    return filterOption ? merged.filter(filterOption) : merged
  }, [searchData, hydratedData, filterOption])

  const visibleSearchCount = searchData?.data.length ?? 0
  const hiddenCount = Math.max(0, (searchData?.meta?.count ?? 0) - visibleSearchCount)

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
      listFooter={
        hiddenCount > 0 ? (
          <p className="border-t border-border px-2.5 py-2 text-muted-foreground text-xs">
            {t('admin.common.combobox_more_results', { count: hiddenCount })}
          </p>
        ) : undefined
      }
      disabled={disabled}
      id={id}
    />
  )
}
