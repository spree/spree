// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const StoreGiftCardSchema = z.object({
  id: z.string(),
  code: z.string(),
  state: z.string(),
  currency: z.string(),
  amount: z.number(),
  amount_used: z.number(),
  amount_authorized: z.number(),
  amount_remaining: z.number(),
  display_amount: z.string(),
  display_amount_used: z.string(),
  display_amount_remaining: z.string(),
  expires_at: z.string().nullable(),
  redeemed_at: z.string().nullable(),
  expired: z.boolean(),
  active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string(),
});

export type StoreGiftCard = z.infer<typeof StoreGiftCardSchema>;
