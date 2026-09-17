import { zodResolver } from '@hookform/resolvers/zod'
import type { SpreeError } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, useAuth } from '@spree/dashboard-core'
import { Button, Checkbox, Input, Label, toastManager } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link, Navigate } from '@tanstack/react-router'
import { useState } from 'react'
import { Controller, useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { AuthShell } from '../components/spree/auth-shell'
import { StoreSetupFields } from '../components/spree/store-setup-fields'
import { type SetupFormValues, setupFormSchema } from '../schemas/auth'

const setupSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/setup')({
  validateSearch: setupSearchSchema,
  component: SetupPage,
})

function SetupPage() {
  const { t } = useTranslation()
  const { token } = Route.useSearch()
  const { isAuthenticated } = useAuth()
  // Completing setup signs the merchant in, which re-renders this component
  // with `isAuthenticated` true. The guard below would then send them to the
  // store index — so the store setup just claimed is held here and the guard
  // routes to its checklist instead.
  const [setupStoreId, setSetupStoreId] = useState<string | null>(null)

  if (setupStoreId) {
    return <Navigate to="/$storeId/getting-started" params={{ storeId: setupStoreId }} replace />
  }

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
      <SetupLoader token={token} onCompleted={setSetupStoreId} />
    </AuthShell>
  )
}

function SetupLoader({
  token,
  onCompleted,
}: {
  token: string
  onCompleted: (storeId: string | null) => void
}) {
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

  return <SetupForm token={token} onCompleted={onCompleted} />
}

function SetupForm({
  token,
  onCompleted,
}: {
  token: string
  onCompleted: (storeId: string | null) => void
}) {
  const { t } = useTranslation()
  const { completeSetup, isLoading } = useAuth()

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
      sample_data: true,
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

  const onSubmit = async (data: SetupFormValues) => {
    try {
      const session = await completeSetup({ ...data, setup_token: token })
      const store = session.user?.stores?.[0]

      toastManager.add({
        type: 'success',
        title: t('admin.setup.welcome_title'),
        description: t('admin.setup.welcome_description', {
          store: store?.name ?? data.store_name,
        }),
      })

      // A merchant who has just claimed the installation has an empty store,
      // so the checklist is the useful landing place rather than a dashboard
      // of zeroes. A payload carrying no store falls through to the index
      // redirect, which resolves one for itself.
      onCompleted(store?.id ?? null)
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
        <StoreSetupFields
          form={form}
          countries={countries}
          countriesPending={countriesQuery.isPending}
        />
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
        {/* Sample data needs an admin to own its imports, so this is the
            earliest moment it can be offered; the load runs in the
            background after setup completes. */}
        <Controller
          name="sample_data"
          control={form.control}
          render={({ field }) => (
            <div className="grid gap-1">
              <label
                htmlFor="sample_data"
                className="flex cursor-pointer items-center gap-2 text-sm font-medium"
              >
                <Checkbox
                  id="sample_data"
                  checked={field.value}
                  onCheckedChange={(checked) => field.onChange(checked === true)}
                />
                {t('admin.fields.setup.sample_data.label')}
              </label>
              <p className="pl-6 text-xs text-muted-foreground">
                {t('admin.fields.setup.sample_data.help')}
              </p>
            </div>
          )}
        />
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
