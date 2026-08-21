import { zodResolver } from '@hookform/resolvers/zod'
import type { SetupCountry, SpreeError } from '@spree/admin-sdk'
import {
  ALL_CURRENCY_CODES,
  adminClient,
  mapSpreeErrorsToForm,
  useAuth,
  useDisplayName,
} from '@spree/dashboard-core'
import {
  Button,
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
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link, Navigate, useNavigate } from '@tanstack/react-router'
import { useCallback, useEffect, useMemo } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { AuthShell } from '../components/spree/auth-shell'
import { type SetupFormValues, setupFormSchema } from '../schemas/auth'

const setupSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/setup')({
  validateSearch: setupSearchSchema,
  component: SetupPage,
})

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

function SetupPage() {
  const { t } = useTranslation()
  const { token } = Route.useSearch()
  const { isAuthenticated } = useAuth()

  if (isAuthenticated) return <Navigate to="/" replace />

  if (!token) {
    return (
      <AuthShell>
        <SetupUnavailable
          title={t('admin.setup.missing_token_title')}
          message={t('admin.setup.missing_token_message')}
        />
      </AuthShell>
    )
  }

  return (
    <AuthShell>
      <SetupLoader token={token} />
    </AuthShell>
  )
}

function SetupLoader({ token }: { token: string }) {
  const { t } = useTranslation()
  const status = useQuery({
    queryKey: ['setup-status'],
    queryFn: () => adminClient.auth.setupStatus(),
    retry: false,
    // Availability flips exactly once, and a cached `true` would re-render
    // the form after setup completed (browser back, or the login page's
    // link) — a form that can no longer succeed. Always ask.
    gcTime: 0,
    staleTime: 0,
    refetchOnMount: 'always',
  })

  if (status.isPending) {
    return <div className="py-12 text-center text-muted-foreground">{t('admin.setup.loading')}</div>
  }

  if (status.isError || !status.data?.setup_required) {
    return (
      <SetupUnavailable
        title={t('admin.setup.not_available_title')}
        message={t('admin.setup.not_available_message')}
      />
    )
  }

  return <SetupForm token={token} />
}

function SetupForm({ token }: { token: string }) {
  const { t } = useTranslation()
  const { completeSetup, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<SetupFormValues>({
    resolver: zodResolver(setupFormSchema),
    defaultValues: {
      email: '',
      first_name: '',
      last_name: '',
      password: '',
      password_confirmation: '',
      store_name: '',
      country_code: '',
      locale: 'en',
      currency: 'USD',
    },
  })
  const { errors } = form.formState

  // Unauthenticated: setup runs before any credential exists, so this cannot
  // use the authenticated countries endpoint the rest of the app uses.
  const countriesQuery = useQuery({
    queryKey: ['setup-countries'],
    queryFn: () => adminClient.auth.setupCountries(),
    retry: false,
    staleTime: Number.POSITIVE_INFINITY,
  })
  const countries = countriesQuery.data?.countries ?? []

  const languageName = useDisplayName('language')
  const currencyLabel = useCurrencyLabel()
  const countryCode = form.watch('country_code')
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
      form.setValue('country_code', code, { shouldValidate: true })

      const country = countries.find((candidate) => candidate.code === code)
      form.setValue('locale', country?.locales[0] ?? 'en')
      form.setValue('currency', country?.currency ?? 'USD', { shouldValidate: true })
    },
    [countries, form],
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
    if (form.getValues('country_code')) return
    if (!countries.some((country) => country.code === suggestedCountry)) return

    handleCountryChange(suggestedCountry)
  }, [countries, suggestedCountry, handleCountryChange, form])

  const onSubmit = async (data: SetupFormValues) => {
    try {
      const session = await completeSetup({ ...data, setup_token: token })

      // A merchant who has just claimed the installation has an empty store,
      // so the checklist is the useful landing place rather than a dashboard
      // of zeroes. Falls back to the index redirect if the payload carries no
      // store, which resolves one for itself.
      const storeId = session.user?.stores?.[0]?.id
      if (storeId) {
        navigate({
          to: '/$storeId/getting-started',
          params: { storeId },
          replace: true,
        })
      } else {
        navigate({ to: '/', replace: true })
      }
    } catch (err) {
      const e = err as SpreeError
      if (e?.status === 404) {
        form.setError('root', { message: t('admin.setup.not_available_message') })
        return
      }
      if (!mapSpreeErrorsToForm(err, form.setError)) {
        form.setError('root', { message: e?.message || t('admin.setup.could_not_complete') })
      }
    }
  }

  return (
    <>
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-bold">{t('admin.setup.title')}</h1>
        <p className="text-sm text-muted-foreground">{t('admin.setup.subtitle')}</p>
      </div>
      {/* Chrome ignores `autocomplete="off"` on a field it has decided is part
          of an address form — which is what it made of the country box, and it
          covered our own list with saved addresses. On the form element it is
          honoured. Nothing is lost here: this screen creates an account that
          does not exist yet, so there is nothing useful to autofill. */}
      <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6" autoComplete="off">
        {errors.root && <p className="text-sm text-destructive">{errors.root.message}</p>}
        <div className="grid gap-2">
          <Label htmlFor="store_name">{t('admin.fields.setup.store_name.label')}</Label>
          <Input
            id="store_name"
            autoFocus
            aria-invalid={!!errors.store_name || undefined}
            {...form.register('store_name')}
          />
          {errors.store_name && (
            <p className="text-sm text-destructive">{errors.store_name.message}</p>
          )}
        </div>
        {/* Setup cannot be completed without this list, so a failed request
            needs saying out loud and a way back — otherwise the country box
            is simply empty and the merchant is stuck with no explanation. */}
        {countriesQuery.isError && (
          <div className="flex items-center justify-between gap-3 rounded-lg border border-destructive/50 px-3 py-2">
            <p className="text-sm text-destructive">{t('admin.setup.countries_failed')}</p>
            <Button
              type="button"
              variant="outline"
              size="sm"
              onClick={() => countriesQuery.refetch()}
              disabled={countriesQuery.isFetching}
            >
              {t('admin.common.retry')}
            </Button>
          </div>
        )}
        <div className="grid gap-2">
          <Label htmlFor="setup-country-search">{t('admin.fields.setup.country_code.label')}</Label>
          <Controller
            name="country_code"
            control={form.control}
            render={({ field }) => (
              <Combobox
                items={countries}
                value={selectedCountry}
                onValueChange={(country: SetupCountry | null) =>
                  handleCountryChange(country?.code ?? '')
                }
                itemToStringLabel={(country: SetupCountry | null) => country?.name ?? ''}
                itemToStringValue={(country: SetupCountry | null) => country?.code ?? ''}
                disabled={countriesQuery.isPending}
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
              control={form.control}
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
              control={form.control}
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
              <p className="text-xs text-muted-foreground">
                {t('admin.fields.setup.currency.help')}
              </p>
            )}
          </div>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="grid gap-2">
            <Label htmlFor="first_name">{t('admin.fields.first_name.label')}</Label>
            <Input
              id="first_name"
              aria-invalid={!!errors.first_name || undefined}
              {...form.register('first_name')}
            />
            {errors.first_name && (
              <p className="text-sm text-destructive">{errors.first_name.message}</p>
            )}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="last_name">{t('admin.fields.last_name.label')}</Label>
            <Input
              id="last_name"
              aria-invalid={!!errors.last_name || undefined}
              {...form.register('last_name')}
            />
            {errors.last_name && (
              <p className="text-sm text-destructive">{errors.last_name.message}</p>
            )}
          </div>
        </div>
        <div className="grid gap-2">
          <Label htmlFor="email">{t('admin.fields.email.label')}</Label>
          <Input
            id="email"
            type="email"
            aria-invalid={!!errors.email || undefined}
            {...form.register('email')}
          />
          {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
        </div>
        <div className="grid gap-2">
          <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
          <Input
            id="password"
            type="password"
            aria-invalid={!!errors.password || undefined}
            {...form.register('password')}
          />
          {errors.password && <p className="text-sm text-destructive">{errors.password.message}</p>}
        </div>
        <div className="grid gap-2">
          <Label htmlFor="password_confirmation">
            {t('admin.fields.setup.password_confirmation.label')}
          </Label>
          <Input
            id="password_confirmation"
            type="password"
            aria-invalid={!!errors.password_confirmation || undefined}
            {...form.register('password_confirmation')}
          />
          {errors.password_confirmation && (
            <p className="text-sm text-destructive">{errors.password_confirmation.message}</p>
          )}
        </div>
        <Button type="submit" className="w-full" disabled={isLoading}>
          {isLoading ? t('admin.setup.completing') : t('admin.setup.complete')}
        </Button>
      </form>
    </>
  )
}

function SetupUnavailable({ title, message }: { title: string; message: string }) {
  const { t } = useTranslation()

  return (
    <div className="flex flex-col gap-2">
      <h1 className="text-2xl font-bold">{title}</h1>
      <p className="text-sm text-muted-foreground">{message}</p>
      <p className="text-sm text-muted-foreground">
        <Link to="/login" className="underline underline-offset-4">
          {t('admin.setup.back_to_login')}
        </Link>
      </p>
    </div>
  )
}
