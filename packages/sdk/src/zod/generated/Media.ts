// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MediaSchema = z.object({
  id: z.string(),
  product_id: z.string().nullable(),
  variant_ids: z.array(z.string()),
  position: z.number(),
  alt: z.string().nullable(),
  media_type: z.string(),
  focal_point_x: z.number().nullable(),
  focal_point_y: z.number().nullable(),
  external_video_url: z.string().nullable(),
  original_url: z.string().nullable(),
  mini_url: z.string().nullable(),
  small_url: z.string().nullable(),
  medium_url: z.string().nullable(),
  large_url: z.string().nullable(),
  xlarge_url: z.string().nullable(),
  og_image_url: z.string().nullable(),
});

export type Media = z.infer<typeof MediaSchema>;
