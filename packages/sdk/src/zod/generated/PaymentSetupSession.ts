// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { PaymentMethodSchema } from './PaymentMethod';

export const PaymentSetupSessionSchema = z.object({
  id: z.string(),
  status: z.string(),
  external_id: z.string().nullable(),
  external_client_secret: z.string().nullable(),
  external_data: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
  payment_method_id: z.string().nullable(),
  payment_source_id: z.string().nullable(),
  payment_source_type: z.string().nullable(),
  customer_id: z.string().nullable(),
  payment_method: PaymentMethodSchema,
});

export type PaymentSetupSession = z.infer<typeof PaymentSetupSessionSchema>;
