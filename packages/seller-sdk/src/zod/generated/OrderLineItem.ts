// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const OrderLineItemSchema = z.object({
  id: z.string(),
  name: z.string(),
  options_text: z.string().nullable(),
  quantity: z.number(),
  currency: z.string(),
  price: z.string().nullable(),
  display_price: z.string().nullable(),
  discounted_amount: z.string().nullable(),
  display_discounted_amount: z.string().nullable(),
  total: z.string().nullable(),
  display_total: z.string().nullable(),
  variant_id: z.string().nullable(),
  sku: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
});

export type OrderLineItem = z.infer<typeof OrderLineItemSchema>;
