import type {
  Company,
  CompanyContact,
  CompanyContactParams,
  CompanyLocation,
  CompanyLocationParams,
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
// Locations — listed and created under their company, then addressed by id
// ---------------------------------------------------------------------------

export function useCompanyLocations(companyId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey('companies', companyId ?? 'noop', 'locations', `${page}:${limit}`),
    queryFn: () => adminClient.companies.locations.list(companyId as string, { page, limit }),
    enabled: !!companyId,
    placeholderData: (previous) => previous,
  })
}

export function useCompanyLocation(id: string | undefined) {
  return useQuery({
    queryKey: useResourceKey('company-locations', id ?? 'noop'),
    queryFn: () => adminClient.companyLocations.get(id as string),
    enabled: !!id,
  })
}

export function useCreateCompanyLocation(companyId: string) {
  return useResourceMutation<CompanyLocation, Error, CompanyLocationParams>({
    mutationFn: (params) => adminClient.companies.locations.create(companyId, params),
    invalidate: [['companies', companyId, 'locations']],
    successMessage: i18n.t('admin.company_locations.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useUpdateCompanyLocation(id: string, companyId?: string) {
  return useResourceMutation<CompanyLocation, Error, CompanyLocationParams>({
    mutationFn: (params) => adminClient.companyLocations.update(id, params),
    invalidate: [
      ['company-locations', id],
      ...(companyId ? [['companies', companyId, 'locations']] : []),
    ],
    successMessage: i18n.t('admin.company_locations.messages.updated'),
    errorMessage: i18n.t('admin.errors.failed_to_update'),
  })
}

export function useDeleteCompanyLocation(companyId?: string) {
  const queryClient = useQueryClient()
  const buildKey = useResourceKeyBuilder()

  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companyLocations.delete(id),
    invalidate: companyId ? [['companies', companyId, 'locations']] : [],
    successMessage: i18n.t('admin.company_locations.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
    // Drop just this branch's cached detail; invalidating the whole
    // `company-locations` prefix would refetch every branch visited this session.
    onSuccess: (_data, id) => {
      queryClient.removeQueries({ queryKey: buildKey('company-locations', id) })
    },
  })
}

// ---------------------------------------------------------------------------
// Contacts — the buyers authorised to purchase for a branch
// ---------------------------------------------------------------------------

export function useCompanyLocationContacts(locationId: string | undefined, page = 1, limit = 25) {
  return useQuery({
    queryKey: useResourceKey(
      'company-locations',
      locationId ?? 'noop',
      'contacts',
      `${page}:${limit}`,
    ),
    queryFn: () =>
      adminClient.companyLocations.contacts.list(locationId as string, { page, limit }),
    enabled: !!locationId,
    placeholderData: (previous) => previous,
  })
}

export function useCreateCompanyContact(locationId: string) {
  return useResourceMutation<CompanyContact, Error, CompanyContactParams>({
    mutationFn: (params) => adminClient.companyLocations.contacts.create(locationId, params),
    invalidate: [['company-locations', locationId]],
    successMessage: i18n.t('admin.company_contacts.messages.created'),
    errorMessage: i18n.t('admin.errors.failed_to_create'),
  })
}

export function useDeleteCompanyContact(locationId: string) {
  return useResourceMutation<void, Error, string>({
    mutationFn: (id) => adminClient.companyContacts.delete(id),
    invalidate: [['company-locations', locationId]],
    successMessage: i18n.t('admin.company_contacts.messages.deleted'),
    errorMessage: i18n.t('admin.errors.failed_to_delete'),
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
