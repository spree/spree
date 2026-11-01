// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { AddressSchema } from './Address';

export const InvoiceRequestSchema = z.object({
  id: z.string(),
  status: z.string(),
  company_name: z.string().nullable(),
  tax_id: z.string().nullable(),
  order_id: z.string(),
  invoice_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  customer_id: z.string().nullable(),
  billing_address: AddressSchema.nullable(),
});

export type InvoiceRequest = z.infer<typeof InvoiceRequestSchema>;
