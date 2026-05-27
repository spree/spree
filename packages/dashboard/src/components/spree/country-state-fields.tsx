import type { State } from '@spree/admin-sdk'
import {
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
} from '@spree/dashboard-ui'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { useCountries } from '@/hooks/use-countries'

type StateOption = { abbr: string; name: string }

/**
 * Country/state lookup for the active country selection. `states` is empty
 * when the country doesn't enumerate them (free-text region); `statesRequired`
 * tells callers whether to fall back to a plain text input.
 */
export function useCountryStates(countryIso: string | null | undefined) {
  const { countries } = useCountries()
  const country = useMemo(
    () => countries.find((c) => c.iso === countryIso) ?? null,
    [countries, countryIso],
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
 * Keyed on `countryIso` so the internal state is reset when the country
 * changes — prevents a stale highlight from a previous country.
 */
export function StateCombobox({
  countryIso,
  states,
  value,
  onValueChange,
  placeholder,
  disabled = false,
}: {
  countryIso: string | null | undefined
  /** State list for the active country (typically from `useCountryStates`). */
  states: Pick<State, 'abbr' | 'name'>[]
  value: string | null | undefined
  onValueChange: (abbr: string) => void
  placeholder?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const items = states as StateOption[]
  const selected = useMemo(() => items.find((s) => s.abbr === value) ?? null, [items, value])

  return (
    <Combobox
      key={countryIso ?? 'no-country'}
      items={items}
      value={selected}
      onValueChange={(s: StateOption | null) => onValueChange(s?.abbr ?? '')}
      itemToStringLabel={(s: StateOption | null) => s?.name ?? ''}
      itemToStringValue={(s: StateOption | null) => s?.abbr ?? ''}
    >
      <ComboboxInput
        placeholder={placeholder ?? t('admin.components.state_combobox.search_placeholder')}
        disabled={disabled}
      />
      <ComboboxContent>
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
