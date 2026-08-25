import type {
  Company,
  CompanyAddress,
  CompanyAddressParams,
  CompanyInvitation,
  CompanyMembership,
  CompanyMembershipCreateParams,
  CompanyParams,
  TaxExemptionCertificate,
  TaxExemptionCertificateParams,
  TaxIdentifier,
  TaxIdentifierParams,
} from '@spree/admin-sdk'
import {
  adminClient,
  useResourceKey,
  useResourceKeyBuilder,
  useResourceMutation,
} from '@spree/dashboard-core'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import i18n from 'i18next'

export function useCompany(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('companies', id ?? 'noop'),
    queryFn: () => adminClient.companies.get(id as string),
    enabled: !!id,
  })
}

/** One level of the tree: roots when `parentId` is undefined, else children. */
export function useCompanyChildren(parentId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('companies', 'tree', parentId ?? 'roots', `${page}:${limit}`),
    queryFn: () =>
      adminClient.companies.list(
        parentId
          ? { page, limit, parent_id_eq: parentId, sort: 'name' }
          : { page, limit, parent_id_null: 1, sort: 'name' },
      ),
    placeholderData: (previous) => previous,
  })
}

export function useCreateCompany() {
  return useResourceMutation<Company, Error, CompanyParams>({
    mutationFn: (params) => adminClient.companies.create(params),
    invalidate: [['companies']],
    successMessage: i18n.t('admin.companies.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCompany(id: string) {
  return useResourceMutation<Company, Error, CompanyParams>({
    mutationFn: (params) => adminClient.companies.update(id, params),
    invalidate: [['companies'], ['companies', id]],
    successMessage: i18n.t('admin.companies.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCompany() {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companies.delete(id),
    invalidate: [['companies']],
    successMessage: i18n.t('admin.companies.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('companies', id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Address book — entries listed and created under their node, addressed by id
// ---------------------------------------------------------------------------

export function useCompanyAddresses(companyId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'addresses', `${page}:${limit}`),
    queryFn: () => adminClient.companies.addresses.list(companyId as string, { page, limit }),
    enabled: !!companyId,
    placeholderData: (previous) => previous,
  })
}

/** Adds a labeled address to the node; the address row is owned by the entry. */
export function useCreateCompanyAddress(companyId: string) {
  return useResourceMutation<CompanyAddress, Error, CompanyAddressParams>({
    mutationFn: (params) => adminClient.companies.addresses.create(companyId, params),
    invalidate: [['companies', companyId, 'addresses']],
    successMessage: i18n.t('admin.company_addresses.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/** Edits an entry in place — the address row is updated, never replaced. */
export function useUpdateCompanyAddress(companyId: string) {
  return useResourceMutation<CompanyAddress, Error, { id: string; params: CompanyAddressParams }>({
    mutationFn: ({ id, params }) => adminClient.companyAddresses.update(id, params),
    invalidate: [['companies', companyId, 'addresses']],
    successMessage: i18n.t('admin.company_addresses.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

/** Removes an entry and the address row it owned. */
export function useDeleteCompanyAddress(companyId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companyAddresses.delete(id),
    invalidate: [['companies', companyId, 'addresses']],
    successMessage: i18n.t('admin.company_addresses.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

// ---------------------------------------------------------------------------
// Members — standing over the node and its subtree
// ---------------------------------------------------------------------------

export function useCompanyMemberships(companyId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'memberships', `${page}:${limit}`),
    queryFn: () => adminClient.companies.memberships.list(companyId as string, { page, limit }),
    enabled: !!companyId,
    placeholderData: (previous) => previous,
  })
}

/**
 * Adding by email does the right thing server-side — the result is a
 * membership for an existing customer, an invitation otherwise. Both lists
 * refresh because either may have grown.
 */
export function useAddCompanyMember(companyId: string) {
  return useResourceMutation<
    CompanyMembership | CompanyInvitation,
    Error,
    CompanyMembershipCreateParams
  >({
    mutationFn: (params) => adminClient.companies.memberships.create(companyId, params),
    invalidate: [
      ['companies', companyId, 'memberships'],
      ['companies', companyId, 'invitations'],
    ],
    successMessage: i18n.t('admin.company_memberships.messages.added'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/** Withdraws a member's standing; the customer account is untouched. */
export function useDeleteCompanyMembership(companyId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companyMemberships.delete(id),
    invalidate: [['companies', companyId, 'memberships']],
    successMessage: i18n.t('admin.company_memberships.messages.removed'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

// ---------------------------------------------------------------------------
// Invitations — the pending state for not-yet-registered emails
// ---------------------------------------------------------------------------

export function useCompanyInvitations(companyId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'invitations', `${page}:${limit}`),
    queryFn: () => adminClient.companies.invitations.list(companyId as string, { page, limit }),
    enabled: !!companyId,
    placeholderData: (previous) => previous,
  })
}

/** Revokes a pending invitation, so its emailed token stops resolving. */
export function useRevokeCompanyInvitation(companyId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companyInvitations.delete(id),
    invalidate: [['companies', companyId, 'invitations']],
    successMessage: i18n.t('admin.company_invitations.messages.revoked'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

// ---------------------------------------------------------------------------
// Tax identifiers — the registration that goes on the business's invoices
// ---------------------------------------------------------------------------

export function useCompanyTaxIdentifiers(companyId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'tax-identifiers'),
    queryFn: () => adminClient.companies.taxIdentifiers.list(companyId as string),
    enabled: !!companyId,
  })
}

export function useCreateCompanyTaxIdentifier(companyId: string) {
  return useResourceMutation<TaxIdentifier, Error, TaxIdentifierParams>({
    mutationFn: (params) => adminClient.companies.taxIdentifiers.create(companyId, params),
    invalidate: [['companies', companyId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

/**
 * Which row is being edited is decided by the panel at call time, so the id
 * travels with the variables rather than being bound when the hook is created.
 */
export function useUpdateCompanyTaxIdentifier(companyId: string) {
  return useResourceMutation<TaxIdentifier, Error, { id: string; params: TaxIdentifierParams }>({
    mutationFn: ({ id, params }) =>
      adminClient.companies.taxIdentifiers.update(companyId, id, params),
    invalidate: [['companies', companyId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCompanyTaxIdentifier(companyId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companies.taxIdentifiers.delete(companyId, id),
    invalidate: [['companies', companyId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}

/**
 * Asks the registered validator to check the number with the tax authority.
 * The verdict comes back on the row, so the panel re-reads rather than
 * tracking it locally.
 */
export function useValidateCompanyTaxIdentifier(companyId: string) {
  return useResourceMutation<TaxIdentifier, Error, string>({
    mutationFn: (id) => adminClient.companies.taxIdentifiers.validate(companyId, id),
    invalidate: [['companies', companyId, 'tax-identifiers']],
    successMessage: i18n.t('admin.tax_identifiers.messages.validation_requested'),
    errorMessage: i18n.t('admin.tax_identifiers.messages.validation_failed'),
  })
}

// ---------------------------------------------------------------------------
// Exemption certificates
// ---------------------------------------------------------------------------

export function useTaxExemptionCertificates(companyId: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'tax-exemption-certificates'),
    queryFn: () => adminClient.companies.taxExemptionCertificates.list(companyId as string),
    enabled: !!companyId,
  })
}

export function useCreateTaxExemptionCertificate(companyId: string) {
  return useResourceMutation<TaxExemptionCertificate, Error, TaxExemptionCertificateParams>({
    mutationFn: (params) =>
      adminClient.companies.taxExemptionCertificates.create(companyId, params),
    invalidate: [['companies', companyId, 'tax-exemption-certificates']],
    successMessage: i18n.t('admin.tax_exemption_certificates.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useVerifyTaxExemptionCertificate(companyId: string) {
  return useResourceMutation<TaxExemptionCertificate, Error, string>({
    mutationFn: (id) => adminClient.companies.taxExemptionCertificates.verify(companyId, id),
    invalidate: [['companies', companyId, 'tax-exemption-certificates']],
    successMessage: i18n.t('admin.tax_exemption_certificates.messages.verified'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useRevokeTaxExemptionCertificate(companyId: string) {
  return useResourceMutation<TaxExemptionCertificate, Error, string>({
    mutationFn: (id) => adminClient.companies.taxExemptionCertificates.revoke(companyId, id),
    invalidate: [['companies', companyId, 'tax-exemption-certificates']],
    successMessage: i18n.t('admin.tax_exemption_certificates.messages.revoked'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteTaxExemptionCertificate(companyId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companies.taxExemptionCertificates.delete(companyId, id),
    invalidate: [['companies', companyId, 'tax-exemption-certificates']],
    successMessage: i18n.t('admin.tax_exemption_certificates.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
  })
}
