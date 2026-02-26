// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreDigitalSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  variant_id: z.string().nullable(),
});

export type StoreDigital = z.infer<typeof StoreDigitalSchema>;
