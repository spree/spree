// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PaymentMethodSchema } from './PaymentMethod';

export const PaymentSchema = z.object({
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
  source_id: z.string().nullable(),
  source: z.any(),
  payment_method: PaymentMethodSchema,
});

export type Payment = z.infer<typeof PaymentSchema>;
