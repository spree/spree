import type { ReactNode } from 'react'
import {
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
} from '../ui/combobox'

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
   * Records available to render in the dropdown. The caller owns fetching +
   * caching; pass whatever subset of options should currently be visible.
   * Must include the record matching `value` so the trigger can render its
   * label, otherwise the trigger falls back to the raw ID.
   */
  items: T[]

  /**
   * Called as the user types — receives the raw input string. The caller
   * typically debounces and queries with it. The combobox does NOT manage
   * any internal input/query state.
   */
  onInputChange?: (next: string) => void

  /** Renders the trigger + item label. */
  getOptionLabel: (option: T) => string

  /**
   * Optional richer item renderer for the dropdown. Falls back to
   * `getOptionLabel` when omitted.
   */
  renderOption?: (option: T) => ReactNode

  /** Placeholder for the search input. */
  placeholder?: string
  /** Empty state text shown in the dropdown when items is empty. */
  emptyText?: string
  disabled?: boolean
}

/**
 * Headless search-driven single-select picker. Doesn't fetch anything itself —
 * pass `items` plus an `onInputChange` callback and wire the data layer
 * outside (TanStack Query, SWR, manual state, whatever).
 *
 * `@spree/dashboard-core` ships a convenience `<ResourceCombobox>` (same name,
 * same props shape minus `items`/`onInputChange`, plus a `search`/`hydrate`/
 * `queryKey` interface) that wraps this one with TanStack Query — that's what
 * most callsites use. Reach for the pure version here when the data flow
 * doesn't match the wrapper's shape.
 */
export function ResourceCombobox<T extends ComboboxOption>({
  value,
  onChange,
  items,
  onInputChange,
  getOptionLabel,
  renderOption,
  placeholder,
  emptyText,
  disabled,
}: ResourceComboboxProps<T>) {
  const selected = items.find((r) => r.id === value) ?? null

  return (
    <Combobox
      items={items}
      value={selected}
      onValueChange={(record: T | null) => onChange(record?.id, record)}
      onInputValueChange={onInputChange}
      itemToStringLabel={(record: T | null) => (record ? getOptionLabel(record) : '')}
      itemToStringValue={(record: T | null) => record?.id ?? ''}
      // Filtering is server-side: the caller's `onInputChange` already narrows
      // the items list. Disable Base UI's built-in client filter so it doesn't
      // hide rows whose label doesn't substring-match the typed query.
      filter={null}
      // Mirror multi-autocomplete: `disabled` on the root also disables the
      // dropdown trigger + selection mechanics, not just the input.
      disabled={disabled}
    >
      <ComboboxInput placeholder={placeholder} disabled={disabled} showClear />
      <ComboboxContent>
        <ComboboxEmpty>{emptyText}</ComboboxEmpty>
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
