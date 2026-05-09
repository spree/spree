import type { State } from '@spree/admin-sdk'
import { useMemo } from 'react'
import { CountryFlag } from '@/components/spree/country-flag'
import {
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
} from '@/components/ui/combobox'
import { InputGroupAddon } from '@/components/ui/input-group'
import { useCountries } from '@/hooks/use-countries'

type CountryOption = { iso: string; name: string }
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

// ---------------------------------------------------------------------------
// CountryCombobox
// ---------------------------------------------------------------------------

/**
 * Searchable country picker. Value is the 2-letter ISO code (so the field
 * round-trips cleanly with the Spree API). Renders the country name + flag in
 * the trigger and dropdown.
 */
export function CountryCombobox({
  value,
  onValueChange,
  placeholder = 'Search countries...',
  disabled = false,
}: {
  value: string | null | undefined
  onValueChange: (iso: string) => void
  placeholder?: string
  disabled?: boolean
}) {
  const { countries } = useCountries()

  const items: CountryOption[] = useMemo(
    () => countries.map((c) => ({ iso: c.iso, name: c.name })),
    [countries],
  )

  // The Combobox holds the selected object internally; we adapt to a flat ISO
  // string at the boundary so callers don't have to thread the option shape.
  const selected = useMemo(() => items.find((c) => c.iso === value) ?? null, [items, value])

  return (
    <Combobox
      items={items}
      value={selected}
      onValueChange={(c: CountryOption | null) => onValueChange(c?.iso ?? '')}
      itemToStringLabel={(c: CountryOption | null) => c?.name ?? ''}
      itemToStringValue={(c: CountryOption | null) => c?.iso ?? ''}
    >
      <ComboboxInput placeholder={placeholder} disabled={disabled}>
        {/* When a country is picked the InputGroup gets a leading flag —
            mirrors the dropdown items so the trigger shows the same shape.
            Hidden while empty so the input doesn't lurch when typing a new
            search query. */}
        {selected?.iso && (
          <InputGroupAddon align="inline-start">
            <CountryFlag iso={selected.iso} />
          </InputGroupAddon>
        )}
      </ComboboxInput>
      <ComboboxContent>
        <ComboboxEmpty>No countries found</ComboboxEmpty>
        <ComboboxList>
          {(country: CountryOption) => (
            <ComboboxItem key={country.iso} value={country}>
              <CountryFlag iso={country.iso} />
              {country.name}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}

// ---------------------------------------------------------------------------
// StateCombobox
// ---------------------------------------------------------------------------

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
  placeholder = 'Search states...',
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
      <ComboboxInput placeholder={placeholder} disabled={disabled} />
      <ComboboxContent>
        <ComboboxEmpty>No states found</ComboboxEmpty>
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
