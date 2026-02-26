// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreRefundSchema = z.object({
  id: z.string(),
  transaction_id: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string().nullable(),
  payment_id: z.string().nullable(),
  refund_reason_id: z.string().nullable(),
  reimbursement_id: z.string().nullable(),
});

export type StoreRefund = z.infer<typeof StoreRefundSchema>;
