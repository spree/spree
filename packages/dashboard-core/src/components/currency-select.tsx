import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useTranslation } from 'react-i18next'
import { useDisplayName } from '../hooks/use-display-name'
import { useStore } from '../providers/store-provider'

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
  /** Marks the field required for screen readers + native form submission. */
  required?: boolean
  disabled?: boolean
}

/**
 * Picker for one of the current store's `supported_currencies`. Defaults to
 * the store's `default_currency` so callers don't have to wire it up
 * themselves. Each option reads `CODE — Full Name` (e.g.
 * `USD — US Dollar`), with the name localized to the admin UI language. Use
 * this anywhere the merchant is choosing a currency for an admin-side action
 * (issuing store credit, recording a refund, manual money entry on an
 * order, etc.).
 */
export function CurrencySelect({
  id,
  name,
  defaultValue,
  value: controlledValue,
  onChange,
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

  const handleChange = (next: string) => {
    if (!isControlled) setInternalValue(next)
    onChange?.(next)
  }

  const renderOption = (code: string) => {
    const name = displayNameFor(code)
    // Avoid `USD — USD` when the resolver falls back to the code itself.
    return name && name !== code ? `${code} — ${name}` : code
  }

  return (
    <>
      {/* Hidden input keeps the parent `<form>` submit / FormData path working
          without each caller having to thread the value through state. */}
      {name && <input type="hidden" name={name} value={value} />}
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
          {currencies.map((currency) => (
            <SelectItem key={currency} value={currency}>
              {renderOption(currency)}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </>
  )
}
