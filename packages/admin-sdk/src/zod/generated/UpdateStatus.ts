// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const UpdateStatusSchema = z.object({
  current_version: z.string(),
  enabled: z.boolean(),
  checked_at: z.string().nullable(),
  update_available: z.boolean(),
  latest_version: z.string().nullable(),
  latest_release_url: z.string().nullable(),
  latest_release_published_at: z.string().nullable(),
});

export type UpdateStatus = z.infer<typeof UpdateStatusSchema>;
