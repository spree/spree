// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailParcelItemSchema = z.object({
  id: z.string(),
  url: z.string().nullable(),
  image_url: z.string().nullable(),
  name: z.string(),
  quantity: z.number(),
  sku: z.string().nullable(),
  options_text: z.string().nullable(),
  price: z.string(),
  amount: z.string(),
  display_price: z.string(),
  display_amount: z.string(),
});

export type EmailParcelItem = z.infer<typeof EmailParcelItemSchema>;
