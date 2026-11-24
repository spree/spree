// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const EmailReturnedItemSchema = z.object({
  id: z.string(),
  url: z.string().nullable(),
  image_url: z.string().nullable(),
  name: z.string(),
  quantity: z.number(),
  sku: z.string().nullable(),
  options_text: z.string().nullable(),
  price: z.string(),
  amount: z.string(),
});

export type EmailReturnedItem = z.infer<typeof EmailReturnedItemSchema>;
