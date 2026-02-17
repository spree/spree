// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePaymentSourceSchema = z.object({
  id: z.string(),
  gateway_payment_profile_id: z.string().nullable(),
  public_metadata: z.record(z.string(), z.unknown()).nullable(),
});

export type StorePaymentSource = z.infer<typeof StorePaymentSourceSchema>;
