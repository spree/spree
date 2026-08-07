// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const ReturnReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
});

export type ReturnReason = z.infer<typeof ReturnReasonSchema>;
