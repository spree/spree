// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AllowedOriginSchema = z.object({
  id: z.string(),
  origin: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AllowedOrigin = z.infer<typeof AllowedOriginSchema>;
