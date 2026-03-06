// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreTaxCategorySchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type StoreTaxCategory = z.infer<typeof StoreTaxCategorySchema>;
