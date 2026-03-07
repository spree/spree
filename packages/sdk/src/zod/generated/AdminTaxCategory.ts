// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminTaxCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
  is_default: z.boolean(),
  tax_code: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type AdminTaxCategory = z.infer<typeof AdminTaxCategorySchema>;
