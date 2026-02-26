// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreReturnItemSchema = z.object({
  id: z.string(),
  reception_status: z.string().nullable(),
  acceptance_status: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  pre_tax_amount: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  inventory_unit_id: z.string().nullable(),
  return_authorization_id: z.string().nullable(),
  customer_return_id: z.string().nullable(),
  reimbursement_id: z.string().nullable(),
  exchange_variant_id: z.string().nullable(),
});

export type StoreReturnItem = z.infer<typeof StoreReturnItemSchema>;
