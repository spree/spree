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
});

export type Invoice = z.infer<typeof InvoiceSchema>;
