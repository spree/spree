import type { SetupCountry } from '@spree/admin-sdk'
// Barrel imports only. Deep imports here (`@spree/dashboard-ui/ui/select` and
// friends) make Vite prebundle each subpath as its own dependency in an
// installed app, which leaves Base UI's CommonJS shim unconverted and stops
// the dashboard from starting. The monorepo cannot show this: its workspace
// links are treated as source.
import { ALL_CURRENCY_CODES, useDisplayName } from '@spree/dashboard-core'
import {
  Combobox,
  ComboboxButtonTrigger,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxItem,
  ComboboxList,
  ComboboxSearch,
  ComboboxTriggerPlaceholder,
  CountryFlag,
  Input,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@spree/dashboard-ui'
import { useCallback, useEffect, useMemo } from 'react'
import { Controller, type FieldErrors, type UseFormReturn } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

/**
 * Enough of ISO 4217 to stay useful on runtimes without
 * `Intl.supportedValuesOf` — the country's own currency is prepended to
 * whichever list is used, so the recommendation is never missing.
 */
const FALLBACK_CURRENCY_CODES = [
  'USD',
  'EUR',
  'GBP',
  'CHF',
  'PLN',
  'SEK',
  'NOK',
  'DKK',
  'CZK',
  'RON',
  'CAD',
  'AUD',
  'NZD',
  'JPY',
  'CNY',
  'HKD',
  'SGD',
  'INR',
  'BRL',
  'MXN',
  'ZAR',
  'AED',
  'TRY',
  'ILS',
  'KRW',
]

/** `PLN — Polish Zloty`, with the name in the admin UI language. */
function useCurrencyLabel() {
  const currencyName = useDisplayName('currency')
  return useCallback(
    (code: string) => {
      const name = currencyName(code)
      return name && name !== code ? `${code} — ${name}` : code
    },
    [currencyName],
  )
}

/**
 * The merchant's own region, when the browser actually states one (`en-GB`,
 * `pl-PL`). Only an explicit region counts: `Intl` will happily maximize a
 * bare `en` to `en-Latn-US`, which would prefill "United States" as though the
 * merchant had chosen it and quietly provision a US store. Undefined leaves
 * the field empty, and the form requires an answer.
 */
function guessCountryCode(): string | undefined {
  try {
    return new Intl.Locale(navigator.language).region ?? undefined
  } catch {
    return undefined
  }
}

/** The four answers that shape a store, whatever flow is asking for them. */
export interface StoreSetupValues {
  store_name: string
  country_code: string
  locale: string
  currency: string
}

export interface StoreSetupFieldsProps<Values extends StoreSetupValues> {
  form: UseFormReturn<Values>
  /** Countries the store may be set up in, with their own currency and languages. */
  countries: SetupCountry[]
  /** Renders a retry affordance when the list could not be loaded. */
  countriesPending?: boolean
}

/**
 * Store name, country, currency and language — the step every flow that
 * creates a store shares: first-run setup on a self-hosted install, and the
 * hosted signup funnel, which asks the same four questions after the account
 * exists.
 *
 * Headless about submission: the caller owns the form, the countries query
 * and what happens on submit, because those differ between the flows.
 */
export function StoreSetupFields<Values extends StoreSetupValues>({
  form,
  countries,
  countriesPending = false,
}: StoreSetupFieldsProps<Values>) {
  const { t } = useTranslation()
  // The generic form's errors are keyed by the caller's value type; these four
  // fields are guaranteed present by the StoreSetupValues constraint.
  const errors = form.formState.errors as FieldErrors<StoreSetupValues>
  const control = form.control as unknown as UseFormReturn<StoreSetupValues>['control']
  const register = form.register as unknown as UseFormReturn<StoreSetupValues>['register']
  const setValue = form.setValue as unknown as UseFormReturn<StoreSetupValues>['setValue']
  const getValues = form.getValues as unknown as UseFormReturn<StoreSetupValues>['getValues']
  const watch = form.watch as unknown as UseFormReturn<StoreSetupValues>['watch']

  const languageName = useDisplayName('language')
  const currencyLabel = useCurrencyLabel()
  const countryCode = watch('country_code')
  const selectedCountry = useMemo(
    () => countries.find((country) => country.code === countryCode) ?? null,
    [countries, countryCode],
  )

  // English stays on the list so an English-speaking merchant running a store
  // in Warsaw isn't forced into Polish.
  const localeOptions = useMemo(() => {
    const codes = [...(selectedCountry?.locales ?? []), 'en']
    return Array.from(new Set(codes))
  }, [selectedCountry])

  // Both the currency and the language follow the country: having just said
  // the store is in Poland, being left on English reads as the form ignoring
  // the answer. The country's own language and currency win, and both stay
  // editable — plenty of Polish merchants price in euros.
  const handleCountryChange = useCallback(
    (code: string) => {
      setValue('country_code', code, { shouldValidate: true })

      const country = countries.find((candidate) => candidate.code === code)
      setValue('locale', country?.locales[0] ?? 'en')
      setValue('currency', country?.currency ?? 'USD', { shouldValidate: true })
    },
    [countries, setValue],
  )

  // The country's own currency leads the list; the rest of ISO 4217 follows so
  // pricing in a currency other than the local one is one scroll away.
  const currencyOptions = useMemo(() => {
    const recommended = selectedCountry?.currency
    const all = ALL_CURRENCY_CODES.length > 0 ? ALL_CURRENCY_CODES : FALLBACK_CURRENCY_CODES
    return recommended ? [recommended, ...all.filter((code) => code !== recommended)] : all
  }, [selectedCountry])

  // The store most likely sells from wherever it is being set up, so a region
  // the browser names outright is a better opening guess than an empty box.
  // Applied once, and only while the merchant hasn't touched the field.
  const suggestedCountry = useMemo(() => guessCountryCode(), [])
  useEffect(() => {
    if (!suggestedCountry) return
    if (countries.length === 0) return
    if (getValues('country_code')) return
    if (!countries.some((country) => country.code === suggestedCountry)) return

    handleCountryChange(suggestedCountry)
  }, [countries, suggestedCountry, handleCountryChange, getValues])

  return (
    <>
      <div className="grid gap-2">
        <Label htmlFor="store_name">{t('admin.fields.setup.store_name.label')}</Label>
        <Input
          id="store_name"
          autoFocus
          aria-invalid={!!errors.store_name || undefined}
          {...register('store_name')}
        />
        {errors.store_name && (
          <p className="text-sm text-destructive">{errors.store_name.message}</p>
        )}
      </div>
      <div className="grid gap-2">
        <Label htmlFor="setup-country-search">{t('admin.fields.setup.country_code.label')}</Label>
        <Controller
          name="country_code"
          control={control}
          render={({ field }) => (
            <Combobox
              items={countries}
              value={selectedCountry}
              onValueChange={(country: SetupCountry | null) =>
                handleCountryChange(country?.code ?? '')
              }
              itemToStringLabel={(country: SetupCountry | null) => country?.name ?? ''}
              itemToStringValue={(country: SetupCountry | null) => country?.code ?? ''}
              disabled={countriesPending}
            >
              <ComboboxButtonTrigger
                id="setup-country-search"
                onBlur={field.onBlur}
                aria-invalid={!!errors.country_code || undefined}
              >
                {selectedCountry ? (
                  <>
                    <CountryFlag iso={selectedCountry.code} />
                    <span className="truncate">{selectedCountry.name}</span>
                  </>
                ) : (
                  <ComboboxTriggerPlaceholder>
                    {t('admin.fields.setup.country_code.placeholder')}
                  </ComboboxTriggerPlaceholder>
                )}
              </ComboboxButtonTrigger>
              <ComboboxContent>
                <ComboboxSearch placeholder={t('admin.fields.setup.country_code.placeholder')} />
                <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                <ComboboxList>
                  {(country: SetupCountry) => (
                    <ComboboxItem key={country.code} value={country}>
                      <span className="flex items-center gap-2">
                        <CountryFlag iso={country.code} />
                        {country.name}
                      </span>
                    </ComboboxItem>
                  )}
                </ComboboxList>
              </ComboboxContent>
            </Combobox>
          )}
        />
        {errors.country_code ? (
          <p className="text-sm text-destructive">{errors.country_code.message}</p>
        ) : (
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.setup.country_code.help')}
          </p>
        )}
      </div>
      {/* `grid-rows-subgrid` keeps the label, control and help of both
          columns on the same three lines, so help text that wraps to a
          different number of lines can't stagger the fields. */}
      <div className="grid grid-cols-2 grid-rows-[auto_auto_auto] gap-x-3 gap-y-0">
        <div className="grid grid-rows-subgrid row-span-3 gap-2">
          <Label htmlFor="locale">{t('admin.fields.setup.locale.label')}</Label>
          <Controller
            name="locale"
            control={control}
            render={({ field }) => (
              <Select value={field.value} onValueChange={field.onChange}>
                <SelectTrigger id="locale">
                  <SelectValue>
                    {(value) => languageName(value as string) ?? (value as string)}
                  </SelectValue>
                </SelectTrigger>
                <SelectContent>
                  {localeOptions.map((code) => (
                    <SelectItem key={code} value={code}>
                      {languageName(code) ?? code}
                    </SelectItem>
                  ))}
                </SelectContent>
              </Select>
            )}
          />
          <p className="text-xs text-muted-foreground">{t('admin.fields.setup.locale.help')}</p>
        </div>
        <div className="grid grid-rows-subgrid row-span-3 gap-2">
          <Label htmlFor="setup-currency-search">{t('admin.fields.setup.currency.label')}</Label>
          {/* The country's own currency leads the list and is preselected,
              but the merchant can override it — shipping from Warsaw and
              pricing in euros is an ordinary thing to want. */}
          <Controller
            name="currency"
            control={control}
            render={({ field }) => (
              <Combobox
                items={currencyOptions}
                value={field.value}
                onValueChange={(code: string | null) => field.onChange(code ?? '')}
                itemToStringLabel={(code: string | null) => (code ? currencyLabel(code) : '')}
                itemToStringValue={(code: string | null) => code ?? ''}
              >
                {/* Same shape as the country field, so the two read as one
                    pair of fields. */}
                <ComboboxButtonTrigger
                  id="setup-currency-search"
                  onBlur={field.onBlur}
                  aria-invalid={!!errors.currency || undefined}
                >
                  {field.value ? (
                    <span className="truncate">{currencyLabel(field.value)}</span>
                  ) : (
                    <ComboboxTriggerPlaceholder>
                      {t('admin.fields.setup.currency.placeholder')}
                    </ComboboxTriggerPlaceholder>
                  )}
                </ComboboxButtonTrigger>
                <ComboboxContent>
                  <ComboboxSearch placeholder={t('admin.fields.setup.currency.placeholder')} />
                  <ComboboxEmpty>{t('admin.common.no_results')}</ComboboxEmpty>
                  <ComboboxList>
                    {(code: string) => (
                      <ComboboxItem key={code} value={code}>
                        {currencyLabel(code)}
                      </ComboboxItem>
                    )}
                  </ComboboxList>
                </ComboboxContent>
              </Combobox>
            )}
          />
          {/* Error replaces the help rather than joining it, so the column
              keeps exactly the three rows the subgrid expects. */}
          {errors.currency ? (
            <p className="text-sm text-destructive">{errors.currency.message}</p>
          ) : (
            <p className="text-xs text-muted-foreground">{t('admin.fields.setup.currency.help')}</p>
          )}
        </div>
      </div>
    </>
  )
}
