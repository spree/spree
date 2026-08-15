import { zodResolver } from '@hookform/resolvers/zod'
import type { SetupCountry, SpreeError } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, useAuth, useDisplayName } from '@spree/dashboard-core'
import {
  Button,
  Combobox,
  ComboboxContent,
  ComboboxEmpty,
  ComboboxInput,
  ComboboxItem,
  ComboboxList,
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
 * The merchant's own region, read from the browser's locale — a better
 * opening guess than any single hardcoded country. Falls back to the US,
 * which is where the seeded defaults pointed before setup asked.
 */
function guessCountryCode(): string {
  try {
    const locale = new Intl.Locale(navigator.language)
    // `maximize()` turns "de" into "de-Latn-DE", so a bare language still
    // yields a region.
    return locale.maximize().region ?? 'US'
  } catch {
    return 'US'
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
  // the answer. The country's own language wins, and English remains one
  // click away in the dropdown.
  const handleCountryChange = useCallback(
    (code: string) => {
      form.setValue('country_code', code, { shouldValidate: true })

      const country = countries.find((candidate) => candidate.code === code)
      form.setValue('locale', country?.locales[0] ?? 'en')
    },
    [countries, form],
  )

  // The store most likely sells from wherever it is being set up, so the
  // browser's own region is a better opening guess than an empty box. Applied
  // once, and only while the merchant hasn't touched the field.
  const suggestedCountry = useMemo(() => guessCountryCode(), [])
  useEffect(() => {
    if (countries.length === 0) return
    if (form.getValues('country_code')) return
    if (!countries.some((country) => country.code === suggestedCountry)) return

    handleCountryChange(suggestedCountry)
  }, [countries, suggestedCountry, handleCountryChange, form])

  const onSubmit = async (data: SetupFormValues) => {
    try {
      await completeSetup({ ...data, setup_token: token })
      navigate({ to: '/', replace: true })
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
      <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
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
        <div className="grid gap-2">
          <Label htmlFor="country_code">{t('admin.fields.setup.country_code.label')}</Label>
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
                <ComboboxInput
                  id="country_code"
                  onBlur={field.onBlur}
                  aria-invalid={!!errors.country_code || undefined}
                  placeholder={t('admin.fields.setup.country_code.placeholder')}
                />
                <ComboboxContent>
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
          <p className="text-xs text-muted-foreground">
            {t('admin.fields.setup.country_code.help')}
          </p>
          {errors.country_code && (
            <p className="text-sm text-destructive">{errors.country_code.message}</p>
          )}
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div className="grid gap-2">
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
          </div>
          <div className="grid gap-2">
            <Label>{t('admin.fields.setup.currency.label')}</Label>
            {/* Derived, never typed: the currency a country uses is a fact
                about the country, and showing it here stops a merchant in
                Switzerland assuming they are getting euros. */}
            <div className="flex h-9 items-center rounded-md border border-input bg-muted px-3 text-sm text-muted-foreground">
              {selectedCountry?.currency ?? t('admin.fields.setup.currency.placeholder')}
            </div>
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
