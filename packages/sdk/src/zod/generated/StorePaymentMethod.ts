// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StorePaymentMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  type: z.string(),
});

export type StorePaymentMethod = z.infer<typeof StorePaymentMethodSchema>;
