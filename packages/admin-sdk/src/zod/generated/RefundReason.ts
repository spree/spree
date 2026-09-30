// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const RefundReasonSchema = z.object({
  id: z.string(),
  name: z.string(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
  can_be_deleted: z.boolean(),
});

export type RefundReason = z.infer<typeof RefundReasonSchema>;
