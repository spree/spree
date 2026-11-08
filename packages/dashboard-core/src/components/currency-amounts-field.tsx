import { currencyParts, isCurrencyCode } from '@spree/core'
import {
  Field,
  FieldError,
  FieldLabel,
  InputGroup,
  InputGroupAddon,
  InputGroupInput,
  InputGroupText,
} from '@spree/dashboard-ui'
import { useMemo } from 'react'
import { useTranslation } from 'react-i18next'
import { amountForCurrency, applyCurrencyAmount } from '../lib/currency-amounts'

/**
 * The amount an amount-based delivery calculator charges, one input per
 * currency the store sells in, written to the per-currency `amounts`
 * preference. A currency left blank has no amount, and the method is not
 * offered to those carts. A single-currency store sees one plain amount
 * field.
 */
export function CurrencyAmountsField({
  values,
  onChange,
  currencies,
  defaultCurrency,
  error,
}: {
  values: Record<string, unknown>
  onChange: (next: Record<string, unknown>) => void
  /** The currencies the store sells in. */
  currencies: readonly string[]
  defaultCurrency: string
  error?: { message?: string }
}) {
  const { t, i18n } = useTranslation()

  // The store's currency list is the source of truth, but a method may already
  // carry an amount in a currency the store has since stopped selling in —
  // dropping that input would silently discard the amount on the next save.
  const amounts = (values.amounts ?? {}) as Record<string, unknown>
  const extraCodes = Object.keys(amounts).join(',')
  const codes = useMemo(() => {
    const supported = currencies.length > 0 ? currencies : [defaultCurrency]
    const extra = extraCodes
      .split(',')
      .filter(isCurrencyCode)
      .filter((code) => !supported.includes(code))
    return [defaultCurrency, ...supported.filter((code) => code !== defaultCurrency), ...extra]
  }, [currencies, defaultCurrency, extraCodes])

  const multiCurrency = codes.length > 1

  function amountFor(code: string): string {
    const raw = amountForCurrency(values, code, defaultCurrency)
    return raw === null ? '' : String(raw)
  }

  return (
    <Field>
      <FieldLabel htmlFor={`calculator-amount-${defaultCurrency}`}>
        {t('admin.currency_amounts.label')}
      </FieldLabel>
      <div className="flex flex-col gap-2">
        {codes.map((code) => (
          <InputGroup key={code}>
            <InputGroupAddon>
              <InputGroupText>{currencyParts(code, i18n.language).symbol}</InputGroupText>
            </InputGroupAddon>
            <InputGroupInput
              id={`calculator-amount-${code}`}
              type="number"
              step="any"
              min="0"
              aria-label={t('admin.currency_amounts.amount_in_currency', { currency: code })}
              value={amountFor(code)}
              onChange={(event) =>
                onChange(applyCurrencyAmount(values, code, event.target.value, defaultCurrency))
              }
            />
            <InputGroupAddon align="inline-end">
              <InputGroupText>{code}</InputGroupText>
            </InputGroupAddon>
          </InputGroup>
        ))}
      </div>
      {multiCurrency && (
        <span className="text-muted-foreground text-xs">{t('admin.currency_amounts.help')}</span>
      )}
      <FieldError errors={[error]} />
    </Field>
  )
}
