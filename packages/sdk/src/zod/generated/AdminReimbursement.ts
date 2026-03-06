// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminReimbursementSchema = z.object({
  id: z.string(),
  number: z.string(),
  reimbursement_status: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  total: z.string().nullable(),
  order_id: z.string().nullable(),
  customer_return_id: z.string().nullable(),
});

export type AdminReimbursement = z.infer<typeof AdminReimbursementSchema>;
