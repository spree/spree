// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const MediaEventSchema = z.object({
  id: z.string(),
  viewable_id: z.string(),
  viewable_type: z.string(),
  media_type: z.string(),
  position: z.number().nullable(),
  alt: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type MediaEvent = z.infer<typeof MediaEventSchema>;
