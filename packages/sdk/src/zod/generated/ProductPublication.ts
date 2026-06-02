// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ProductPublicationSchema = z.object({
  id: z.string(),
  published_at: z.string().nullable(),
  unpublished_at: z.string().nullable(),
  product_id: z.string(),
  channel_id: z.string(),
});

export type ProductPublication = z.infer<typeof ProductPublicationSchema>;
