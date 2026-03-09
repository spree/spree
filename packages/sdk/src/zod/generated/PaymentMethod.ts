// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  type: z.string(),
  session_required: z.boolean(),
});

export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;
