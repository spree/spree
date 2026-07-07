import { zodResolver } from '@hookform/resolvers/zod'
import { adminClient, useAuth } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  Input,
  Label,
} from '@spree/dashboard-ui'
import { createFileRoute, Link, Navigate } from '@tanstack/react-router'
import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { AuthShell } from '@/components/spree/auth-shell'
import { type ForgotPasswordFormValues, forgotPasswordFormSchema } from '@/schemas/auth'

export const Route = createFileRoute('/forgot-password')({
  component: ForgotPasswordPage,
})

function ForgotPasswordPage() {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const [submitted, setSubmitted] = useState(false)

  const form = useForm<ForgotPasswordFormValues>({
    resolver: zodResolver(forgotPasswordFormSchema),
    defaultValues: { email: '' },
  })
  const { errors, isSubmitting } = form.formState

  if (isAuthenticated) return <Navigate to="/" replace />

  const onSubmit = async (data: ForgotPasswordFormValues) => {
    try {
      // The dashboard origin hosts the reset page; the server appends the token.
      await adminClient.auth.requestPasswordReset({
        email: data.email,
        redirect_url: `${window.location.origin}/reset-password`,
      })
      // Always confirm — the server never reveals whether the email matched.
      setSubmitted(true)
    } catch {
      form.setError('root', { message: t('admin.auth.forgot_password.error') })
    }
  }

  if (submitted) {
    return (
      <AuthShell>
        <Card>
          <CardHeader className="text-center">
            <CardTitle className="text-xl">{t('admin.auth.forgot_password.sent_title')}</CardTitle>
            <CardDescription>{t('admin.auth.forgot_password.sent_subtitle')}</CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <Link to="/login" className="text-sm underline underline-offset-4 hover:text-primary">
              {t('admin.auth.back_to_login')}
            </Link>
          </CardContent>
        </Card>
      </AuthShell>
    )
  }

  return (
    <AuthShell>
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-xl">{t('admin.auth.forgot_password.title')}</CardTitle>
          <CardDescription>{t('admin.auth.forgot_password.subtitle')}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
            {errors.root && (
              <p className="text-center text-sm text-destructive">{errors.root.message}</p>
            )}
            <div className="grid gap-2">
              <Label htmlFor="email">{t('admin.fields.email.label')}</Label>
              <Input
                id="email"
                type="email"
                placeholder={t('admin.fields.login.email.placeholder')}
                autoFocus
                aria-invalid={!!errors.email || undefined}
                {...form.register('email')}
              />
              {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
            </div>
            <Button type="submit" className="w-full" disabled={isSubmitting}>
              {isSubmitting
                ? t('admin.auth.forgot_password.sending')
                : t('admin.auth.forgot_password.submit')}
            </Button>
            <div className="text-center">
              <Link to="/login" className="text-sm underline underline-offset-4 hover:text-primary">
                {t('admin.auth.back_to_login')}
              </Link>
            </div>
          </form>
        </CardContent>
      </Card>
    </AuthShell>
  )
}
