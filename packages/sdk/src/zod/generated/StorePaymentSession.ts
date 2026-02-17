// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StorePaymentSchema } from './StorePayment';
import { StorePaymentMethodSchema } from './StorePaymentMethod';

export const StorePaymentSessionSchema = z.object({
  id: z.string(),
  status: z.string(),
  currency: z.string(),
  external_id: z.string(),
  external_data: z.record(z.string(), z.unknown()),
  customer_external_id: z.string().nullable(),
  expires_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  amount: z.string(),
  payment_method_id: z.string(),
  order_id: z.string(),
  payment_method: StorePaymentMethodSchema,
  payment: StorePaymentSchema.optional(),
});

export type StorePaymentSession = z.infer<typeof StorePaymentSessionSchema>;
