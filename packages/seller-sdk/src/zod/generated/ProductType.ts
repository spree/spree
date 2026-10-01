// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductTypeSchema = z.object({
  id: z.string(),
  name: z.string(),
  option_type_labels: z.array(z.string()),
});

export type ProductType = z.infer<typeof ProductTypeSchema>;
