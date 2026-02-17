// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePaymentMethodSchema } from './StorePaymentMethod';

export const StorePaymentSchema = z.object({
  id: z.string(),
  payment_method_id: z.string(),
  state: z.string(),
  response_code: z.string().nullable(),
  number: z.string(),
  amount: z.string(),
  display_amount: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  source_type: z.string().nullable(),
  source: z.any(),
  payment_method: StorePaymentMethodSchema,
});

export type StorePayment = z.infer<typeof StorePaymentSchema>;
