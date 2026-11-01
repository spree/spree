// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const InvoiceSchema = z.object({
  id: z.string(),
  kind: z.string(),
  number: z.string(),
  currency: z.string(),
  issued_on: z.string(),
  supplied_on: z.string().nullable(),
  total: z.string(),
  net_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  original_invoice_id: z.string().nullable(),
  issuer_type: z.string(),
  issuer_name: z.string().nullable(),
  file_filename: z.string().nullable(),
  file_byte_size: z.number().nullable(),
  file_content_type: z.string().nullable(),
  download_url: z.string().nullable(),
  source: z.string(),
  external_reference: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  sent_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  order_id: z.string().nullable(),
  seller_payout_id: z.string().nullable(),
  issuer_id: z.string(),
  order_number: z.string().nullable(),
  can_be_deleted: z.boolean(),
});

export type Invoice = z.infer<typeof InvoiceSchema>;
