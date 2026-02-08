// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreShippingMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
});

export type StoreShippingMethod = z.infer<typeof StoreShippingMethodSchema>;
