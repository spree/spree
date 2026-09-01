import type { DeliveryZone } from '@spree/admin-sdk'
import { useStore } from '@spree/dashboard-core'
import {
  Button,
  Checkbox,
  Input,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import {
  ChevronDownIcon,
  ChevronRightIcon,
  PlusIcon,
  SearchIcon,
  Trash2Icon,
} from '@spree/dashboard-ui/icons'
import { Link } from '@tanstack/react-router'
import { useMemo, useRef, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useCountryNames, useCountryStates, useMarketCountries } from '../../../hooks/use-geography'
import type { DeliveryZoneMemberValues } from '../../../schemas/delivery-zone'
import {
  type CountryRow,
  claimedByOtherZones,
  readSelection,
  type Selection,
  supersedeCountry,
  writeSelection,
} from './delivery-zone-selection'

/**
 * Picks the countries, states and postal-code rules a delivery zone covers.
 * The value is the flat member list the Admin API takes; the tree shape only
 * exists while the merchant is editing.
 */
export function DeliveryZoneRegionPicker({
  value,
  onChange,
  siblingZones,
}: {
  value: DeliveryZoneMemberValues[]
  onChange: (members: DeliveryZoneMemberValues[]) => void
  /** Other zones of the same profile — their countries cannot be claimed twice. */
  siblingZones: DeliveryZone[]
}) {
  const { t } = useTranslation()
  const { storeId } = useStore()
  const { countries: marketCountries, isLoading } = useMarketCountries()
  const countryNames = useCountryNames()
  const [search, setSearch] = useState('')
  const [expanded, setExpanded] = useState<string[]>([])
  const [postalOpen, setPostalOpen] = useState(false)

  const selection = useMemo(() => readSelection(value), [value])
  const claimed = useMemo(() => claimedByOtherZones(siblingZones), [siblingZones])

  const rows = useMemo<CountryRow[]>(() => {
    const byIso = new Map<string, CountryRow>()

    for (const country of marketCountries) {
      byIso.set(country.iso, {
        iso: country.iso,
        name: country.name,
        statesRequired: country.states_required,
        offMarket: false,
        claimed: claimed.countries.has(country.iso),
      })
    }

    // Anything the zone already holds outside the markets still gets a row —
    // dropping it here would delete the member on the next save.
    for (const iso of [...selection.countries, ...selection.states.keys()]) {
      if (byIso.has(iso)) continue
      byIso.set(iso, {
        iso,
        name: countryNames.get(iso) ?? iso,
        statesRequired: selection.states.has(iso),
        offMarket: true,
        claimed: false,
      })
    }

    return [...byIso.values()].sort((left, right) => left.name.localeCompare(right.name))
  }, [marketCountries, countryNames, claimed, selection])

  const visibleRows = useMemo(() => {
    const term = search.trim().toLowerCase()
    if (!term) return rows
    return rows.filter(
      (row) => row.name.toLowerCase().includes(term) || row.iso.toLowerCase().includes(term),
    )
  }, [rows, search])

  function apply(next: Partial<Selection>) {
    onChange(writeSelection({ ...selection, ...next }))
  }

  function toggleCountry(iso: string, checked: boolean) {
    if (checked) {
      apply(supersedeCountry(selection, iso))
      return
    }

    const countries = new Set(selection.countries)
    countries.delete(iso)
    apply({ countries })
  }

  /**
   * `allAbbrs` is the country's full state list, needed to unselect one state
   * of a wholly-selected country: that country member has to become an
   * explicit member per remaining state before one can be dropped.
   */
  function toggleState(iso: string, abbr: string, checked: boolean, allAbbrs: string[]) {
    const countries = new Set(selection.countries)
    const states = new Map(selection.states)
    const wholeCountry = countries.has(iso)
    const forCountry = new Set(wholeCountry ? allAbbrs : (states.get(iso) ?? []))

    if (checked) {
      forCountry.add(abbr)
    } else {
      forCountry.delete(abbr)
    }

    // Either way the country is no longer covered as a whole — it is now
    // described by the states below it.
    countries.delete(iso)

    if (forCountry.size > 0) states.set(iso, forCountry)
    else states.delete(iso)

    apply({ countries, states })
  }

  const selectedStateCount = [...selection.states.values()].reduce(
    (total, abbrs) => total + abbrs.size,
    0,
  )

  return (
    <div className="flex flex-col gap-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <span className="font-medium text-sm">{t('admin.delivery_zones.regions_title')}</span>
        <span className="text-muted-foreground text-xs">
          {t('admin.delivery_zones.selection_summary', {
            countries: selection.countries.size,
            states: selectedStateCount,
            rules: selection.postalRules.length,
          })}
        </span>
      </div>

      <div className="relative">
        <SearchIcon className="-translate-y-1/2 absolute top-1/2 left-2.5 size-4 text-muted-foreground" />
        <Input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder={t('admin.delivery_zones.region_search_placeholder')}
          aria-label={t('admin.delivery_zones.region_search_placeholder')}
          className="pl-8"
        />
      </div>

      <div className="max-h-72 overflow-y-auto rounded-md border">
        {isLoading && (
          <p className="p-3 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
        )}

        {!isLoading && visibleRows.length === 0 && (
          <p className="p-3 text-muted-foreground text-sm">
            {t('admin.delivery_zones.no_regions_found')}
          </p>
        )}

        {visibleRows.map((row) => (
          <CountryListRow
            key={row.iso}
            row={row}
            selectedWholeCountry={selection.countries.has(row.iso)}
            selectedStates={selection.states.get(row.iso) ?? new Set()}
            claimedStates={claimed.states.get(row.iso) ?? new Set()}
            expanded={expanded.includes(row.iso)}
            onToggleExpanded={() =>
              setExpanded((current) =>
                current.includes(row.iso)
                  ? current.filter((iso) => iso !== row.iso)
                  : [...current, row.iso],
              )
            }
            onToggleCountry={(checked) => toggleCountry(row.iso, checked)}
            onToggleState={(abbr, checked, allAbbrs) =>
              toggleState(row.iso, abbr, checked, allAbbrs)
            }
          />
        ))}
      </div>

      <Link
        to="/$storeId/settings/markets"
        params={{ storeId }}
        className="text-primary text-sm underline-offset-4 hover:underline"
      >
        {t('admin.delivery_zones.add_countries_in_markets')}
      </Link>

      <div className="rounded-md border">
        <button
          type="button"
          onClick={() => setPostalOpen((open) => !open)}
          className="flex w-full items-center gap-2 p-3 text-left font-medium text-sm"
          aria-expanded={postalOpen}
        >
          {postalOpen ? (
            <ChevronDownIcon className="size-4" />
          ) : (
            <ChevronRightIcon className="size-4" />
          )}
          {t('admin.delivery_zones.postal_rules_title')}
          {selection.postalRules.length > 0 && (
            <span className="text-muted-foreground text-xs">
              {t('admin.delivery_zones.postal_rules_count', {
                count: selection.postalRules.length,
              })}
            </span>
          )}
        </button>

        {postalOpen && (
          <PostalRulesSection
            rules={selection.postalRules}
            // A checked country already matches every address in it, so a
            // postal rule for it would be dead config — members OR together.
            countries={rows.filter((row) => !selection.countries.has(row.iso))}
            onChange={(postalRules) => apply({ postalRules })}
          />
        )}
      </div>
    </div>
  )
}

function CountryListRow({
  row,
  selectedWholeCountry,
  selectedStates,
  claimedStates,
  expanded,
  onToggleExpanded,
  onToggleCountry,
  onToggleState,
}: {
  row: CountryRow
  selectedWholeCountry: boolean
  selectedStates: Set<string>
  claimedStates: Set<string>
  expanded: boolean
  onToggleExpanded: () => void
  onToggleCountry: (checked: boolean) => void
  onToggleState: (abbr: string, checked: boolean, allAbbrs: string[]) => void
}) {
  const { t } = useTranslation()
  // Only an opened country pays for its states — the list runs to ~250 rows.
  const { states, isLoading } = useCountryStates(row.iso, expanded && row.statesRequired)

  const checked = selectedWholeCountry
  const indeterminate = !selectedWholeCountry && selectedStates.size > 0

  return (
    <div className="border-b last:border-b-0">
      <div className="flex items-center gap-2 px-3 py-2">
        <Checkbox
          checked={checked}
          indeterminate={indeterminate}
          disabled={row.claimed}
          onCheckedChange={onToggleCountry}
          aria-label={row.name}
        />
        <span
          className={`flex-1 text-sm ${row.claimed ? 'text-muted-foreground' : ''}`}
          data-testid="country-name"
        >
          {row.name}
          {row.offMarket && (
            <span className="ml-2 text-muted-foreground text-xs">
              {t('admin.delivery_zones.not_in_any_market')}
            </span>
          )}
        </span>

        {row.claimed ? (
          <span className="text-muted-foreground text-xs">
            {t('admin.delivery_zones.in_another_zone')}
          </span>
        ) : (
          row.statesRequired && (
            <button
              type="button"
              onClick={onToggleExpanded}
              className="flex items-center gap-1 text-muted-foreground text-xs hover:text-foreground"
              aria-expanded={expanded}
              aria-label={t('admin.delivery_zones.toggle_states', { country: row.name })}
            >
              {selectedWholeCountry
                ? t('admin.delivery_zones.all_states')
                : // The total is only known once the row has been opened and its
                  // states fetched, so before that only the selection is shown.
                  states.length > 0
                  ? t('admin.delivery_zones.states_summary', {
                      selected: selectedStates.size,
                      total: states.length,
                    })
                  : t('admin.delivery_zones.states_selected', {
                      count: selectedStates.size,
                    })}
              {expanded ? (
                <ChevronDownIcon className="size-4" />
              ) : (
                <ChevronRightIcon className="size-4" />
              )}
            </button>
          )
        )}
      </div>

      {expanded && row.statesRequired && !row.claimed && (
        <div className="border-t bg-muted/30 pl-9">
          {isLoading && (
            <p className="px-3 py-2 text-muted-foreground text-sm">{t('admin.common.loading')}</p>
          )}
          {!isLoading && states.length === 0 && (
            <p className="px-3 py-2 text-muted-foreground text-sm">
              {t('admin.delivery_zones.no_states')}
            </p>
          )}
          {states.map((state) => {
            const stateClaimed = claimedStates.has(state.abbr)
            return (
              <div key={state.abbr} className="flex items-center gap-2 px-3 py-1.5">
                <Checkbox
                  checked={selectedWholeCountry || selectedStates.has(state.abbr)}
                  disabled={stateClaimed}
                  onCheckedChange={(next) =>
                    onToggleState(
                      state.abbr,
                      next,
                      states.map((each) => each.abbr),
                    )
                  }
                  aria-label={state.name}
                />
                <span className={`flex-1 text-sm ${stateClaimed ? 'text-muted-foreground' : ''}`}>
                  {state.name}
                </span>
                {stateClaimed && (
                  <span className="text-muted-foreground text-xs">
                    {t('admin.delivery_zones.in_another_zone')}
                  </span>
                )}
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}

/**
 * Postal-code members: either a prefix or a from/to range, always tied to one
 * country. They sit apart from the country list because they narrow a country
 * the zone may not otherwise cover in full.
 */
function PostalRulesSection({
  rules,
  countries,
  onChange,
}: {
  rules: DeliveryZoneMemberValues[]
  countries: CountryRow[]
  onChange: (rules: DeliveryZoneMemberValues[]) => void
}) {
  const { t } = useTranslation()
  // Postal rules carry no id until they are saved, and the submitted payload
  // must not gain one, so React keys are minted here and kept out of the value.
  const keys = useRef<string[]>([])
  while (keys.current.length < rules.length) {
    keys.current = [...keys.current, `postal-rule-${crypto.randomUUID()}`]
  }

  const countryOptions = countries
    .filter((country) => !country.claimed)
    .map((country) => ({ value: country.iso, label: country.name }))

  function update(index: number, patch: Partial<DeliveryZoneMemberValues>) {
    onChange(rules.map((rule, position) => (position === index ? { ...rule, ...patch } : rule)))
  }

  function remove(index: number) {
    keys.current = keys.current.filter((_, position) => position !== index)
    onChange(rules.filter((_, position) => position !== index))
  }

  return (
    <div className="flex flex-col gap-2 border-t p-3">
      {rules.length === 0 && (
        <p className="text-muted-foreground text-sm">
          {t('admin.delivery_zones.no_postal_rules_hint')}
        </p>
      )}

      {rules.map((rule, index) => (
        <div key={keys.current[index]} className="flex flex-col gap-2 rounded-md border p-2">
          <div className="flex items-center gap-2">
            <Select
              items={countryOptions}
              value={rule.country_code ?? ''}
              onValueChange={(next) => update(index, { country_code: next as string })}
            >
              <SelectTrigger className="flex-1">
                <SelectValue>
                  {(value) =>
                    countryOptions.find((option) => option.value === value)?.label ??
                    t('admin.delivery_zones.select_country')
                  }
                </SelectValue>
              </SelectTrigger>
              <SelectContent>
                {countryOptions.map((option) => (
                  <SelectItem key={option.value} value={option.value}>
                    {option.label}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <Button
              type="button"
              variant="ghost"
              size="icon-sm"
              onClick={() => remove(index)}
              aria-label={t('admin.delivery_zones.remove_postal_rule')}
            >
              <Trash2Icon className="size-4" />
            </Button>
          </div>

          <div className="grid grid-cols-3 gap-2">
            <Input
              value={rule.postal_code_prefix ?? ''}
              onChange={(event) => update(index, { postal_code_prefix: event.target.value })}
              placeholder={t('admin.delivery_zones.prefix_placeholder')}
              aria-label={t('admin.delivery_zones.prefix_placeholder')}
            />
            <Input
              value={rule.postal_code_from ?? ''}
              onChange={(event) => update(index, { postal_code_from: event.target.value })}
              placeholder={t('admin.delivery_zones.from_placeholder')}
              aria-label={t('admin.delivery_zones.from_placeholder')}
            />
            <Input
              value={rule.postal_code_to ?? ''}
              onChange={(event) => update(index, { postal_code_to: event.target.value })}
              placeholder={t('admin.delivery_zones.to_placeholder')}
              aria-label={t('admin.delivery_zones.to_placeholder')}
            />
          </div>
        </div>
      ))}

      <div>
        <Button
          type="button"
          variant="outline"
          size="sm"
          onClick={() =>
            onChange([
              ...rules,
              {
                member_type: 'postal_code',
                country_code: countryOptions[0]?.value ?? '',
                postal_code_prefix: '',
                postal_code_from: '',
                postal_code_to: '',
              },
            ])
          }
        >
          <PlusIcon className="size-4" />
          {t('admin.delivery_zones.add_postal_rule')}
        </Button>
      </div>
    </div>
  )
}
