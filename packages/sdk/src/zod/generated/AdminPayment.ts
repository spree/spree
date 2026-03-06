// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePaymentMethodSchema } from './StorePaymentMethod';

export const AdminPaymentSchema = z.object({
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
  payment_method: StorePaymentMethodSchema,
  metadata: z.record(z.string(), z.unknown()).nullable(),
  captured_amount: z.string(),
  order_id: z.string().nullable(),
});

export type AdminPayment = z.infer<typeof AdminPaymentSchema>;
