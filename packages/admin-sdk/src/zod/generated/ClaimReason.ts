// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ClaimReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  can_be_deleted: z.boolean(),
});

export type ClaimReason = z.infer<typeof ClaimReasonSchema>;
