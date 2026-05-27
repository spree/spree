import { useMemo, useState } from 'react'
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
} from '@/components/ui/combobox'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useTranslation } from '@/lib/i18n'
import { useStore } from '@/providers/store-provider'

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
 * Resolves a locale code (`en`, `pt-BR`) to its localized display name
 * (`English`, `Portuguese (Brazil)`) via the browser's built-in
 * `Intl.DisplayNames`. Falls back to the code itself when the runtime
 * lacks coverage so the user always sees something.
 */
function useLocaleDisplayName(displayLocale: string) {
  return useMemo(() => {
    try {
      const formatter = new Intl.DisplayNames([displayLocale, 'en'], { type: 'language' })
      return (code: string) => formatter.of(code) ?? code
    } catch {
      return (code: string) => code
    }
  }, [displayLocale])
}

/** Mirrors `CurrencySelect`'s row format: `CODE — Localized Name`. */
function formatOption(code: string, name: string) {
  const upper = code.toUpperCase()
  return name === code ? upper : `${upper} — ${name}`
}

/**
 * Static text label for a locale code: `EN — English`. Use this in tables
 * and read-only contexts where the picker isn't needed but the same
 * formatting is. Falls back to the upper-cased code when `Intl.DisplayNames`
 * has no entry.
 */
export function LocaleLabel({ code }: { code: string }) {
  const { defaultLocale } = useStore()
  const displayNameFor = useLocaleDisplayName(defaultLocale)
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
  const { locales: storeLocales, defaultLocale } = useStore()
  const displayNameFor = useLocaleDisplayName(defaultLocale)

  // Union of `props.options` (everything the picker should show) and the
  // currently selected values — so editing an existing record doesn't
  // silently drop chips when the store's locale list later narrows.
  const items = useMemo(() => {
    const base = props.options ?? storeLocales
    const selected = props.multiple ? props.value : props.value ? [props.value] : []
    const merged = Array.from(new Set([...base, ...selected]))
    return props.excludeCode ? merged.filter((l) => l !== props.excludeCode) : merged
  }, [props.options, props.excludeCode, props.multiple, props.value, storeLocales])

  if (props.multiple) {
    return (
      <MultiLocalePicker
        id={props.id}
        items={items}
        value={props.value}
        onChange={props.onChange}
        displayNameFor={displayNameFor}
        placeholder={props.placeholder ?? t('admin.components.locale_select.multi_placeholder')}
        emptyText={t('admin.components.locale_select.empty')}
        disabled={props.disabled}
      />
    )
  }

  const value = props.value ?? ''
  return (
    <Select value={value} onValueChange={props.onChange} disabled={props.disabled}>
      <SelectTrigger id={props.id} aria-required={props.required}>
        {/* Base UI's `<SelectValue>` defaults to the raw locale code. Use
            the children render-prop so the trigger shows the same
            `CODE — Name` as the items. */}
        <SelectValue
          placeholder={props.placeholder ?? t('admin.components.locale_select.placeholder')}
        >
          {(v) => (v ? formatOption(v as string, displayNameFor(v as string)) : (v as string))}
        </SelectValue>
      </SelectTrigger>
      <SelectContent>
        {items.map((locale) => (
          <SelectItem key={locale} value={locale}>
            {formatOption(locale, displayNameFor(locale))}
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
  displayNameFor,
  placeholder,
  emptyText,
  disabled,
}: {
  id?: string
  items: string[]
  value: string[]
  onChange: (locales: string[]) => void
  displayNameFor: (code: string) => string
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
      disabled={disabled}
    >
      <ComboboxChips ref={anchorRef}>
        <ComboboxValue>
          {(selectedLocales: string[]) =>
            selectedLocales.map((l) => (
              <ComboboxChip key={l}>{formatOption(l, displayNameFor(l))}</ComboboxChip>
            ))
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
              {formatOption(locale, displayNameFor(locale))}
            </ComboboxItem>
          )}
        </ComboboxList>
      </ComboboxContent>
    </Combobox>
  )
}
