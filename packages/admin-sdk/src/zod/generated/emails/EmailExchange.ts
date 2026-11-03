// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailParcelItemSchema } from './EmailParcelItem';
import { EmailStockLocationSchema } from './EmailStockLocation';

export const EmailExchangeSchema = z.object({
  id: z.string(),
  number: z.string(),
  status: z.string(),
  memo: z.string().nullable(),
  cancelable: z.boolean(),
  order_id: z.string().nullable(),
  reason_id: z.string().nullable(),
  price_difference: z.string().nullable(),
  approved_at: z.string().nullable(),
  received_at: z.string().nullable(),
  fulfilled_at: z.string().nullable(),
  canceled_at: z.string().nullable(),
  items: z.array(EmailParcelItemSchema),
  replacements: z.array(z.object({ name: z.string().nullable(), options_text: z.string().nullable(), quantity: z.number() })),
  stock_location: EmailStockLocationSchema,
  reason_name: z.string().nullable(),
});

export type EmailExchange = z.infer<typeof EmailExchangeSchema>;
