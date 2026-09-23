import type { AuthProvider } from '@spree/admin-sdk'
import { adminClient } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * The authentication providers this store accepts, used by the login page to
 * decide what to render.
 *
 * Not store-scoped: it is read before a session exists, so there is no selected
 * store yet. Retries are disabled — a failure must surface promptly as an error
 * state rather than leaving the sign-in screen spinning.
 */
export function useAuthProviders() {
  const query = useQuery({
    queryKey: ['auth', 'providers'],
    queryFn: () => adminClient.auth.providers(),
    retry: false,
    staleTime: 5 * 60 * 1000,
  })

  const providers: AuthProvider[] = query.data?.providers ?? []

  return {
    ...query,
    providers,
    passwordProvider: providers.find((provider) => provider.kind === 'password'),
    // A provider whose authorization URL could not be built is unusable, so it
    // never becomes a button.
    redirectProviders: providers.filter(
      (provider) => provider.kind === 'redirect' && !!provider.authorization_url,
    ),
  }
}

/**
 * Server error codes (`ERROR_CODES` in the Admin API) to their copy. A rejected
 * SSO sign-in is not a failed credential check — the person proved who they are
 * to the identity provider — so each code says what actually needs to happen.
 */
const CALLBACK_ERROR_KEYS: Record<string, string> = {
  account_not_provisioned: 'admin.auth.login.account_not_provisioned',
  invalid_oauth_state: 'admin.auth.login.invalid_oauth_state',
  invalid_provider: 'admin.auth.login.sso_failed',
  authentication_failed: 'admin.auth.login.sso_failed',
  // Temporary and self-clearing — say so, rather than implying the provider is broken.
  rate_limit_exceeded: 'admin.auth.login.rate_limit_exceeded',
}

/**
 * Translation key for the `error` code the SSO callback redirects back to the
 * login page with. Unknown codes fall back to the generic message.
 */
export function authCallbackErrorKey(code: string): string {
  return CALLBACK_ERROR_KEYS[code] ?? 'admin.auth.login.sso_failed'
}
