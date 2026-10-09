// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentSplitSchema = z.object({
  id: z.string(),
  currency: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  authorized_amount: z.string(),
  captured_amount: z.string(),
  refunded_amount: z.string(),
  claimed_amount: z.string(),
  net_captured_amount: z.string(),
  refundable_amount: z.string(),
  payment_id: z.string(),
  payment_number: z.string().nullable(),
  order_id: z.string(),
  order_number: z.string().nullable(),
});

export type PaymentSplit = z.infer<typeof PaymentSplitSchema>;
