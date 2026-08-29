import { zodResolver } from '@hookform/resolvers/zod'
import type { AuthProvider } from '@spree/admin-sdk'
import { SpreeError } from '@spree/admin-sdk'
import { adminClient, useAuth } from '@spree/dashboard-core'
import { Button, Input, Label, Skeleton } from '@spree/dashboard-ui'
import { useQuery } from '@tanstack/react-query'
import { createFileRoute, Link, Navigate } from '@tanstack/react-router'
import { useForm } from 'react-hook-form'
import { useTranslation } from 'react-i18next'
import { AuthShell } from '../components/spree/auth-shell'
import { useAuthProviders } from '../hooks/use-auth-providers'
import { type LoginFormValues, loginFormSchema } from '../schemas/auth'

/** Error code the SSO callback redirects back with when it rejects a sign-in. */
type LoginSearch = { error?: string }

export const Route = createFileRoute('/login')({
  component: LoginPage,
  validateSearch: (search: Record<string, unknown>): LoginSearch =>
    typeof search.error === 'string' ? { error: search.error } : {},
})

function LoginPage() {
  const { t } = useTranslation()
  const { isAuthenticated } = useAuth()
  const { error: callbackError } = Route.useSearch()
  const {
    passwordProvider,
    redirectProviders,
    isLoading: isLoadingProviders,
    isError: providersFailed,
  } = useAuthProviders()

  if (isAuthenticated) return <Navigate to="/" replace />

  return (
    <AuthShell>
      <div className="flex flex-col gap-2">
        <h1 className="text-2xl font-bold">{t('admin.auth.login.title')}</h1>
        <p className="text-sm text-muted-foreground">{t('admin.auth.login.subtitle')}</p>
      </div>

      {callbackError && <CallbackError code={callbackError} />}

      <SetupRequiredNotice />

      <ProviderOptions
        passwordProvider={passwordProvider}
        redirectProviders={redirectProviders}
        isLoading={isLoadingProviders}
        failed={providersFailed}
      />
    </AuthShell>
  )
}

/**
 * A fresh install has no admin account to sign in with — point at the
 * first-run setup screen instead (the setup token from the install output is
 * still required there). Renders nothing on an already-claimed installation.
 */
function SetupRequiredNotice() {
  const { t } = useTranslation()
  const status = useQuery({
    queryKey: ['setup-status'],
    queryFn: () => adminClient.auth.setupStatus(),
    retry: false,
    // See the /setup route: never offer setup from a cached `true`.
    gcTime: 0,
    staleTime: 0,
    refetchOnMount: 'always',
  })

  if (!status.data?.setup_required) return null

  return (
    <div className="grid gap-2 rounded-md border p-4">
      <p className="font-medium text-sm">{t('admin.setup.required_notice_title')}</p>
      <p className="text-sm text-muted-foreground">{t('admin.setup.required_notice_message')}</p>
      <Link to="/setup" className="text-sm underline underline-offset-4">
        {t('admin.setup.required_notice_link')}
      </Link>
    </div>
  )
}

function ProviderOptions({
  passwordProvider,
  redirectProviders,
  isLoading,
  failed,
}: {
  passwordProvider?: AuthProvider
  redirectProviders: AuthProvider[]
  isLoading: boolean
  failed: boolean
}) {
  // Falling back to the password form would be the safer default for
  // availability, but it is the wrong one here: on an SSO-only store it renders
  // a form that cannot possibly work.
  if (failed) return <ProvidersUnavailable />
  if (isLoading) return <Skeleton className="h-40" />

  return (
    <div className="grid gap-6">
      {passwordProvider && <PasswordLoginForm />}

      {passwordProvider && redirectProviders.length > 0 && <Divider />}

      {redirectProviders.length > 0 && (
        <div className="grid gap-3">
          {redirectProviders.map((provider) => (
            <SsoButton key={provider.key} provider={provider} />
          ))}
        </div>
      )}
    </div>
  )
}

function PasswordLoginForm() {
  const { t } = useTranslation()
  const { login, isLoading } = useAuth()

  const form = useForm<LoginFormValues>({
    resolver: zodResolver(loginFormSchema),
    defaultValues: { email: '', password: '' },
  })
  const { errors } = form.formState

  const onSubmit = async (data: LoginFormValues) => {
    try {
      await login(data.email, data.password)
    } catch (err) {
      // Surface the server's message (e.g. account lockout) — bad credentials and
      // lockout share a code, so the message is the only distinguishing signal.
      // Fall back to the generic string for network/unexpected errors.
      const message =
        err instanceof SpreeError ? err.message : t('admin.validation.invalid_email_or_password')
      form.setError('root', { message })
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)}>
      <div className="grid gap-6">
        {errors.root && <p className="text-sm text-destructive">{errors.root.message}</p>}
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
          {errors.email && <p className="text-sm text-destructive">{errors.email.message}</p>}
        </div>
        <div className="grid gap-2">
          <div className="flex items-center justify-between">
            <Label htmlFor="password">{t('admin.fields.password.label')}</Label>
            <Link
              tabIndex={-1}
              to="/forgot-password"
              className="text-sm underline-offset-4 hover:underline"
            >
              {t('admin.auth.forgot_password.link')}
            </Link>
          </div>
          <Input
            id="password"
            type="password"
            tabIndex={0}
            aria-invalid={!!errors.password || undefined}
            {...form.register('password')}
          />
          {errors.password && <p className="text-sm text-destructive">{errors.password.message}</p>}
        </div>
        <Button type="submit" className="w-full" disabled={isLoading}>
          {isLoading ? t('admin.actions.signing_in') : t('admin.actions.sign_in')}
        </Button>
      </div>
    </form>
  )
}

function SsoButton({ provider }: { provider: AuthProvider }) {
  const { t } = useTranslation()

  // A full page navigation, not a fetch: the identity provider needs to own the
  // browser for its own login screen and any MFA prompts.
  return (
    <Button
      type="button"
      variant="outline"
      className="w-full"
      onClick={() => {
        if (provider.authorization_url) window.location.href = provider.authorization_url
      }}
    >
      {t('admin.auth.login.sso_button', { provider: provider.label ?? provider.key })}
    </Button>
  )
}

function Divider() {
  const { t } = useTranslation()

  return (
    <div className="relative text-center text-sm">
      <span className="absolute inset-0 top-1/2 border-t" aria-hidden="true" />
      <span className="relative bg-muted px-2 text-muted-foreground">
        {t('admin.auth.login.divider')}
      </span>
    </div>
  )
}

function ProvidersUnavailable() {
  const { t } = useTranslation()

  return (
    <div className="grid gap-2 rounded-md border border-destructive/50 p-4">
      <p className="font-medium text-sm">{t('admin.auth.login.providers_error_title')}</p>
      <p className="text-sm text-muted-foreground">
        {t('admin.auth.login.providers_error_message')}
      </p>
    </div>
  )
}

/**
 * Server error codes (`ERROR_CODES` in the Admin API) to their copy. A rejected
 * SSO sign-in is not a failed credential check — the person proved who they are
 * to the identity provider — so each code says what actually needs to happen.
 * Unknown codes fall back to the generic message.
 */
const CALLBACK_ERROR_KEYS: Record<string, string> = {
  account_not_provisioned: 'admin.auth.login.account_not_provisioned',
  invalid_oauth_state: 'admin.auth.login.invalid_oauth_state',
  invalid_provider: 'admin.auth.login.sso_failed',
  authentication_failed: 'admin.auth.login.sso_failed',
  // Temporary and self-clearing — say so, rather than implying the provider is broken.
  rate_limit_exceeded: 'admin.auth.login.rate_limit_exceeded',
}

function CallbackError({ code }: { code: string }) {
  const { t } = useTranslation()

  return (
    <p className="text-sm text-destructive">
      {t(CALLBACK_ERROR_KEYS[code] ?? 'admin.auth.login.sso_failed')}
    </p>
  )
}
