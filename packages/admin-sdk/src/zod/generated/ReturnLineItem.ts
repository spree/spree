// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { LineItemSchema } from './LineItem';
import { VariantSchema } from './Variant';

export const ReturnLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  received_quantity: z.number(),
  resellable: z.boolean(),
  pre_tax_amount: z.string(),
  display_pre_tax_amount: z.string(),
  variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_item_id: z.string().nullable(),
  variant: z.lazy(() => VariantSchema).optional(),
  created_at: z.string(),
  updated_at: z.string(),
  line_item: LineItemSchema.optional(),
});

export type ReturnLineItem = z.infer<typeof ReturnLineItemSchema>;
