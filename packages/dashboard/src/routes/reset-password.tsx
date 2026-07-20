import { zodResolver } from '@hookform/resolvers/zod'
import type { SpreeError } from '@spree/admin-sdk'
import { mapSpreeErrorsToForm, useAuth } from '@spree/dashboard-core'
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
import { createFileRoute, Link, Navigate, useNavigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { z } from 'zod/v4'
import { AuthShell } from '../components/spree/auth-shell'
import { type ResetPasswordFormValues, resetPasswordFormSchema } from '../schemas/auth'

const resetSearchSchema = z.object({
  token: z.string().min(1).optional(),
})

export const Route = createFileRoute('/reset-password')({
  validateSearch: resetSearchSchema,
  component: ResetPasswordPage,
})

function ResetPasswordPage() {
  const { t } = useTranslation()
  const { token } = Route.useSearch()
  const { isAuthenticated } = useAuth()

  if (isAuthenticated) return <Navigate to="/" replace />

  if (!token) {
    return (
      <AuthShell>
        <Card>
          <CardHeader className="text-center">
            <CardTitle className="text-xl">
              {t('admin.auth.reset_password.missing_token_title')}
            </CardTitle>
            <CardDescription>
              {t('admin.auth.reset_password.missing_token_message')}
            </CardDescription>
          </CardHeader>
          <CardContent className="text-center">
            <Link
              to="/forgot-password"
              className="text-sm underline underline-offset-4 hover:text-primary"
            >
              {t('admin.auth.reset_password.request_new_link')}
            </Link>
          </CardContent>
        </Card>
      </AuthShell>
    )
  }

  return (
    <AuthShell>
      <ResetPasswordForm token={token} />
    </AuthShell>
  )
}

function ResetPasswordForm({ token }: { token: string }) {
  const { t } = useTranslation()
  const { resetPassword, isLoading } = useAuth()
  const navigate = useNavigate()

  const form = useForm<ResetPasswordFormValues>({
    resolver: zodResolver(resetPasswordFormSchema),
    defaultValues: { password: '', password_confirmation: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: ResetPasswordFormValues) => {
    try {
      // On success the endpoint signs the user in, so land them in the app.
      await resetPassword(token, data)
      navigate({ to: '/', replace: true })
    } catch (err) {
      if (mapSpreeErrorsToForm(err, form.setError)) return
      const e = err as SpreeError
      // A 422 without field errors means the token itself was rejected.
      form.setError('root', {
        message:
          e?.status === 422
            ? t('admin.auth.reset_password.token_invalid')
            : e?.message || t('admin.auth.reset_password.error'),
      })
    }
  }

  return (
    <Card>
      <CardHeader className="text-center">
        <CardTitle className="text-xl">{t('admin.auth.reset_password.title')}</CardTitle>
        <CardDescription>{t('admin.auth.reset_password.subtitle')}</CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={form.handleSubmit(onSubmit)} className="grid gap-6">
          {errors.root && (
            <p className="text-center text-sm text-destructive">{errors.root.message}</p>
          )}
          <div className="grid gap-2">
            <Label htmlFor="password">{t('admin.auth.reset_password.new_password_label')}</Label>
            <Input
              id="password"
              type="password"
              autoFocus
              aria-invalid={!!errors.password || undefined}
              {...form.register('password')}
            />
            {errors.password && (
              <p className="text-sm text-destructive">{errors.password.message}</p>
            )}
          </div>
          <div className="grid gap-2">
            <Label htmlFor="password_confirmation">
              {t('admin.auth.reset_password.confirm_password_label')}
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
            {isLoading
              ? t('admin.auth.reset_password.submitting')
              : t('admin.auth.reset_password.submit')}
          </Button>
        </form>
      </CardContent>
    </Card>
  )
}
