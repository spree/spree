// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminRefundSchema = z.object({
  id: z.string(),
  transaction_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string().nullable(),
  payment_id: z.string().nullable(),
  refund_reason_id: z.string().nullable(),
  reimbursement_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()).nullable(),
});

export type AdminRefund = z.infer<typeof AdminRefundSchema>;
