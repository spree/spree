// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const CollectionPublicationSchema = z.object({
  id: z.string(),
  published_at: z.string().nullable(),
  unpublished_at: z.string().nullable(),
  collection_id: z.string(),
  channel_id: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type CollectionPublication = z.infer<typeof CollectionPublicationSchema>;
