// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const AdminMetafieldSchema = z.object({
  id: z.string(),
  name: z.string(),
  type: z.string(),
  key: z.string(),
  value: z.any(),
  display_on: z.string(),
});

export type AdminMetafield = z.infer<typeof AdminMetafieldSchema>;
