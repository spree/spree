// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { VariantSchema } from './Variant';

export const ClaimLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  send_replacement: z.boolean(),
  description: z.string().nullable(),
  refund_amount: z.string(),
  paid_amount: z.string(),
  pre_tax_amount: z.string(),
  included_tax_total: z.string(),
  additional_tax_total: z.string(),
  tax_total: z.string(),
  display_refund_amount: z.string(),
  variant_id: z.string().nullable(),
  replacement_variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  variant: VariantSchema.optional(),
});

export type ClaimLineItem = z.infer<typeof ClaimLineItemSchema>;
