import {
  Combobox,
  ComboboxChip,
  ComboboxChips,
  ComboboxChipsInput,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  ComboboxValue,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  useComboboxAnchor,
} from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDisplayName } from '../hooks/use-display-name'
import { useStore } from '../providers/store-provider'

interface BaseProps {
  /** Locale codes to pick from. Defaults to the current store's `supported_locales`. */
  options?: string[]
  /** Locale to filter out (e.g. the default locale when picking additional supported ones). */
  excludeCode?: string
  /** Marks the field required for screen readers + native form submission. */
  required?: boolean
  disabled?: boolean
  placeholder?: string
  /** ID for the trigger / chips input — paired with the parent `<FieldLabel htmlFor>`. */
  id?: string
}

interface SingleProps extends BaseProps {
  multiple?: false
  value: string | null | undefined
  onChange: (locale: string) => void
}

interface MultiProps extends BaseProps {
  multiple: true
  value: string[]
  onChange: (locales: string[]) => void
}

type LocaleSelectProps = SingleProps | MultiProps

/**
 * Resolves a locale code (`en`, `pt-BR`) to its display name (`English`,
 * `Portuguese (Brazil)`) in the admin UI language, falling back to the code
 * itself when the runtime lacks coverage.
 */
function useLocaleDisplayName() {
  const displayName = useDisplayName('language')
  return (code: string) => displayName(code) ?? code
}

/** Mirrors `CurrencySelect`'s row format: `CODE — Localized Name`. */
function formatOption(code: string, name: string) {
  const upper = code.toUpperCase()
  return name === code ? upper : `${upper} — ${name}`
}

/** Above this many options a plain `<Select>` is unwieldy — switch to a
 *  searchable combobox. Matches `CurrencySelect`. */
const SEARCHABLE_THRESHOLD = 12

/**
 * Combobox `filter` factory shared by the single- and multi-select pickers:
 * case-insensitive match on both the raw code and the localized `CODE — Name`
 * label, so typing "pt", "BR", or "Portuguese" all find `pt-BR`.
 */
function localeFilter(labelFor: (locale: string) => string) {
  return (locale: string, query: string) => {
    const q = query.trim().toLowerCase()
    if (!q) return true
    return locale.toLowerCase().includes(q) || labelFor(locale).toLowerCase().includes(q)
  }
}

/**
 * Static text label for a locale code: `EN — English`. Use this in tables
 * and read-only contexts where the picker isn't needed but the same
 * formatting is. Falls back to the upper-cased code when `Intl.DisplayNames`
 * has no entry.
 */
export function LocaleLabel({ code }: { code: string }) {
  const displayNameFor = useLocaleDisplayName()
  if (!code) return null
  return <>{formatOption(code, displayNameFor(code))}</>
}

/**
 * Picker for one of the current store's `supported_locales`. Single-select by
 * default; pass `multiple` for a chips multi-select. Each option reads
 * `CODE — Localized Name` (e.g. `EN — English`), localized via the browser's
 * `Intl.DisplayNames` against the store's `default_locale`. Use this anywhere
 * the merchant is choosing a storefront language (market default, supported
 * locales list, customer preference, etc.).
 */
export function LocaleSelect(props: LocaleSelectProps) {
  const { t } = useTranslation()
  const { locales: storeLocales } = useStore()
  const displayNameFor = useLocaleDisplayName()

  // Union of `props.options` (everything the picker should show) and the
  // currently selected values — so editing an existing record doesn't
  // silently drop chips when the store's locale list later narrows.
  // An empty `options` (store not loaded yet, or a backend that omits
  // `available_locales`) falls back to the store's configured locales rather
  // than rendering an empty picker — matching `CurrencySelect`.
  const items = useMemo(() => {
    const base = props.options?.length ? props.options : storeLocales
    const selected = props.multiple ? props.value : props.value ? [props.value] : []
    const merged = Array.from(new Set([...base, ...selected]))
    return props.excludeCode ? merged.filter((l) => l !== props.excludeCode) : merged
  }, [props.options, props.excludeCode, props.multiple, props.value, storeLocales])

  // Precompute each option's `CODE — Name` label once. The searchable combobox
  // below runs `renderOption` across every item on each keystroke (filter +
  // render), so resolving `Intl.DisplayNames` per call would repeat ~N lookups
  // per character; a lookup map keeps it to a single pass per list change.
  const labels = useMemo(() => {
    const map = new Map<string, string>()
    for (const locale of items) map.set(locale, formatOption(locale, displayNameFor(locale)))
    return map
  }, [items, displayNameFor])

  // `CODE — Name` label for a locale, from the precomputed map (falls back to a
  // direct lookup for a value not in the current option list, e.g. a selected
  // chip the list later dropped).
  const labelFor = (locale: string) =>
    labels.get(locale) ?? formatOption(locale, displayNameFor(locale))

  if (props.multiple) {
    return (
      <MultiLocalePicker
        id={props.id}
        items={items}
        value={props.value}
        onChange={props.onChange}
        labelFor={labelFor}
        placeholder={props.placeholder ?? t('admin.components.locale_select.multi_placeholder')}
        emptyText={t('admin.components.locale_select.empty')}
        disabled={props.disabled}
      />
    )
  }

  const value = props.value ?? ''
  const placeholder = props.placeholder ?? t('admin.components.locale_select.placeholder')

  // Long lists (e.g. the full set of translatable locales) are unusable as a
  // plain dropdown — switch to a searchable combobox, matching `CurrencySelect`.
  if (items.length > SEARCHABLE_THRESHOLD) {
    return (
      <Combobox
        items={items}
        value={value}
        onValueChange={(next: string | null) => props.onChange(next ?? '')}
        itemToStringLabel={(locale: string | null) => (locale ? labelFor(locale) : '')}
        itemToStringValue={(locale: string | null) => locale ?? ''}
        filter={localeFilter(labelFor)}
        disabled={props.disabled}
      >
        <ComboboxInput id={props.id} aria-required={props.required} placeholder={placeholder} />
        <ComboboxContent>
          <ComboboxEmpty>{t('admin.components.locale_select.empty')}</ComboboxEmpty>
          <ComboboxList>
            {(locale: string) => (
              <ComboboxItem key={locale} value={locale}>
                {labelFor(locale)}
              </ComboboxItem>
            )}
          </ComboboxList>
        </ComboboxContent>
      </Combobox>
    )
  }

  return (
    <Select value={value} onValueChange={props.onChange} disabled={props.disabled}>
      <SelectTrigger id={props.id} aria-required={props.required}>
        {/* Base UI's `<SelectValue>` defaults to the raw locale code. Use
            the children render-prop so the trigger shows the same
            `CODE — Name` as the items. */}
        <SelectValue placeholder={placeholder}>
          {(v) => (v ? labelFor(v as string) : (v as string))}
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        {items.map((locale) => (
          <SelectItem key={locale} value={locale}>
            {labelFor(locale)}
          </SelectItem>
        ))}
      </SelectContent>
    </Select>
  )
}

function MultiLocalePicker({
  id,
  items,
  value,
  onChange,
  labelFor,
  placeholder,
  emptyText,
  disabled,
}: {
  id?: string
  items: string[]
  value: string[]
  onChange: (locales: string[]) => void
  labelFor: (code: string) => string
  placeholder: string
  emptyText: string
  disabled?: boolean
}) {
  const anchorRef = useComboboxAnchor()
  const [inputValue, setInputValue] = useState('')

  return (
    <Combobox
      multiple
      items={items}
      value={value}
      onValueChange={(next: string[]) => {
        onChange(next)
        setInputValue('')
      }}
      // Search the same `CODE — Name` labels as the single-select picker — the
      // canonical locale list is too long to scan by raw code alone.
      itemToStringLabel={(locale: string | null) => (locale ? labelFor(locale) : '')}
      itemToStringValue={(locale: string | null) => locale ?? ''}
      filter={localeFilter(labelFor)}
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedLocales: string[]) =>
            selectedLocales.map((l) => <ComboboxChip key={l}>{labelFor(l)}</ComboboxChip>)
          }
        </ComboboxValue>
        <ComboboxChipsInput
          id={id}
          placeholder={placeholder}
          value={inputValue}
          onChange={(e) => setInputValue((e.target as HTMLInputElement).value)}
        />
      </ComboboxChips>
      <ComboboxContent anchor={anchorRef}>
        <ComboboxEmpty>{emptyText}</ComboboxEmpty>
        <ComboboxList>
          {(locale: string) => (
            <ComboboxItem key={locale} value={locale}>
              {labelFor(locale)}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
