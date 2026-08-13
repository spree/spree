import { zodResolver } from '@hookform/resolvers/zod'
import type { SpreeError } from '@spree/admin-sdk'
import { adminClient, mapSpreeErrorsToForm, useAuth } from '@spree/dashboard-core'
import { Button, Input, Label } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link, Navigate, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
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
    },
  })
  const { errors } = form.formState

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
