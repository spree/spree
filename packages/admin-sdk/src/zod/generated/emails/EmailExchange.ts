// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailParcelItemSchema } from './EmailParcelItem';
import { EmailReplacementItemSchema } from './EmailReplacementItem';
import { EmailStockLocationSchema } from './EmailStockLocation';

export const EmailExchangeSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  cancelable: z.boolean(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  price_difference: z.string().nullable(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  fulfilled_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  items: z.array(EmailParcelItemSchema),
  replacements: z.array(EmailReplacementItemSchema),
  stock_location: EmailStockLocationSchema,
  memo: z.string().nullable(),
  reason_name: z.string().nullable(),
});

export type EmailExchange = z.infer<typeof EmailExchangeSchema>;
