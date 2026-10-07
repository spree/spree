// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
  tax_code: z.string().nullable(),
  description: z.string().nullable(),
  is_default: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type TaxCategory = z.infer<typeof TaxCategorySchema>;
