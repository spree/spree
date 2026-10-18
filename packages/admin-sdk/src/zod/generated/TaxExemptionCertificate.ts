// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { TaxExemptionReasonSchema } from './TaxExemptionReason';

export const TaxExemptionCertificateSchema = z.object({
  id: z.string(),
  certificate_number: z.string(),
  status: z.string(),
  issuing_authority: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  issued_at: z.string().nullable(),
  expires_at: z.string().nullable(),
  verified_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  company_id: z.string(),
  tax_exemption_reason_id: z.string(),
  tax_exemption_reason: TaxExemptionReasonSchema.optional(),
  country_code: z.string().nullable(),
  state_code: z.string().nullable(),
  active: z.boolean(),
  lapsed: z.boolean(),
  can_be_deleted: z.boolean(),
  document_filename: z.string().nullable(),
  document_byte_size: z.number().nullable(),
  document_url: z.string().nullable(),
});

export type TaxExemptionCertificate = z.infer<typeof TaxExemptionCertificateSchema>;
