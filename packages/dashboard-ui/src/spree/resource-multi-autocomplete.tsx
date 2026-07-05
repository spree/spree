import { useCallback } from 'react'
import { useTranslation } from 'react-i18next'
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
} from '../ui/combobox'

/**
 * Anything we can pick. Items must have a stable string `id`. The label
 * (and any other rendering) is up to the caller via `getOptionLabel`.
 */
export type AutocompleteOption = { id: string }

/**
 * Safely resolve an option's label. The caller's `getOptionLabel` typically
 * reads hydrated fields (e.g. `c.email`), which throw or return blank when
 * called against a stub `{ id }`. Detect that case (single own key, the `id`)
 * and fall back to the raw id so chips for un-hydrated selections stay
 * readable until hydration lands.
 */
function labelOrFallback<T extends AutocompleteOption>(
  option: T,
  getOptionLabel: (option: T) => string,
): string {
  const isStub = Object.keys(option).length === 1 && 'id' in option
  if (isStub) return option.id
  try {
    return getOptionLabel(option) || option.id
  } catch {
    return option.id
  }
}

export interface ResourceMultiAutocompleteProps<T extends AutocompleteOption> {
  /** Currently selected IDs (controlled). */
  value: string[]
  onChange: (next: string[]) => void
  /**
   * Optional companion callback fired alongside `onChange` carrying the
   * resolved option records for the selected IDs. Use this to stamp display
   * labels on the parent state without re-fetching. IDs whose record isn't
   * yet hydrated will be absent from this list.
   */
  onResolvedOptionsChange?: (options: T[]) => void

  /**
   * Records available to render in the dropdown — typically search results
   * for the current query plus any selected records pulled from a cache.
   * The caller owns fetching, caching, and merging.
   */
  items: T[]

  /**
   * Records matching `value` that we already have details for. Used to
   * render chips with labels (and dispatch onResolvedOptionsChange with
   * the right records). IDs missing from `selectedOptions` render as
   * stubs (just the raw ID) until the caller hydrates them.
   */
  selectedOptions: T[]

  /** Current text in the search input. */
  inputValue: string
  /** Called when the user types or selects (selection clears the input). */
  onInputChange: (next: string) => void

  /** Renders the chip and dropdown row label. */
  getOptionLabel: (option: T) => string

  /** Placeholder for the search input. */
  placeholder?: string
  /** Empty state text shown in the dropdown when items is empty. */
  emptyText?: string
  /** Override emptyText when the consumer's search is in-flight. */
  fetchingText?: string
  /** True while the consumer's data source is loading. */
  isFetching?: boolean
  /** Disable the whole picker. */
  disabled?: boolean
}

/**
 * Headless search-driven multi-select picker. Doesn't fetch anything — the
 * caller passes `items` (visible options) + `selectedOptions` (records
 * matching `value`) + `inputValue`/`onInputChange` for the typed query.
 *
 * `@spree/dashboard-core` ships a convenience `<ResourceMultiAutocomplete>`
 * that wraps this with TanStack Query — that's what most callsites use.
 * Reach for the pure version here when the data flow doesn't match the
 * wrapper's shape.
 */
export function ResourceMultiAutocomplete<T extends AutocompleteOption>({
  value,
  onChange,
  onResolvedOptionsChange,
  items,
  selectedOptions,
  inputValue,
  onInputChange,
  getOptionLabel,
  placeholder,
  emptyText,
  fetchingText,
  isFetching,
  disabled,
}: ResourceMultiAutocompleteProps<T>) {
  const { t } = useTranslation()
  const resolvedPlaceholder = placeholder ?? t('admin.common.search_placeholder')
  const resolvedEmptyText = emptyText ?? t('admin.common.no_results')
  const resolvedFetchingText = fetchingText ?? t('admin.common.searching')
  const anchorRef = useComboboxAnchor()

  const handleChange = useCallback(
    (next: T[]) => {
      onChange(next.map((o) => o.id))
      // Filter out stub `{id}` placeholders for un-hydrated IDs — callers
      // typically stamp these on parent state and stubs would overwrite
      // earlier real records.
      onResolvedOptionsChange?.(next.filter((o) => Object.keys(o).length > 1))
      onInputChange('')
    },
    [onChange, onResolvedOptionsChange, onInputChange],
  )

  void value // silence unused (value is consumed via selectedOptions)

  return (
    <Combobox
      multiple
      items={items}
      value={selectedOptions}
      onValueChange={handleChange as never}
      itemToStringLabel={(o) => getOptionLabel(o as T)}
      itemToStringValue={(o) => (o as T).id}
      isItemEqualToValue={(a, b) => (a as T).id === (b as T).id}
      // Filtering is server-side: the caller's data source already narrows
      // the items list. Disable Base UI's client filter so it doesn't hide
      // rows whose label doesn't substring-match the typed query (the typed
      // query is often shorter than the actual label — partial email, etc.).
      filter={null}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selected: T[]) =>
            selected.map((opt) => (
              // Stubs (un-hydrated IDs) come through with only `{ id }`. Fall
              // back to the raw ID so the chip stays readable instead of going
              // blank while hydration is in flight; `getOptionLabel` can also
              // throw on stubs whose resolver assumes hydrated fields.
              <ComboboxChip key={opt.id}>{labelOrFallback(opt, getOptionLabel)}</ComboboxChip>
            ))
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder={resolvedPlaceholder}
          value={inputValue}
          onChange={(e) => onInputChange((e.target as HTMLInputElement).value)}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{isFetching ? resolvedFetchingText : resolvedEmptyText}</ComboboxEmpty>
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
