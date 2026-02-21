// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreLocaleSchema = z.object({
  code: z.string(),
  name: z.string(),
});

export type StoreLocale = z.infer<typeof StoreLocaleSchema>;
