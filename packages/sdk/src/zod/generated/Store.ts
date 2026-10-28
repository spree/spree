// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreSchema = z.object({
  id: z.string(),
  name: z.string(),
  seo_title: z.string().nullable(),
  meta_description: z.string().nullable(),
});

export type Store = z.infer<typeof StoreSchema>;
