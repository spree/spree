import type {
  CustomFieldCreateParams,
  CustomFieldDefinition,
  CustomFieldDefinitionCreateParams,
  CustomFieldDefinitionUpdateParams,
  CustomFieldOwnerType,
  CustomFieldUpdateParams,
} from '@spree/admin-sdk'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { adminClient } from '../client'
import { i18n } from '../lib/i18n'
import { useResourceMutation } from './use-resource-mutation'

const valuesKey = (ownerType: CustomFieldOwnerType, ownerId: string) =>
  ['custom-fields', ownerType, ownerId] as const

// Root key used to invalidate every definitions query at once. The
// per-resource and per-id keys below extend it so TanStack's prefix
// invalidation catches them.
export const customFieldDefinitionsRootKey = ['custom-field-definitions'] as const

const definitionsKey = (resourceType: string) =>
  [...customFieldDefinitionsRootKey, resourceType] as const

const definitionByIdKey = (id: string) => [...customFieldDefinitionsRootKey, 'id', id] as const

export function useCustomFields(ownerType: CustomFieldOwnerType, ownerId: string) {
  return useQuery({
    queryKey: valuesKey(ownerType, ownerId),
    queryFn: () => adminClient.customFields(ownerType, ownerId).list({ limit: 100 }),
    enabled: !!ownerId,
  })
}

export function useCustomFieldDefinitions(resourceType: string) {
  return useQuery({
    queryKey: definitionsKey(resourceType),
    queryFn: () =>
      adminClient.customFieldDefinitions.list({
        limit: 100,
        resource_type_eq: resourceType,
      }),
    enabled: !!resourceType,
  })
}

export function useCreateCustomField(ownerType: CustomFieldOwnerType, ownerId: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (params: CustomFieldCreateParams) =>
      adminClient.customFields(ownerType, ownerId).create(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: valuesKey(ownerType, ownerId) })
    },
  })
}

export function useUpdateCustomField(ownerType: CustomFieldOwnerType, ownerId: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, ...params }: { id: string } & CustomFieldUpdateParams) =>
      adminClient.customFields(ownerType, ownerId).update(id, params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: valuesKey(ownerType, ownerId) })
    },
  })
}

export function useDeleteCustomField(ownerType: CustomFieldOwnerType, ownerId: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => adminClient.customFields(ownerType, ownerId).delete(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: valuesKey(ownerType, ownerId) })
    },
  })
}

export function useCustomFieldDefinition(id: string | undefined) {
  return useQuery({
    queryKey: id ? definitionByIdKey(id) : [...customFieldDefinitionsRootKey, 'id', 'noop'],
    queryFn: () => adminClient.customFieldDefinitions.get(id as string),
    enabled: !!id,
  })
}

/**
 * Settings-page variant — no `resourceType` argument. Invalidates the root
 * key, which covers every per-resource and per-id definition query.
 *
 * Toast + 422 handling come for free via `useResourceMutation`: validation
 * errors surface inline through `mapSpreeErrorsToForm`, everything else
 * (network, 5xx) shows a toast.
 */
export function useCreateCustomFieldDefinitionForSettings() {
  return useResourceMutation<CustomFieldDefinition, Error, CustomFieldDefinitionCreateParams>({
    mutationFn: (params) => adminClient.customFieldDefinitions.create(params),
    invalidate: [customFieldDefinitionsRootKey],
    successMessage: i18n.t('admin.custom_field_definitions.messages.created'),
    errorMessage: i18n.t('admin.custom_field_definitions.errors.failed_to_create'),
  })
}

export function useUpdateCustomFieldDefinitionForSettings(id: string) {
  return useResourceMutation<CustomFieldDefinition, Error, CustomFieldDefinitionUpdateParams>({
    mutationFn: (params) => adminClient.customFieldDefinitions.update(id, params),
    invalidate: [customFieldDefinitionsRootKey, definitionByIdKey(id)],
    successMessage: i18n.t('admin.custom_field_definitions.messages.updated'),
    errorMessage: i18n.t('admin.custom_field_definitions.errors.failed_to_update'),
  })
}

export function useDeleteCustomFieldDefinitionForSettings() {
  const queryClient = useQueryClient()
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.customFieldDefinitions.delete(id),
    invalidate: [customFieldDefinitionsRootKey],
    successMessage: i18n.t('admin.custom_field_definitions.messages.deleted'),
    errorMessage: i18n.t('admin.custom_field_definitions.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: definitionByIdKey(id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Resource-scoped create — pins invalidation to a single `resourceType` so the
// inline custom-fields card's definitions query re-validates the moment a field
// is created in place (the create-definition sheet on a record detail page).
// ---------------------------------------------------------------------------

export function useCreateCustomFieldDefinition(resourceType: string) {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (params: CustomFieldDefinitionCreateParams) =>
      adminClient.customFieldDefinitions.create(params),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: definitionsKey(resourceType) })
      queryClient.invalidateQueries({ queryKey: customFieldDefinitionsRootKey })
    },
  })
}
