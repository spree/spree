import type {
  CompanyParams,
  TaxExemptionCertificateParams,
  TaxIdentifierParams,
} from '@spree/admin-sdk'
import { blankToNull } from '@spree/dashboard-core'
import { requiredMessage } from '@spree/dashboard-ui'
import { z } from 'zod/v4'

export const COMPANY_KINDS = ['company', 'division'] as const

export const companyFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
})

export type CompanyFormValues = z.infer<typeof companyFormSchema>

export const COMPANY_DEFAULTS: CompanyFormValues = { name: '' }

export function companyValuesToParams(values: CompanyFormValues): CompanyParams {
  return {
    name: values.name,
  }
}

// A sub-unit is created in place under its parent: name + kind only — the
// rest lives on its own page.
export const companyChildFormSchema = z.object({
  name: z.string().min(1, { error: requiredMessage('name') }),
  kind: z.enum(COMPANY_KINDS),
})

export type CompanyChildFormValues = z.infer<typeof companyChildFormSchema>

export const COMPANY_CHILD_DEFAULTS: CompanyChildFormValues = { name: '', kind: 'division' }

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
  country_code: z.string().optional(),
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
  country_code: '',
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
    country_code: blankToNull(values.country_code),
    state_code: blankToNull(values.state_code),
    issued_at: blankToNull(values.issued_at),
    expires_at: blankToNull(values.expires_at),
    issuing_authority: blankToNull(values.issuing_authority),
    ...(values.document_signed_id ? { document: values.document_signed_id } : {}),
  }
}
