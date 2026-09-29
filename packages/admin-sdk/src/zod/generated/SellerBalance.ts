// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerBalanceSchema = z.object({
  currency: z.string(),
  settlement_currency: z.string(),
  converted: z.boolean(),
  seller_id: z.string(),
  earned: z.string(),
  display_earned: z.string(),
  payable: z.string(),
  display_payable: z.string(),
  paid: z.string(),
  display_paid: z.string(),
  balance: z.string(),
  display_balance: z.string(),
  pending: z.string(),
  display_pending: z.string(),
});

export type SellerBalance = z.infer<typeof SellerBalanceSchema>;
