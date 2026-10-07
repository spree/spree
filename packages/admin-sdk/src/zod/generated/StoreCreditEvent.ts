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
  updated_at: z.string(),
  store_credit_id: z.string(),
  originator_type: z.string().nullable(),
  originator_id: z.string().nullable(),
});

export type StoreCreditEvent = z.infer<typeof StoreCreditEventSchema>;
