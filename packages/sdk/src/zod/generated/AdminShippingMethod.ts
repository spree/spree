// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminShippingMethodSchema = z.object({
  id: z.string(),
  name: z.string(),
  code: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminShippingMethod = z.infer<typeof AdminShippingMethodSchema>;
