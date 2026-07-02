// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const GiftCardSchema = z.object({
  id: z.string(),
  code: z.string(),
  status: z.string(),
  currency: z.string(),
  amount: z.string().nullable(),
  amount_used: z.string().nullable(),
  amount_authorized: z.string().nullable(),
  amount_remaining: z.string().nullable(),
  display_amount: z.string().nullable(),
  display_amount_used: z.string().nullable(),
  display_amount_remaining: z.string().nullable(),
  expires_at: z.string().nullable(),
  redeemed_at: z.string().nullable(),
  expired: z.boolean(),
  active: z.boolean(),
});

export type GiftCard = z.infer<typeof GiftCardSchema>;
