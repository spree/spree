import { useAuth } from '@spree/dashboard-core'
import { Button, Field, FieldError, FieldGroup, FieldLabel, Input } from '@spree/dashboard-ui'
import { Link, useNavigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { CenteredMessage } from '../components/centered-message'

interface ResetValues {
  password: string
  password_confirmation: string
}

/**
 * Choosing a new password from the emailed link.
 *
 * The token in the URL is the whole credential — nobody is signed in yet.
 * Spending it returns a seller session, so they land in the panel rather than
 * being bounced to a login form.
 */
export function ResetPasswordPage({ token }: { token?: string }) {
  const { t } = useTranslation()
  const { resetPassword } = useAuth()
  const navigate = useNavigate()
  const [error, setError] = useState<string | null>(null)
  const form = useForm<ResetValues>({
    defaultValues: { password: '', password_confirmation: '' },
  })

  if (!token) return <CenteredMessage>{t('reset_password.invalid_link')}</CenteredMessage>

  async function onSubmit(values: ResetValues) {
    setError(null)
    try {
      await resetPassword(token ?? '', values)
      // The index route decides where to go from there — it already knows how
      // to skip the picker for someone who runs exactly one seller.
      navigate({ to: '/', replace: true })
    } catch {
      // A rejected token and a refused password are reported the same way the
      // API reports them: it will not say whether the address exists.
      setError(t('reset_password.failed'))
    }
  }

  const { errors, isSubmitting } = form.formState

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-medium text-xl">{t('reset_password.title')}</h1>
        <p className="mt-1 mb-6 text-muted-foreground text-sm">{t('reset_password.subtitle')}</p>

        <form onSubmit={form.handleSubmit(onSubmit)}>
          <FieldGroup>
            {error && (
              <p className="text-destructive text-sm" role="alert">
                {error}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="password">{t('reset_password.password')}</FieldLabel>
              <Input
                id="password"
                type="password"
                autoComplete="new-password"
                autoFocus
                aria-invalid={!!errors.password || undefined}
                {...form.register('password', { required: true, minLength: 8 })}
              />
              <FieldError errors={[errors.password]} />
            </Field>

            <Field>
              <FieldLabel htmlFor="password_confirmation">
                {t('reset_password.password_confirmation')}
              </FieldLabel>
              <Input
                id="password_confirmation"
                type="password"
                autoComplete="new-password"
                aria-invalid={!!errors.password_confirmation || undefined}
                {...form.register('password_confirmation', {
                  required: true,
                  validate: (value, values) =>
                    value === values.password || t('reset_password.mismatch'),
                })}
              />
              <FieldError errors={[errors.password_confirmation]} />
            </Field>

            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? t('reset_password.submitting') : t('reset_password.submit')}
            </Button>

            <Link to="/forgot-password" className="text-sm underline underline-offset-4">
              {t('reset_password.request_new_link')}
            </Link>
          </FieldGroup>
        </form>
      </div>
    </div>
  )
}
