// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const ReturnLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  received_quantity: z.number(),
  resellable: z.boolean(),
  pre_tax_amount: z.string(),
  display_pre_tax_amount: z.string(),
  included_tax_total: z.string(),
  additional_tax_total: z.string(),
  tax_total: z.string(),
  display_tax_total: z.string(),
  refund_amount: z.string(),
  display_refund_amount: z.string(),
  variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_item_id: z.string().nullable(),
  variant: VariantSchema.optional(),
  name: z.string().nullable(),
});

export type ReturnLineItem = z.infer<typeof ReturnLineItemSchema>;
