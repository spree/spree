// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentSourceSchema = z.object({
  id: z.string(),
  gateway_payment_profile_id: z.string().nullable(),
  metadata: z.record(z.string(), z.unknown()),
  created_at: z.string(),
  updated_at: z.string(),
});

export type PaymentSource = z.infer<typeof PaymentSourceSchema>;
