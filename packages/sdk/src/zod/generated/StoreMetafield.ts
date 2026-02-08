// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreMetafieldSchema = z.object({
  id: z.string(),
  name: z.string(),
  type: z.string(),
  key: z.string(),
  value: z.any(),
});

export type StoreMetafield = z.infer<typeof StoreMetafieldSchema>;
