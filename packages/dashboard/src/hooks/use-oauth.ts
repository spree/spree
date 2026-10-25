import type { OauthAuthorizationParams, OauthConsentRequest, OauthRedirect } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * What a client is asking the merchant to approve.
 *
 * Never cached: the request carries a one-time authorization code and a PKCE
 * challenge, so a stale read would describe a request that no longer exists.
 */
export function useOauthAuthorization(params: OauthAuthorizationParams | null) {
  return useQuery<OauthConsentRequest>({
    queryKey: useResourceKey('oauth-authorization', JSON.stringify(params ?? {})),
    enabled: params !== null,
    staleTime: 0,
    gcTime: 0,
    retry: false,
    queryFn: () => adminClient.oauth.authorization(params as OauthAuthorizationParams),
  })
}

export function useApproveOauthAuthorization() {
  return useResourceMutation<OauthRedirect, Error, OauthAuthorizationParams>({
    mutationFn: (params) => adminClient.oauth.approve(params),
    successMessage: false,
    errorMessage: false,
  })
}

export function useDenyOauthAuthorization() {
  return useResourceMutation<OauthRedirect, Error, OauthAuthorizationParams>({
    mutationFn: (params) => adminClient.oauth.deny(params),
    successMessage: false,
    errorMessage: false,
  })
}

/**
 * Every client registered against this store. The connected ones are those
 * carrying live scopes, which the row renders from.
 */
export function useOauthApplications() {
  return useQuery({
    queryKey: useResourceKey('oauth-applications'),
    queryFn: () => adminClient.oauth.applications.list(),
  })
}

/** Kept for the connect panel, which only needs the client ids. */
export function useOauthRegistrations() {
  return useQuery({
    queryKey: useResourceKey('oauth-applications'),
    queryFn: () => adminClient.oauth.applications.list(),
    staleTime: 30 * 60 * 1000,
  })
}

/** Removes the registration, and every grant and token with it. */
export function useDeleteOauthApplication() {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.oauth.applications.delete(id),
    invalidate: [['oauth-applications']],
  })
}

/**
 * The people connected through one registered client. A store registers a
 * client once and everyone connects to that same registration, so this is
 * who actually holds access.
 */
export function useOauthApplicationTokens(applicationId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('oauth-application-tokens', applicationId ?? ''),
    queryFn: () =>
      adminClient.oauth.applications.tokens.list(applicationId as string, {
        expand: ['owner'],
      }),
    enabled: Boolean(applicationId),
  })
}

export function useRevokeOauthToken(applicationId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.oauth.applications.tokens.delete(applicationId, id),
    invalidate: [['oauth-applications'], ['oauth-application-tokens']],
    successMessage: false,
    // A failed revoke has no inline form to report into, and the row simply
    // staying put reads as success — so this one does toast.
  })
}
