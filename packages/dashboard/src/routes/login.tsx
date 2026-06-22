import { zodResolver } from '@hookform/resolvers/zod'
import { useAuth } from '@spree/dashboard-core'
import {
  Button,
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
  cn,
  Input,
  Label,
} from '@spree/dashboard-ui'
import { createFileRoute, Navigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { type LoginFormValues, loginFormSchema } from '@/schemas/auth'

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

  const onSubmit = async (data: LoginFormValues) => {
    try {
      await login(data.email, data.password)
    } catch {
      form.setError('root', { message: t('admin.validation.invalid_email_or_password') })
    }
  }

  if (isAuthenticated) return <Navigate to="/" replace />

  return (
    <div className="flex min-h-svh flex-col items-center justify-center gap-6 bg-muted p-6 md:p-10">
      <div className="flex w-full max-w-sm flex-col gap-6">
        <a href="/" className="flex items-center gap-2 self-center font-medium">
          <div className="flex h-6 w-6 items-center justify-center rounded-md bg-primary text-primary-foreground">
            <GalleryVerticalEnd className="size-4" />
          </div>
          {t('admin.branding.app_name')}
        </a>
        <LoginFormCard form={form} onSubmit={onSubmit} isLoading={isLoading} />
      </div>
    </div>
  )
}

function LoginFormCard({
  form,
  onSubmit,
  isLoading,
  className,
}: {
  form: ReturnType<typeof useForm<LoginFormValues>>
  onSubmit: (data: LoginFormValues) => Promise<void>
  isLoading: boolean
  className?: string
}) {
  const { t } = useTranslation()
  const { errors } = form.formState
  return (
    <div className={cn('flex flex-col gap-6', className)}>
      <Card>
        <CardHeader className="text-center">
          <CardTitle className="text-xl">{t('admin.pages.login.title')}</CardTitle>
          <CardDescription>{t('admin.pages.login.subtitle')}</CardDescription>
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
                  <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
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
      <div className="text-balance text-center text-xs text-muted-foreground">
        <a
          href="https://spreecommerce.org"
          className="underline underline-offset-4 hover:text-primary"
          target="_blank"
          rel="noreferrer"
        >
          {t('admin.branding.powered_by')}
        </a>
      </div>
    </div>
  )
}

function GalleryVerticalEnd(props: React.SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      <path d="M7 2h10" />
      <path d="M5 6h14" />
      <rect width="18" height="12" x="3" y="10" rx="2" />
    </svg>
  )
}
