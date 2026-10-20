// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const BalanceSchema = z.object({
  currency: z.string(),
  settlement_currency: z.string(),
  converted: z.boolean(),
  earned: z.string(),
  pending: z.string(),
  payable: z.string(),
  paid: z.string(),
  balance: z.string(),
});

export type Balance = z.infer<typeof BalanceSchema>;
