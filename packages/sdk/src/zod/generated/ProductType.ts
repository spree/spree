// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
});

export type ProductType = z.infer<typeof ProductTypeSchema>;
