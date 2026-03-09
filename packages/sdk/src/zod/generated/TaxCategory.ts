// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const TaxCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type TaxCategory = z.infer<typeof TaxCategorySchema>;
