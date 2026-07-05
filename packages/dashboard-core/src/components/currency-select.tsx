import {
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { useMemo, useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDisplayName } from '../hooks/use-display-name'
import { useStore } from '../providers/store-provider'

/**
 * Every ISO 4217 currency code the runtime knows about — the active-currency
 * counterpart to the Rails admin's `Money::Currency.table` list. Used for
 * contexts where the merchant can pick *any* currency (a market's currency)
 * rather than one the store already supports. Degrades to an empty list on
 * runtimes without `Intl.supportedValuesOf`, so callers fall back to
 * `supported_currencies`.
 */
export const ALL_CURRENCY_CODES: string[] = (() => {
  try {
    return Intl.supportedValuesOf('currency')
  } catch {
    return []
  }
})()

interface CurrencySelectProps {
  /** ID for the trigger — paired with the parent `<FieldLabel htmlFor>`. */
  id?: string
  /** Submit name — a hidden input mirrors the value so plain `FormData` works. */
  name?: string
  /** Initial selection. Falls back to the store's default currency. */
  defaultValue?: string
  /** Controlled value. Pair with `onChange` to lift state out. */
  value?: string
  /** Fires on every selection change. */
  onChange?: (currency: string) => void
  /**
   * Currency codes to pick from. Defaults to the current store's
   * `supported_currencies`. Pass `ALL_CURRENCY_CODES` (or any custom list) for
   * contexts where the merchant chooses a currency the store doesn't yet
   * support — e.g. a market's currency. Large lists switch to a searchable
   * combobox automatically.
   */
  options?: string[]
  /** Marks the field required for screen readers + native form submission. */
  required?: boolean
  disabled?: boolean
}

/** Above this many options a plain `<Select>` is unwieldy — switch to search. */
const SEARCHABLE_THRESHOLD = 12

/**
 * Picker for a currency code. Defaults to the current store's
 * `supported_currencies` (and the store's `default_currency`), so callers
 * choosing among already-configured currencies don't have to wire anything up.
 * Pass `options` (e.g. `ALL_CURRENCY_CODES`) when the merchant may pick any
 * currency, such as a market's currency. Each option reads `CODE — Full Name`
 * (e.g. `USD — US Dollar`), with the name localized to the admin UI language.
 * Long option lists render a searchable combobox.
 */
export function CurrencySelect({
  id,
  name,
  defaultValue,
  value: controlledValue,
  onChange,
  options,
  required,
  disabled,
}: CurrencySelectProps) {
  const { t } = useTranslation()
  const { currencies, defaultCurrency } = useStore()
  const [internalValue, setInternalValue] = useState(defaultValue ?? defaultCurrency)
  const isControlled = controlledValue !== undefined
  // Controlled callers that pass an empty value still see the store default
  // in the dropdown. Derive it here without emitting onChange — committing the
  // fallback during render dirties forms and re-triggers effects. The caller
  // gets the real value the first time the merchant interacts.
  const value = isControlled ? controlledValue || defaultCurrency : internalValue
  const displayNameFor = useDisplayName('currency')

  // Union of the option list and the current value so editing a record whose
  // currency isn't in the list (a store-supported list that later narrowed)
  // never silently drops the selection. An empty `options` (e.g. a runtime
  // without `Intl.supportedValuesOf` yields an empty `ALL_CURRENCY_CODES`)
  // falls back to the store's currencies rather than an empty picker.
  const items = useMemo(() => {
    const base = options?.length ? options : currencies
    return value && !base.includes(value) ? [value, ...base] : base
  }, [options, currencies, value])

  const handleChange = (next: string) => {
    if (!isControlled) setInternalValue(next)
    onChange?.(next)
  }

  const renderOption = (code: string) => {
    const currencyName = displayNameFor(code)
    // Avoid `USD — USD` when the resolver falls back to the code itself.
    return currencyName && currencyName !== code ? `${code} — ${currencyName}` : code
  }

  // Case-insensitive match against the code and its localized name so typing
  // "EUR" or "Euro" both find it.
  const filter = (code: string, query: string) => {
    const q = query.trim().toLowerCase()
    if (!q) return true
    return code.toLowerCase().includes(q) || renderOption(code).toLowerCase().includes(q)
  }

  const hiddenInput = name ? <input type="hidden" name={name} value={value} /> : null

  if (items.length > SEARCHABLE_THRESHOLD) {
    return (
      <>
        {hiddenInput}
        <Combobox
          items={items}
          value={value}
          onValueChange={(next: string | null) => handleChange(next ?? '')}
          itemToStringLabel={(code: string | null) => (code ? renderOption(code) : '')}
          itemToStringValue={(code: string | null) => code ?? ''}
          filter={filter}
          disabled={disabled}
        >
          <ComboboxInput
            id={id}
            aria-required={required}
            placeholder={t('admin.components.currency_select.placeholder')}
            disabled={disabled}
          />
          <ComboboxContent>
            <ComboboxEmpty>{t('admin.components.currency_select.empty')}</ComboboxEmpty>
            <ComboboxList>
              {(code: string) => (
                <ComboboxItem key={code} value={code}>
                  {renderOption(code)}
                </ComboboxItem>
              )}
            </ComboboxList>
          </ComboboxContent>
        </Combobox>
      </>
    )
  }

  return (
    <>
      {/* Hidden input keeps the parent `<form>` submit / FormData path working
          without each caller having to thread the value through state. */}
      {hiddenInput}
      <Select value={value} onValueChange={handleChange} disabled={disabled}>
        <SelectTrigger id={id} aria-required={required}>
          {/* Base UI's `<SelectValue>` defaults to rendering the raw `value`
              (the bare ISO code). Use the children render-prop so the
              trigger shows the same `CODE — Full Name` as the items. */}
          <SelectValue placeholder={t('admin.components.currency_select.placeholder')}>
            {(v) => (v ? renderOption(v as string) : (v as string))}
          </SelectValue>
        </SelectTrigger>
        <SelectContent>
          {items.map((currency) => (
            <SelectItem key={currency} value={currency}>
              {renderOption(currency)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </>
  )
}
