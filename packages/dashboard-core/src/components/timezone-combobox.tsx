import { TIME_ZONES } from '@spree/core'
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

type TimezoneOption = { zone: string; offset: string }

// Browsers list zones under their own, sometimes older, names (`Asia/Calcutta`
// for the `Asia/Kolkata` a store is saved with) and leave out `UTC`, the store
// default, so Spree's suggestions are always merged in.
const TIMEZONES: string[] = (() => {
  let browserZones: string[] = []
  try {
    browserZones = Intl.supportedValuesOf('timeZone')
  } catch {
    // Older browsers cannot list zones; Spree's suggestions stand alone.
  }
  const zones = new Set<string>([...TIME_ZONES, ...browserZones])
  zones.delete('UTC')
  return ['UTC', ...[...zones].sort()]
})()

/** The zone's current offset from UTC, such as `GMT+5:30`, or '' when unknown. */
function utcOffset(zone: string) {
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone: zone,
      timeZoneName: 'shortOffset',
    }).formatToParts(new Date())
    return parts.find((part) => part.type === 'timeZoneName')?.value ?? ''
  } catch {
    return ''
  }
}

/** Typing "new york", "kolkata" or "GMT+5" finds the zone. */
function matches(option: TimezoneOption, query: string) {
  const q = query.trim().toLowerCase()
  if (!q) return true
  return (
    option.zone.toLowerCase().replaceAll('_', ' ').includes(q.replaceAll('_', ' ')) ||
    option.offset.toLowerCase().includes(q)
  )
}

/**
 * Searchable timezone picker. Value is the IANA name the store saves. A saved
 * zone missing from both lists stays selectable.
 */
export function TimezoneCombobox({
  id,
  value,
  onValueChange,
  onBlur,
  invalid,
}: {
  id?: string
  value: string | null | undefined
  onValueChange: (zone: string) => void
  onBlur?: () => void
  invalid?: boolean
}) {
  const { t } = useTranslation()
  const items = useMemo(
    () =>
      (!value || TIMEZONES.includes(value) ? TIMEZONES : [value, ...TIMEZONES]).map((zone) => ({
        zone,
        offset: utcOffset(zone),
      })),
    [value],
  )
  const selected = items.find((option) => option.zone === value) ?? null

  return (
    <Combobox
      items={items}
      value={selected}
      onValueChange={(option: TimezoneOption | null) => option && onValueChange(option.zone)}
      itemToStringLabel={(option: TimezoneOption | null) => option?.zone ?? ''}
      itemToStringValue={(option: TimezoneOption | null) => option?.zone ?? ''}
      filter={matches}
    >
      <ComboboxButtonTrigger id={id} onBlur={onBlur} aria-invalid={invalid || undefined}>
        {selected ? (
          <span className="truncate">{selected.zone}</span>
        ) : (
          <ComboboxTriggerPlaceholder>
            {t('admin.components.timezone_combobox.placeholder')}
          </ComboboxTriggerPlaceholder>
        )}
      </ComboboxButtonTrigger>
      <ComboboxContent>
        <ComboboxSearch placeholder={t('admin.components.timezone_combobox.search_placeholder')} />
        <ComboboxEmpty>{t('admin.components.timezone_combobox.empty')}</ComboboxEmpty>
        <ComboboxList>
          {(option: TimezoneOption) => (
            <ComboboxItem key={option.zone} value={option}>
              <span className="flex min-w-0 items-center gap-3">
                <span className="truncate">{option.zone}</span>
                {option.offset && (
                  <span className="text-xs text-muted-foreground">{option.offset}</span>
                )}
              </span>
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
