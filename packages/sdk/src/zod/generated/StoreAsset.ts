// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreAssetSchema = z.object({
  id: z.string(),
  viewable_id: z.string(),
  type: z.string().nullable(),
  viewable_type: z.string(),
  position: z.number().nullable(),
  alt: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type StoreAsset = z.infer<typeof StoreAssetSchema>;
