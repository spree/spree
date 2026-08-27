import { Button, Field, FieldError, FieldGroup, FieldLabel, Input } from '@spree/dashboard-ui'
import { Link } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { sellerClient } from '../api-client'

interface ForgotValues {
  email: string
}

/**
 * Asking for a reset link.
 *
 * Its own surface rather than the dashboard's: the link has to open the seller
 * panel, and a seller sent to the staff dashboard would land on a form that
 * resets them into an admin session they cannot use.
 */
export function ForgotPasswordPage() {
  const { t } = useTranslation()
  const [sent, setSent] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const form = useForm<ForgotValues>({ defaultValues: { email: '' } })

  async function onSubmit(values: ForgotValues) {
    setError(null)
    try {
      await sellerClient().auth.requestPasswordReset({
        email: values.email,
        // Where this panel serves its reset page. The server honours it only
        // if the origin is one the marketplace has vouched for, and resolves
        // the panel origin itself otherwise.
        redirect_url: `${window.location.origin}/reset-password`,
      })
      // Confirmed either way — the API never reveals whether the address
      // matched, and neither may this page.
      setSent(true)
    } catch {
      setError(t('forgot_password.failed'))
    }
  }

  const { errors, isSubmitting } = form.formState

  if (sent) {
    return (
      <div className="flex min-h-screen items-center justify-center p-6">
        <div className="w-full max-w-sm">
          <h1 className="font-medium text-xl">{t('forgot_password.sent_title')}</h1>
          <p className="mt-1 mb-6 text-muted-foreground text-sm">
            {t('forgot_password.sent_subtitle')}
          </p>
          <Link to="/login" className="text-sm underline underline-offset-4">
            {t('forgot_password.back_to_login')}
          </Link>
        </div>
      </div>
    )
  }

  return (
    <div className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-sm">
        <h1 className="font-medium text-xl">{t('forgot_password.title')}</h1>
        <p className="mt-1 mb-6 text-muted-foreground text-sm">{t('forgot_password.subtitle')}</p>

        <form onSubmit={form.handleSubmit(onSubmit)}>
          <FieldGroup>
            {error && (
              <p className="text-destructive text-sm" role="alert">
                {error}
              </p>
            )}

            <Field>
              <FieldLabel htmlFor="email">{t('forgot_password.email')}</FieldLabel>
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

            <Button type="submit" disabled={isSubmitting}>
              {isSubmitting ? t('forgot_password.submitting') : t('forgot_password.submit')}
            </Button>

            <Link to="/login" className="text-sm underline underline-offset-4">
              {t('forgot_password.back_to_login')}
            </Link>
          </FieldGroup>
        </form>
      </div>
    </div>
  )
}
