// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PublicationSchema = z.object({
  id: z.string(),
  published_at: z.string().nullable(),
  unpublished_at: z.string().nullable(),
  channel_id: z.string(),
});

export type Publication = z.infer<typeof PublicationSchema>;
