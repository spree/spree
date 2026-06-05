import type { AdminUserUpdateParams, InvitationCreateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export function useStaff() {
  return useQuery({
    queryKey: useResourceKey('staff'),
    queryFn: () => adminClient.adminUsers.list({ limit: 100 }),
  })
}

export function useInvitations() {
  return useQuery({
    queryKey: useResourceKey('invitations'),
    queryFn: () => adminClient.invitations.list({ limit: 100 }),
  })
}

export function useRoles() {
  // Roles are global across stores; no storeId scope.
  return useQuery({
    queryKey: ['roles'],
    queryFn: () => adminClient.roles.list({ limit: 100 }),
    staleTime: 5 * 60 * 1000,
  })
}

export function useUpdateStaff() {
  return useResourceMutation<unknown, Error, { id: string; params: AdminUserUpdateParams }>({
    mutationFn: ({ id, params }) => adminClient.adminUsers.update(id, params),
    invalidate: [['staff']],
    successMessage: false,
    errorMessage: false,
  })
}

/**
 * Removes the user's role assignments on the current store. The account is
 * preserved — the user keeps access to any other stores.
 */
export function useRemoveStaff() {
  return useResourceMutation<unknown, Error, string>({
    mutationFn: (id) => adminClient.adminUsers.delete(id),
    invalidate: [['staff']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useCreateInvitation() {
  return useResourceMutation<unknown, Error, InvitationCreateParams>({
    mutationFn: (params) => adminClient.invitations.create(params),
    invalidate: [['invitations']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useResendInvitation() {
  return useResourceMutation<unknown, Error, string>({
    mutationFn: (id) => adminClient.invitations.resend(id),
    invalidate: [['invitations']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useDeleteInvitation() {
  return useResourceMutation<unknown, Error, string>({
    mutationFn: (id) => adminClient.invitations.delete(id),
    invalidate: [['invitations']],
    successMessage: false,
    errorMessage: false,
  })
}
