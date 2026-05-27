import type { AdminUserUpdateParams, InvitationCreateParams } from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '@/client'

const STAFF_KEY = ['staff'] as const
const INVITATIONS_KEY = ['invitations'] as const
const ROLES_KEY = ['roles'] as const

export function useStaff() {
  return useQuery({
    queryKey: STAFF_KEY,
    queryFn: () => adminClient.adminUsers.list({ limit: 100 }),
  })
}

export function useInvitations() {
  return useQuery({
    queryKey: INVITATIONS_KEY,
    queryFn: () => adminClient.invitations.list({ limit: 100 }),
  })
}

export function useRoles() {
  return useQuery({
    queryKey: ROLES_KEY,
    queryFn: () => adminClient.roles.list({ limit: 100 }),
    // Roles are global; cache aggressively so the role picker doesn't refetch
    // every time the staff dialog opens.
    staleTime: 5 * 60 * 1000,
  })
}

export function useUpdateStaff() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: ({ id, params }: { id: string; params: AdminUserUpdateParams }) =>
      adminClient.adminUsers.update(id, params),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: STAFF_KEY })
    },
  })
}

/**
 * Removes the user's role assignments on the current store. The account is
 * preserved — the user keeps access to any other stores.
 */
export function useRemoveStaff() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => adminClient.adminUsers.delete(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: STAFF_KEY })
    },
  })
}

export function useCreateInvitation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (params: InvitationCreateParams) => adminClient.invitations.create(params),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: INVITATIONS_KEY })
    },
  })
}

export function useResendInvitation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => adminClient.invitations.resend(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: INVITATIONS_KEY })
    },
  })
}

export function useDeleteInvitation() {
  const qc = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => adminClient.invitations.delete(id),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: INVITATIONS_KEY })
    },
  })
}
