// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const SellerBalanceSchema = z.object({
  currency: z.string(),
  settlement_currency: z.string(),
  converted: z.boolean(),
  seller_id: z.string(),
  earned: z.string(),
  pending: z.string(),
  payable: z.string(),
  paid: z.string(),
  balance: z.string(),
});

export type SellerBalance = z.infer<typeof SellerBalanceSchema>;
