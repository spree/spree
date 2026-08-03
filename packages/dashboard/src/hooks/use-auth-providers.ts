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
