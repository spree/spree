import type {
  Invitation,
  ListParams,
  Seller,
  SellerApproveParams,
  SellerCreateParams,
  SellerInviteParams,
  SellerRejectParams,
  SellerReopenOnboardingParams,
  SellerSuspendParams,
  SellerUpdateParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useSellers(params?: ListParams & Record<string, unknown>) {
  return useQuery({
    queryKey: useResourceKey('sellers', params ? JSON.stringify(params) : 'all'),
    queryFn: () => adminClient.sellers.list(params),
  })
}

/**
 * Whether this store has any sellers at all.
 *
 * What the marketplace surfaces gate on: an operator selling purely their own
 * goods should never meet an "open to sellers" switch or a seller column. One
 * row is enough to answer it, and every caller shares the cache.
 */
export function useHasSellers(): boolean {
  const { data } = useSellers({ limit: 1 })

  return (data?.data.length ?? 0) > 0
}

/**
 * Shared config for any `<ResourceMultiAutocomplete>` picking sellers (today
 * the products table filter). Pass a unique `queryKey` per instance so
 * independent caches don't collide.
 */
export function sellerAutocompleteProps(queryKey: string) {
  return {
    queryKey,
    search: (q: string) =>
      adminClient.sellers.list({ name_cont: q, limit: 100, sort: 'name', fields: ['name'] }),
    hydrate: (ids: string[]) => adminClient.sellers.list({ id_in: ids, limit: ids.length }),
    getOptionLabel: (seller: Seller) => seller.name ?? seller.id,
    placeholder: i18n.t('admin.sellers.autocomplete.placeholder'),
    emptyText: i18n.t('admin.sellers.autocomplete.empty'),
  }
}

export function useSeller(id: string | undefined) {
  const key = useResourceKey('sellers', id ?? 'noop')
  return useQuery({
    queryKey: key,
    queryFn: () => adminClient.sellers.get(id as string),
    enabled: !!id,
  })
}

export function useCreateSeller() {
  return useResourceMutation<Seller, Error, SellerCreateParams>({
    mutationFn: (params) => adminClient.sellers.create(params),
    invalidate: [['sellers']],
    successMessage: i18n.t('admin.sellers.messages.created'),
    errorMessage: i18n.t('admin.sellers.messages.create_failed'),
  })
}

export function useUpdateSeller(id: string) {
  return useResourceMutation<Seller, Error, SellerUpdateParams>({
    mutationFn: (params) => adminClient.sellers.update(id, params),
    invalidate: [['sellers'], ['sellers', id]],
    successMessage: i18n.t('admin.sellers.messages.updated'),
    errorMessage: i18n.t('admin.sellers.messages.update_failed'),
  })
}

export function useDeleteSeller() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.sellers.delete(id),
    invalidate: [['sellers']],
    successMessage: i18n.t('admin.sellers.messages.deleted'),
    errorMessage: i18n.t('admin.sellers.messages.delete_failed'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('sellers', id) })
    },
  })
}

export function useInviteSeller(id: string) {
  return useResourceMutation<Seller, Error, SellerInviteParams>({
    mutationFn: (params) => adminClient.sellers.invite(id, params),
    invalidate: [['sellers'], ['sellers', id]],
    successMessage: i18n.t('admin.sellers.messages.invited'),
    errorMessage: i18n.t('admin.sellers.messages.invite_failed'),
  })
}

/**
 * Admits a seller. The server refuses while a required onboarding requirement
 * is unmet, so pass `override_requirements` to admit one anyway — the page
 * turns that into a confirm dialog naming what is outstanding, and the
 * `seller.approved` event records the override.
 *
 * Invalidates the seller's onboarding query as well as the seller itself,
 * since approving can change what the checklist reports.
 */
export function useApproveSeller(id: string) {
  return useResourceMutation<Seller, Error, SellerApproveParams | undefined>({
    mutationFn: (params) => adminClient.sellers.approve(id, params ?? undefined),
    invalidate: [['sellers'], ['sellers', id], ['sellers', id, 'onboarding']],
    successMessage: i18n.t('admin.sellers.messages.approved'),
    errorMessage: i18n.t('admin.sellers.messages.approve_failed'),
  })
}

/**
 * Sends a seller awaiting review back to onboarding, optionally with a note
 * saying what to fix. Distinct from rejecting them, which turns them away.
 *
 * Invalidates the onboarding query too, because the seller's standing against
 * the checklist changes with their status.
 */
export function useReopenSellerOnboarding(id: string) {
  return useResourceMutation<Seller, Error, SellerReopenOnboardingParams | undefined>({
    mutationFn: (params) => adminClient.sellers.reopenOnboarding(id, params ?? undefined),
    invalidate: [['sellers'], ['sellers', id], ['sellers', id, 'onboarding']],
    successMessage: i18n.t('admin.sellers.messages.onboarding_reopened'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useSuspendSeller(id: string) {
  return useResourceMutation<Seller, Error, SellerSuspendParams | undefined>({
    mutationFn: (params) => adminClient.sellers.suspend(id, params ?? undefined),
    invalidate: [['sellers'], ['sellers', id]],
    successMessage: i18n.t('admin.sellers.messages.suspended'),
    errorMessage: i18n.t('admin.sellers.messages.suspend_failed'),
  })
}

export function useRejectSeller(id: string) {
  return useResourceMutation<Seller, Error, SellerRejectParams | undefined>({
    mutationFn: (params) => adminClient.sellers.reject(id, params ?? undefined),
    invalidate: [['sellers'], ['sellers', id]],
    successMessage: i18n.t('admin.sellers.messages.rejected'),
    errorMessage: i18n.t('admin.sellers.messages.reject_failed'),
  })
}

export function useSellerTeam(sellerId: string) {
  return useQuery({
    queryKey: useResourceKey('sellers', sellerId, 'team'),
    queryFn: () => adminClient.sellers.team.list(sellerId),
  })
}

export function useRemoveSellerTeamMember(sellerId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.sellers.team.remove(sellerId, id),
    invalidate: [
      ['sellers', sellerId, 'team'],
      ['sellers', sellerId],
    ],
    successMessage: i18n.t('admin.sellers.team.messages.removed'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useSellerInvitations(sellerId: string) {
  return useQuery({
    queryKey: useResourceKey('sellers', sellerId, 'invitations'),
    queryFn: () => adminClient.sellers.invitations.list(sellerId),
  })
}

export function useRevokeSellerInvitation(sellerId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.sellers.invitations.remove(sellerId, id),
    invalidate: [['sellers', sellerId, 'invitations']],
    successMessage: i18n.t('admin.sellers.team.messages.invitation_revoked'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

export function useResendSellerInvitation(sellerId: string) {
  return useResourceMutation<Invitation, Error, string>({
    mutationFn: (id) => adminClient.sellers.invitations.resend(sellerId, id),
    invalidate: [['sellers', sellerId, 'invitations']],
    successMessage: i18n.t('admin.sellers.team.messages.invitation_resent'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}
