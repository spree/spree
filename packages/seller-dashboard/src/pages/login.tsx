import { useAuth } from '@spree/dashboard-core'
import { Button, Field, FieldError, FieldGroup, FieldLabel, Input } from '@spree/dashboard-ui'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'

interface LoginValues {
  email: string
  password: string
}

/**
 * Sign-in for sellers.
 *
 * Its own surface rather than the admin login: the two read different
 * strategy registries against the same user class, so a marketplace can
 * require SSO for its own staff while sellers still use a password.
 */
export function LoginPage() {
  const { t } = useTranslation()
  const { login } = useAuth()
  const [error, setError] = useState<string | null>(null)
  const form = useForm<LoginValues>({ defaultValues: { email: '', password: '' } })

  async function onSubmit(values: LoginValues) {
    setError(null)
    try {
      await login(values.email, values.password)
      // Where to go next is the index route's decision — it already knows how
      // to skip the picker for a seller who runs exactly one seller, and
      // duplicating that here would leave two rules to keep in step.
    } catch {
      // The API refuses a staff member who runs no seller with the same
      // status as a bad password, so the panel says the same thing: it must
      // not become a way to discover which accounts exist.
      setError(t('login.failed'))
    }
  }

  const { errors, isSubmitting } = form.formState

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-medium text-xl">{t('login.title')}</h1>
        <p className="mt-1 mb-6 text-muted-foreground text-sm">{t('login.subtitle')}</p>

        <form onSubmit={form.handleSubmit(onSubmit)}>
          <FieldGroup>
            {error && (
              <p className="text-destructive text-sm" role="alert">
                {error}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="email">{t('login.email')}</FieldLabel>
              <Input
                id="email"
                type="email"
                autoComplete="email"
                autoFocus
                aria-invalid={!!errors.email || undefined}
                {...form.register('email', { required: true })}
              />
              <FieldError errors={[errors.email]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="password">{t('login.password')}</FieldLabel>
              <Input
                id="password"
                type="password"
                autoComplete="current-password"
                aria-invalid={!!errors.password || undefined}
                {...form.register('password', { required: true })}
              />
              <FieldError errors={[errors.password]} />
            </Field>

            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? t('login.submitting') : t('login.submit')}
            </Button>
          </FieldGroup>
        </form>
      </div>
    </div>
  )
}
