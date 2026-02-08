// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreImageSchema = z.object({
  id: z.string(),
  viewable_id: z.string(),
  position: z.number(),
  alt: z.string().nullable(),
  viewable_type: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  original_url: z.string().nullable(),
  mini_url: z.string().nullable(),
  small_url: z.string().nullable(),
  medium_url: z.string().nullable(),
  large_url: z.string().nullable(),
  xlarge_url: z.string().nullable(),
  og_image_url: z.string().nullable(),
});

export type StoreImage = z.infer<typeof StoreImageSchema>;
