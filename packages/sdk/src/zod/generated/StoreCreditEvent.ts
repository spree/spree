// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreCreditEventSchema = z.object({
  id: z.string(),
  action: z.string(),
  authorization_code: z.string().nullable(),
  display_action: z.string().nullable(),
  amount: z.string(),
  display_amount: z.string(),
  created_at: z.string(),
});

export type StoreCreditEvent = z.infer<typeof StoreCreditEventSchema>;
