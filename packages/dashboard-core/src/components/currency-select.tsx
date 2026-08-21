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
   * support — e.g. a market's currency.
   */
  options?: string[]
  /**
   * Announces the field as required to screen readers. Enforcement is the
   * form's job — every caller validates through react-hook-form, and the
   * button trigger is not a form-associated control, so this never blocks a
   * submit on its own.
   */
  required?: boolean
  disabled?: boolean
  /** Text in the dropdown's search box. */
  searchPlaceholder?: string
  invalid?: boolean
  /** Forwarded to the trigger so RHF's `<Controller>` can track touched state. */
  onBlur?: () => void
}

/**
 * Picker for a currency code. Defaults to the current store's
 * `supported_currencies` (and the store's `default_currency`), so callers
 * choosing among already-configured currencies don't have to wire anything up.
 * Pass `options` (e.g. `ALL_CURRENCY_CODES`) when the merchant may pick any
 * currency, such as a market's currency. Each option reads `CODE — Full Name`
 * (e.g. `USD — US Dollar`), with the name localized to the admin UI language.
 *
 * Always searchable, whatever the list length. The picker used to fall back to
 * a plain `<Select>` under a dozen options, which meant the same field behaved
 * differently from one store to the next — typing to filter worked on a store
 * with many currencies and did nothing on a store with three.
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
  searchPlaceholder,
  invalid,
  onBlur,
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

  return (
    <>
      {/* Hidden input keeps the parent `<form>` submit / FormData path working
          without each caller having to thread the value through state. */}
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
        <ComboboxButtonTrigger
          id={id}
          onBlur={onBlur}
          disabled={disabled}
          aria-required={required}
          aria-invalid={invalid || undefined}
        >
          {value ? (
            <span className="truncate">{renderOption(value)}</span>
          ) : (
            <ComboboxTriggerPlaceholder>
              {t('admin.components.currency_select.placeholder')}
            </ComboboxTriggerPlaceholder>
          )}
        </ComboboxButtonTrigger>
        <ComboboxContent>
          <ComboboxSearch
            placeholder={
              searchPlaceholder ?? t('admin.components.currency_select.search_placeholder')
            }
          />
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
