import { zodResolver } from '@hookform/resolvers/zod'
import { useAuth } from '@spree/dashboard-core'
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
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { AuthShell } from '../components/spree/auth-shell'
import { type LoginFormValues, loginFormSchema } from '../schemas/auth'

export const Route = createFileRoute('/login')({
  component: LoginPage,
})

function LoginPage() {
  const { t } = useTranslation()
  const { login, isLoading, isAuthenticated } = useAuth()

  const form = useForm<LoginFormValues>({
    resolver: zodResolver(loginFormSchema),
    defaultValues: { email: '', password: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: LoginFormValues) => {
    try {
      await login(data.email, data.password)
    } catch {
      form.setError('root', { message: t('admin.validation.invalid_email_or_password') })
    }
  }

  if (isAuthenticated) return <Navigate to="/" replace />

  return (
    <AuthShell>
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-xl">{t('admin.auth.login.title')}</CardTitle>
          <CardDescription>{t('admin.auth.login.subtitle')}</CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={form.handleSubmit(onSubmit)}>
            <div className="grid gap-6">
              {errors.root && (
                <p className="text-sm text-destructive text-center">{errors.root.message}</p>
              )}
              <div className="grid gap-6">
                <div className="grid gap-2">
                  <Label htmlFor="email">{t('admin.fields.email.label')}</Label>
                  <Input
                    id="email"
                    type="email"
                    placeholder={t('admin.fields.login.email.placeholder')}
                    aria-invalid={!!errors.email || undefined}
                    autoFocus={true}
                    {...form.register('email')}
                  />
                  {errors.email && (
                    <p className="text-sm text-destructive">{errors.email.message}</p>
                  )}
                </div>
                <div className="grid gap-2">
                  <div className="flex items-center justify-between">
                    <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
                    <Link
                      to="/forgot-password"
                      className="text-sm underline-offset-4 hover:underline"
                    >
                      {t('admin.auth.forgot_password.link')}
                    </Link>
                  </div>
                  <Input
                    id="password"
                    type="password"
                    aria-invalid={!!errors.password || undefined}
                    {...form.register('password')}
                  />
                  {errors.password && (
                    <p className="text-sm text-destructive">{errors.password.message}</p>
                  )}
                </div>
                <Button type="submit" className="w-full" disabled={isLoading}>
                  {isLoading ? t('admin.actions.signing_in') : t('admin.actions.sign_in')}
                </Button>
              </div>
            </div>
          </form>
        </CardContent>
      </Card>
    </AuthShell>
  )
}
