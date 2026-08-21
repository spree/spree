import type { State } from '@spree/admin-sdk'
import {
  Combobox,
  ComboboxButtonTrigger,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
} from '@spree/dashboard-ui'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useCountries } from '../hooks/use-countries'

type StateOption = { abbr: string; name: string }

/**
 * Country/state lookup for the active country selection. `states` is empty
 * when the country doesn't enumerate them (free-text region); `statesRequired`
 * tells callers whether to fall back to a plain text input.
 */
export function useCountryStates(countryCode: string | null | undefined) {
  const { countries } = useCountries()
  const country = useMemo(
    () => countries.find((c) => c.iso === countryCode) ?? null,
    [countries, countryCode],
  )
  return {
    states: ((country?.states ?? []) as StateOption[]).filter((s) => Boolean(s.abbr)),
    statesRequired: country?.states_required ?? false,
  }
}

/**
 * Searchable state/province picker for a given country. Value is the state
 * abbreviation (e.g. "CA"). Callers should hide this and render a free-text
 * Input when `useCountryStates(...).states` is empty.
 *
 * Shares the country picker's button-trigger shape — the two sit side by side
 * in every address form, so they have to look alike, and the state field is
 * exactly as prone to being buried by the browser's saved-address panel.
 *
 * Keyed on `countryCode` so the internal state is reset when the country
 * changes — prevents a stale highlight from a previous country.
 */
export function StateCombobox({
  id,
  countryCode,
  states,
  value,
  onValueChange,
  onBlur,
  placeholder,
  searchPlaceholder,
  invalid,
  disabled = false,
}: {
  /** Forwarded to the trigger so a `<FieldLabel htmlFor>` can target it. */
  id?: string
  countryCode: string | null | undefined
  /** State list for the active country (typically from `useCountryStates`). */
  states: Pick<State, 'abbr' | 'name'>[]
  value: string | null | undefined
  onValueChange: (abbr: string) => void
  /** Forwarded to the trigger so RHF's `<Controller>` can track touched state. */
  onBlur?: () => void
  /** Trigger text while nothing is selected. */
  placeholder?: string
  /** Text in the dropdown's search box. */
  searchPlaceholder?: string
  invalid?: boolean
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const items = states as StateOption[]
  const selected = useMemo(() => items.find((s) => s.abbr === value) ?? null, [items, value])

  return (
    <Combobox
      key={countryCode ?? 'no-country'}
      items={items}
      value={selected}
      onValueChange={(s: StateOption | null) => onValueChange(s?.abbr ?? '')}
      itemToStringLabel={(s: StateOption | null) => s?.name ?? ''}
      itemToStringValue={(s: StateOption | null) => s?.abbr ?? ''}
      disabled={disabled}
    >
      <ComboboxButtonTrigger
        id={id}
        onBlur={onBlur}
        disabled={disabled}
        aria-invalid={invalid || undefined}
      >
        {selected ? (
          <span className="truncate">{selected.name}</span>
        ) : (
          <ComboboxTriggerPlaceholder>
            {placeholder ?? t('admin.components.state_combobox.placeholder')}
          </ComboboxTriggerPlaceholder>
        )}
      </ComboboxButtonTrigger>
      <ComboboxContent>
        <ComboboxSearch
          placeholder={searchPlaceholder ?? t('admin.components.state_combobox.search_placeholder')}
        />
        <ComboboxEmpty>{t('admin.components.state_combobox.empty')}</ComboboxEmpty>
        <ComboboxList>
          {(state: StateOption) => (
            <ComboboxItem key={state.abbr} value={state}>
              {state.name}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
