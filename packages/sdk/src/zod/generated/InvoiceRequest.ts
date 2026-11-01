// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const InvoiceRequestSchema = z.object({
  id: z.string(),
  status: z.string(),
  company_name: z.string().nullable(),
  tax_id: z.string().nullable(),
  order_id: z.string(),
  invoice_id: z.string().nullable(),
});

export type InvoiceRequest = z.infer<typeof InvoiceRequestSchema>;
