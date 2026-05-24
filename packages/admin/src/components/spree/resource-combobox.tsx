import { useQuery } from '@tanstack/react-query'
import { type ReactNode, useDeferredValue, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import {
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
} from '@/components/ui/combobox'

/**
 * Anything we can pick. Records must have a stable string `id` so they round-
 * trip through the `value` prop (the form/parent state keeps the ID, not the
 * full record).
 */
export type ComboboxOption = { id: string }

export interface ResourceComboboxProps<T extends ComboboxOption> {
  /** Currently selected ID. */
  value: string | undefined | null
  /** Fires with the picked record's ID, or `undefined` when cleared. */
  onChange: (id: string | undefined, record: T | null) => void

  /**
   * Server-side search. Called as the user types (with React's
   * `useDeferredValue` to avoid a request per keystroke). Receives the
   * trimmed query string — returning `{ data: [] }` for empty queries is a
   * fine default, as is showing "recent records".
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

  /** Renders the trigger + item label. */
  getOptionLabel: (option: T) => string

  /**
   * Optional richer item renderer for the dropdown. Falls back to
   * `getOptionLabel` when omitted. Use this to show a secondary line
   * (e.g. the customer's full name under their email).
   */
  renderOption?: (option: T) => ReactNode

  placeholder?: string
  emptyText?: string
  disabled?: boolean
}

/**
 * Search-driven single-select for a remote resource (customers, variants,
 * stores, …). Mirrors `<ResourceMultiAutocomplete>`'s data contract — pass
 * `search` + `hydrate` + `getOptionLabel` callbacks — but renders the
 * shadcn `<Combobox>` instead of the chips multi-picker, so the trigger
 * reads like a single-value input.
 *
 * Why this exists: hand-rolled `<Input>` + custom dropdown patterns (see
 * pre-refactor `routes/.../orders/new.tsx`) duplicate keyboard/a11y/focus
 * code per call site. Centralising on this combobox keeps every picker
 * accessible and visually consistent.
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
  // `onInputValueChange` on the Root rather than controlling
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

  const selected = useMemo<T | null>(
    () => items.find((r) => r.id === value) ?? null,
    [items, value],
  )

  return (
    <Combobox
      items={items}
      value={selected}
      onValueChange={(record: T | null) => onChange(record?.id, record)}
      onInputValueChange={(next: string) => setInput(next)}
      itemToStringLabel={(record: T | null) => (record ? getOptionLabel(record) : '')}
      itemToStringValue={(record: T | null) => record?.id ?? ''}
      // Filtering is server-side: `search(query)` already narrows the
      // result set. Disable Base UI's built-in client filter so it doesn't
      // hide rows whose label doesn't substring-match the typed query.
      filter={null}
    >
      <ComboboxInput placeholder={placeholderLabel} disabled={disabled} showClear />
      <ComboboxContent>
        <ComboboxEmpty>{emptyLabel}</ComboboxEmpty>
        <ComboboxList>
          {(record: T) => (
            <ComboboxItem key={record.id} value={record}>
              {renderOption ? renderOption(record) : getOptionLabel(record)}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
