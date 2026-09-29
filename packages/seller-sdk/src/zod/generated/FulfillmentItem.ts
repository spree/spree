// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const FulfillmentItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  line_item_id: z.string().nullable(),
  variant_id: z.string().nullable(),
  name: z.string().nullable(),
  sku: z.string().nullable(),
  options_text: z.string().nullable(),
});

export type FulfillmentItem = z.infer<typeof FulfillmentItemSchema>;
