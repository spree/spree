import { useMemo, useState } from 'react'
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select'
import { useStore } from '@/providers/store-provider'

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
 * Resolves a currency code (`USD`) to its localized display name (`United
 * States Dollar`) via the browser's built-in `Intl.DisplayNames`. Falls
 * back to the code itself when the runtime lacks coverage (very old
 * browsers, exotic codes) so the user always sees something.
 */
function useCurrencyDisplayName(locale: string) {
  return useMemo(() => {
    try {
      const formatter = new Intl.DisplayNames([locale, 'en'], { type: 'currency' })
      return (code: string) => formatter.of(code) ?? code
    } catch {
      return (code: string) => code
    }
  }, [locale])
}

/**
 * Picker for one of the current store's `supported_currencies`. Defaults to
 * the store's `default_currency` so callers don't have to wire it up
 * themselves. Each option reads `CODE — Full Name` (e.g.
 * `USD — United States Dollar`), localized via the browser's
 * `Intl.DisplayNames` against the store's `default_locale`. Use this
 * anywhere the merchant is choosing a currency for an admin-side action
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
  const { currencies, defaultCurrency, defaultLocale } = useStore()
  const [internalValue, setInternalValue] = useState(defaultValue ?? defaultCurrency)
  const isControlled = controlledValue !== undefined
  const value = isControlled ? controlledValue : internalValue
  const displayNameFor = useCurrencyDisplayName(defaultLocale)

  const handleChange = (next: string) => {
    if (!isControlled) setInternalValue(next)
    onChange?.(next)
  }

  const renderOption = (code: string) => {
    const name = displayNameFor(code)
    return name === code ? code : `${code} — ${name}`
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
          <SelectValue placeholder="Select a currency">
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
