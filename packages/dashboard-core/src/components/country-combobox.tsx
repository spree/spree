import {
  Combobox,
  ComboboxButtonTrigger,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
  ComboboxValue,
  CountryFlag,
  useComboboxAnchor,
} from '@spree/dashboard-ui'
import { useCallback, useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCountries } from '../hooks/use-countries'
import { useDisplayName } from '../hooks/use-display-name'

export type CountryOption = { iso: string; iso3: string; name: string }

/**
 * Resolves a country's display name in the admin UI language (keyed on the
 * stable ISO code), falling back to the API's backend-locale `name` when the
 * runtime lacks coverage. Exported so every country-labelled surface
 * (pickers, grid cells) reads the same.
 *
 * The resolver is referentially stable across renders — callers feed it into
 * `useMemo` deps, and a fresh closure each render would rebuild every derived
 * option list (and, downstream, every grid column) on each keystroke.
 */
export function useCountryDisplayName() {
  const displayName = useDisplayName('region')
  return useCallback(
    (country: CountryOption) => displayName(country.iso) ?? country.name,
    [displayName],
  )
}

/**
 * Case-insensitive substring match against name, iso, and iso3 so the user
 * can find a country by typing "United States", "US", or "USA". Both pickers
 * filter the cached `useCountries()` list client-side — countries are a
 * ~250-row static set, so there's no remote search. Mirrors the server-side
 * `search` Ransack scope (`Spree::Country.search`).
 */
export function countryFilter(item: CountryOption, query: string): boolean {
  const q = query.trim().toLowerCase()
  if (!q) return true
  return (
    item.name.toLowerCase().includes(q) ||
    item.iso.toLowerCase().includes(q) ||
    item.iso3.toLowerCase().includes(q)
  )
}

/**
 * Filter that also matches the LOCALIZED country name shown to the user (not
 * just the raw backend `name` / ISO codes), so typing a translated label finds
 * its country. Memoized on the display-name resolver.
 */
function useCountryFilter() {
  const countryName = useCountryDisplayName()
  return useMemo(
    () => (item: CountryOption, query: string) => {
      const q = query.trim().toLowerCase()
      if (!q) return true
      return countryName(item).toLowerCase().includes(q) || countryFilter(item, query)
    },
    [countryName],
  )
}

/**
 * Shared dropdown row used by both pickers — flag + localized name + ISO code
 * in a muted suffix. The ISO code makes ISO-based matches (typing "US"/"USA")
 * comprehensible and keeps the two pickers visually consistent.
 */
function CountryRow({ country, label }: { country: CountryOption; label: string }) {
  return (
    <span className="flex items-center gap-3">
      <CountryFlag iso={country.iso} />
      <span>{label}</span>
      {country.iso && <span className="text-xs text-muted-foreground">({country.iso})</span>}
    </span>
  )
}

/** Maps the cached country list onto the flat option shape both pickers use. */
function useCountryOptions(): CountryOption[] {
  const { countries } = useCountries()
  return useMemo(
    () => countries.map((c) => ({ iso: c.iso, iso3: c.iso3, name: c.name })),
    [countries],
  )
}

/**
 * Searchable single-select country picker. Value is the 2-letter ISO code
 * (so the field round-trips cleanly with the Spree API).
 *
 * The field itself is a button showing the selected flag + name, with the
 * search box inside the dropdown — see `<ComboboxButtonTrigger>` for why a
 * text input is the wrong trigger for an address-adjacent picker.
 */
export function CountryCombobox({
  id,
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
  value: string | null | undefined
  onValueChange: (iso: string) => void
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
  const items = useCountryOptions()
  const countryName = useCountryDisplayName()
  const filter = useCountryFilter()

  // The Combobox holds the selected object internally; we adapt to a flat ISO
  // string at the boundary so callers don't have to thread the option shape.
  const selected = useMemo(() => items.find((c) => c.iso === value) ?? null, [items, value])

  return (
    <Combobox
      items={items}
      value={selected}
      onValueChange={(c: CountryOption | null) => onValueChange(c?.iso ?? '')}
      itemToStringLabel={(c: CountryOption | null) => (c ? countryName(c) : '')}
      itemToStringValue={(c: CountryOption | null) => c?.iso ?? ''}
      disabled={disabled}
      // Matches the localized name, the raw name, and both ISO codes so typing
      // "Allemagne", "Germany", "DE", or "DEU" all find the country.
      filter={filter}
    >
      <ComboboxButtonTrigger
        id={id}
        onBlur={onBlur}
        disabled={disabled}
        aria-invalid={invalid || undefined}
      >
        {selected ? (
          <>
            <CountryFlag iso={selected.iso} />
            <span className="truncate">{countryName(selected)}</span>
          </>
        ) : (
          <ComboboxTriggerPlaceholder>
            {placeholder ?? t('admin.components.country_combobox.placeholder')}
          </ComboboxTriggerPlaceholder>
        )}
      </ComboboxButtonTrigger>
      <ComboboxContent>
        <ComboboxSearch
          placeholder={
            searchPlaceholder ?? t('admin.components.country_combobox.search_placeholder')
          }
        />
        <ComboboxEmpty>{t('admin.components.country_combobox.empty')}</ComboboxEmpty>
        <ComboboxList>
          {(country: CountryOption) => (
            <ComboboxItem key={country.iso} value={country}>
              <CountryRow country={country} label={countryName(country)} />
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}

/**
 * Searchable multi-select country picker. Value is an array of 2-letter ISO
 * codes. Renders a flag + name per chip and `<CountryRow>` per dropdown row;
 * filters the cached `useCountries()` list client-side (localized name, raw
 * name, and both ISO codes). Reused anywhere the admin picks multiple
 * countries (promotion Country rule, market/zone editors, …).
 *
 * Keeps the chips-with-inline-input shape rather than a button trigger: the
 * chips are the selection display, and typing beside them is how a
 * multi-select is expected to work.
 */
export function CountryMultiCombobox({
  value,
  onValueChange,
  placeholder,
  emptyText,
  disabled = false,
}: {
  /** Selected 2-letter ISO codes. */
  value: string[]
  /** Fires with the next array of ISO codes. */
  onValueChange: (isos: string[]) => void
  placeholder?: string
  emptyText?: string
  disabled?: boolean
}) {
  const { t } = useTranslation()
  const items = useCountryOptions()
  const countryName = useCountryDisplayName()
  const filter = useCountryFilter()
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  // The Combobox holds full option objects; selection round-trips as ISO
  // strings. Selected ISOs not yet present in `items` (list still loading)
  // fall back to a stub so chips don't vanish on first render.
  const selected = useMemo<CountryOption[]>(
    () => value.map((iso) => items.find((c) => c.iso === iso) ?? { iso, iso3: '', name: iso }),
    [value, items],
  )

  return (
    <Combobox
      multiple
      items={items}
      value={selected}
      onValueChange={(next: CountryOption[]) => {
        onValueChange(next.map((c) => c.iso))
        setInputValue('')
      }}
      itemToStringLabel={(c: CountryOption | null) => (c ? countryName(c) : '')}
      itemToStringValue={(c: CountryOption | null) => c?.iso ?? ''}
      isItemEqualToValue={(a: CountryOption, b: CountryOption) => a.iso === b.iso}
      filter={filter}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedCountries: CountryOption[]) =>
            selectedCountries.map((c) => (
              <ComboboxChip key={c.iso}>
                {c.iso && <CountryFlag iso={c.iso} className="mr-2" />}
                {countryName(c)}
              </ComboboxChip>
            ))
          }
        </ComboboxValue>
        <ComboboxChipsInput
          placeholder={placeholder ?? t('admin.components.country_combobox.search_placeholder')}
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{emptyText ?? t('admin.components.country_combobox.empty')}</ComboboxEmpty>
        <ComboboxList>
          {(country: CountryOption) => (
            <ComboboxItem key={country.iso} value={country}>
              <CountryRow country={country} label={countryName(country)} />
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
