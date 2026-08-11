import type { RoleCreateParams, RoleUpdateParams } from '@spree/admin-sdk'
import { adminClient, useResourceKey, useResourceMutation } from '@spree/dashboard-core'
import { useQuery } from '@tanstack/react-query'

export { useRoles } from './use-staff'

export function useRole(id: string) {
  return useQuery({
    queryKey: [...useResourceKey('roles'), id],
    queryFn: () => adminClient.roles.get(id),
    // An empty id would hit the roles index instead of a record — the create
    // page passes '' when it is not duplicating an existing role.
    enabled: id !== '',
  })
}

/**
 * The permission catalog — the grant vocabulary shared by staff roles and API
 * key scopes. Static per server boot; store-keyed anyway so labels follow the
 * store's locale context.
 */
export function usePermissionCatalog() {
  return useQuery({
    queryKey: useResourceKey('permissions'),
    queryFn: () => adminClient.permissions.list(),
    staleTime: 30 * 60 * 1000,
  })
}

export function useCreateRole() {
  return useResourceMutation<unknown, Error, RoleCreateParams>({
    mutationFn: (params) => adminClient.roles.create(params),
    invalidate: [['roles']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useUpdateRole() {
  return useResourceMutation<unknown, Error, { id: string; params: RoleUpdateParams }>({
    mutationFn: ({ id, params }) => adminClient.roles.update(id, params),
    invalidate: [['roles']],
    successMessage: false,
    errorMessage: false,
  })
}

export function useDeleteRole() {
  return useResourceMutation<unknown, Error, string>({
    mutationFn: (id) => adminClient.roles.delete(id),
    // Deleting a role also updates staff members' role badge lists.
    invalidate: [['roles'], ['staff']],
    successMessage: false,
    errorMessage: false,
  })
}
