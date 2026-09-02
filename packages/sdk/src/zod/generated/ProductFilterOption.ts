// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { ProductFilterOptionValueSchema } from './ProductFilterOptionValue';

export const ProductFilterOptionSchema = z.object({
  id: z.string(),
  type: z.any(),
  name: z.string(),
  label: z.string(),
  kind: z.string(),
  options: z.array(ProductFilterOptionValueSchema),
});

export type ProductFilterOption = z.infer<typeof ProductFilterOptionSchema>;
