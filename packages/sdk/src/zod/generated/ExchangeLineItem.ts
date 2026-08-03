// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const ExchangeLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  received_quantity: z.number(),
  resellable: z.boolean(),
  original_price: z.string(),
  new_variant_price: z.string(),
  price_difference: z.string(),
  original_variant_id: z.string().nullable(),
  new_variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_item_id: z.string().nullable(),
  original_variant: VariantSchema.optional(),
  new_variant: VariantSchema.optional(),
});

export type ExchangeLineItem = z.infer<typeof ExchangeLineItemSchema>;
