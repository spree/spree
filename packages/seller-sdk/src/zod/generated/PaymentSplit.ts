// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentSplitSchema = z.object({
  id: z.string(),
  currency: z.string(),
  created_at: z.string(),
  authorized_amount: z.string(),
  captured_amount: z.string(),
  refunded_amount: z.string(),
  claimed_amount: z.string(),
  net_captured_amount: z.string(),
  refundable_amount: z.string(),
});

export type PaymentSplit = z.infer<typeof PaymentSplitSchema>;
