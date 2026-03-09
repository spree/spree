// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const DigitalSchema = z.object({
  id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  variant_id: z.string().nullable(),
});

export type Digital = z.infer<typeof DigitalSchema>;
