// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ShippingMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
});

export type ShippingMethod = z.infer<typeof ShippingMethodSchema>;
