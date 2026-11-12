// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const ReturnLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  received_quantity: z.number(),
  resellable: z.boolean(),
  pre_tax_amount: z.string().nullable(),
  display_pre_tax_amount: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  tax_total: z.string().nullable(),
  display_tax_total: z.string().nullable(),
  refund_amount: z.string().nullable(),
  display_refund_amount: z.string().nullable(),
  variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_item_id: z.string().nullable(),
  variant: VariantSchema.optional(),
});

export type ReturnLineItem = z.infer<typeof ReturnLineItemSchema>;
