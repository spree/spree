// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductFilterOptionValueSchema = z.object({
  id: z.string(),
  name: z.string(),
  label: z.string(),
  position: z.number(),
  color_code: z.string().nullable(),
  image_url: z.string().nullable(),
  count: z.number(),
});

export type ProductFilterOptionValue = z.infer<typeof ProductFilterOptionValueSchema>;
