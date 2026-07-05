// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RefundSchema = z.object({
  id: z.string(),
  transaction_id: z.string().nullable(),
  amount: z.string().nullable(),
  payment_id: z.string().nullable(),
  refund_reason_id: z.string().nullable(),
  reimbursement_id: z.string().nullable(),
});

export type Refund = z.infer<typeof RefundSchema>;
