// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BulkProductChannelsResultSchema = z.object({
  product_count: z.number(),
  channel_count: z.number(),
  removed: z.number().optional(),
});

export type BulkProductChannelsResult = z.infer<typeof BulkProductChannelsResultSchema>;
