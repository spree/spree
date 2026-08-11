// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ClaimReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
});

export type ClaimReason = z.infer<typeof ClaimReasonSchema>;
