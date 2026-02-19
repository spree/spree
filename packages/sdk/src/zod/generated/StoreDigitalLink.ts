// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreDigitalLinkSchema = z.object({
  id: z.string(),
  access_counter: z.number(),
  filename: z.string(),
  content_type: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  download_url: z.string(),
  authorizable: z.boolean(),
  expired: z.boolean(),
  access_limit_exceeded: z.boolean(),
});

export type StoreDigitalLink = z.infer<typeof StoreDigitalLinkSchema>;
