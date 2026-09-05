// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PromotionSchema = z.object({
  id: z.string(),
  name: z.string(),
  description: z.string().nullable(),
  code: z.string().nullable(),
});

export type Promotion = z.infer<typeof PromotionSchema>;
