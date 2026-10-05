import type {
  OauthAuthorizationParams,
  OauthAuthorizationRequest,
  OauthRedirect,
} from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

/**
 * What a client is asking the merchant to approve.
 *
 * Never cached: the request carries a one-time authorization code and a PKCE
 * challenge, so a stale read would describe a request that no longer exists.
 */
export function useOauthAuthorization(params: OauthAuthorizationParams | null) {
  return useQuery<OauthAuthorizationRequest>({
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
 * Every registered client, for the setup panel — unlike the connected list,
 * which answers what to revoke.
 */
export function useOauthRegistrations() {
  return useQuery({
    queryKey: useResourceKey('oauth-registrations'),
    queryFn: () => adminClient.oauth.applications.registrations(),
    staleTime: 30 * 60 * 1000,
  })
}

export function useOauthApplications() {
  return useQuery({
    queryKey: useResourceKey('oauth-applications'),
    queryFn: () => adminClient.oauth.applications.list(),
  })
}

export function useRevokeOauthApplication() {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.oauth.applications.revoke(id),
    invalidate: [['oauth-applications']],
    successMessage: false,
    // A failed revoke has no inline form to report into, and the row simply
    // staying put reads as success — so this one does toast.
  })
}
