import type {
  CompanyLocationParams,
  CompanyParams,
  TaxExemptionCertificateParams,
  TaxIdentifierParams,
} from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const companyFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  external_id: z.string().optional(),
})

export type CompanyFormValues = z.infer<typeof companyFormSchema>

export const COMPANY_DEFAULTS: CompanyFormValues = { name: '', external_id: '' }

export function companyValuesToParams(values: CompanyFormValues): CompanyParams {
  return {
    name: values.name,
    external_id: blankToNull(values.external_id),
  }
}

const addressSchema = z.object({
  first_name: z.string().optional(),
  last_name: z.string().optional(),
  company: z.string().optional(),
  address1: z.string().optional(),
  address2: z.string().optional(),
  city: z.string().optional(),
  postal_code: z.string().optional(),
  phone: z.string().optional(),
  country_iso: z.string().optional(),
  state_abbr: z.string().optional(),
})

export const companyLocationFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  external_id: z.string().optional(),
  billing_address: addressSchema,
  // Kept separate from billing rather than merged on submit, so a branch that
  // ships somewhere other than it is invoiced stays expressible.
  shipping_address: addressSchema,
  // Form-only: when set, the billing address is copied over the shipping one
  // on submit. Never sent to the API, which always takes both addresses.
  shipping_same_as_billing: z.boolean(),
})

export type CompanyLocationFormValues = z.infer<typeof companyLocationFormSchema>

const EMPTY_ADDRESS = {
  first_name: '',
  last_name: '',
  company: '',
  address1: '',
  address2: '',
  city: '',
  postal_code: '',
  phone: '',
  country_iso: '',
  state_abbr: '',
}

export const COMPANY_LOCATION_DEFAULTS: CompanyLocationFormValues = {
  name: '',
  external_id: '',
  billing_address: { ...EMPTY_ADDRESS },
  shipping_address: { ...EMPTY_ADDRESS },
  shipping_same_as_billing: true,
}

export function companyLocationValuesToParams(
  values: CompanyLocationFormValues,
): CompanyLocationParams {
  const billing = values.billing_address
  const shipping = values.shipping_same_as_billing ? { ...billing } : values.shipping_address

  return {
    name: values.name,
    external_id: blankToNull(values.external_id),
    // A branch may have no address at all, but an address that exists must be
    // complete — so an untouched fieldset is omitted rather than sent empty,
    // which would fail the address record's own validations.
    ...(isAddressBlank(billing) ? {} : { billing_address: billing }),
    ...(isAddressBlank(shipping) ? {} : { shipping_address: shipping }),
  }
}

function isAddressBlank(address: Record<string, string | undefined>): boolean {
  return Object.values(address).every((value) => !value?.trim())
}

/**
 * Whether a saved branch's two addresses are the same, deciding how the edit
 * form opens. Compared field by field because they are separate records.
 */
export function addressesMatch(
  billing: Record<string, unknown> | null | undefined,
  shipping: Record<string, unknown> | null | undefined,
): boolean {
  if (!billing || !shipping) return false

  return ADDRESS_COMPARISON_KEYS.every((key) => (billing[key] ?? '') === (shipping[key] ?? ''))
}

const ADDRESS_COMPARISON_KEYS = [
  'first_name',
  'last_name',
  'company',
  'address1',
  'address2',
  'city',
  'postal_code',
  'phone',
  'country_iso',
  'state_abbr',
] as const

export const taxIdentifierFormSchema = z.object({
  kind: z.string().min(1, { error: requiredMessage('tax_identifier.kind') }),
  value: z.string().min(1, { error: requiredMessage('tax_identifier.value') }),
})

export type TaxIdentifierFormValues = z.infer<typeof taxIdentifierFormSchema>

export const TAX_IDENTIFIER_DEFAULTS: TaxIdentifierFormValues = { kind: '', value: '' }

export function taxIdentifierValuesToParams(values: TaxIdentifierFormValues): TaxIdentifierParams {
  return { kind: values.kind, value: values.value }
}

/**
 * The registration kinds core ships strings for. Any string is accepted by the
 * API — what a kind means is decided by whichever validator is registered for
 * it — so the merchant can type their own.
 */
export const TAX_IDENTIFIER_KINDS = ['eu_vat', 'gb_vat', 'ch_vat', 'au_abn', 'us_ein'] as const

export const taxExemptionCertificateFormSchema = z.object({
  certificate_number: z.string().min(1, { error: requiredMessage('certificate_number') }),
  reason_code: z.string().min(1, { error: requiredMessage('reason_code') }),
  country_iso: z.string().optional(),
  state_code: z.string().optional(),
  issued_at: z.string().optional(),
  expires_at: z.string().optional(),
  issuing_authority: z.string().optional(),
  document_signed_id: z.string().nullable().optional(),
})

export type TaxExemptionCertificateFormValues = z.infer<typeof taxExemptionCertificateFormSchema>

export const TAX_EXEMPTION_CERTIFICATE_DEFAULTS: TaxExemptionCertificateFormValues = {
  certificate_number: '',
  reason_code: '',
  country_iso: '',
  state_code: '',
  issued_at: '',
  expires_at: '',
  issuing_authority: '',
  document_signed_id: null,
}

/**
 * Reason codes become the tax provider's entity use code. These are the ones in
 * common circulation; the field stays free text because the set is the
 * provider's, not Spree's.
 */
export const TAX_EXEMPTION_REASON_CODES = [
  'resale',
  'government',
  'charitable',
  'educational',
  'manufacturing',
  'agricultural',
] as const

export function taxExemptionCertificateValuesToParams(
  values: TaxExemptionCertificateFormValues,
): TaxExemptionCertificateParams {
  return {
    certificate_number: values.certificate_number,
    reason_code: values.reason_code,
    country_iso: blankToNull(values.country_iso),
    state_code: blankToNull(values.state_code),
    issued_at: blankToNull(values.issued_at),
    expires_at: blankToNull(values.expires_at),
    issuing_authority: blankToNull(values.issuing_authority),
    ...(values.document_signed_id ? { document: values.document_signed_id } : {}),
  }
}
