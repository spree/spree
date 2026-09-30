// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxExemptionCertificateSchema = z.object({
  id: z.string(),
  certificate_number: z.string(),
  reason_code: z.string(),
  status: z.string(),
  issuing_authority: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  issued_at: z.string(),
  expires_at: z.string(),
  verified_at: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  company_id: z.string(),
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
