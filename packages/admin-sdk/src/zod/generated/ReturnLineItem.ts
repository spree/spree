// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type ReturnLineItem from '../../types/generated/ReturnLineItem';
import { LineItemSchema } from './LineItem';
import { TaxLineSchema } from './TaxLine';
import { VariantSchema } from './Variant';

export const ReturnLineItemSchema = z.object({
  id: z.string(),
  quantity: z.number(),
  received_quantity: z.number(),
  resellable: z.boolean(),
  pre_tax_amount: z.string(),
  included_tax_total: z.string(),
  additional_tax_total: z.string(),
  tax_total: z.string(),
  refund_amount: z.string(),
  variant_id: z.string().nullable(),
  line_item_id: z.string().nullable(),
  fulfillment_item_id: z.string().nullable(),
  get variant() { return VariantSchema.optional(); },
  created_at: z.string(),
  updated_at: z.string(),
  get line_item() { return LineItemSchema.optional(); },
  tax_lines: z.array(TaxLineSchema).optional(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<ReturnLineItem['id']>;
  quantity: z.ZodType<ReturnLineItem['quantity']>;
  received_quantity: z.ZodType<ReturnLineItem['received_quantity']>;
  resellable: z.ZodType<ReturnLineItem['resellable']>;
  pre_tax_amount: z.ZodType<ReturnLineItem['pre_tax_amount']>;
  included_tax_total: z.ZodType<ReturnLineItem['included_tax_total']>;
  additional_tax_total: z.ZodType<ReturnLineItem['additional_tax_total']>;
  tax_total: z.ZodType<ReturnLineItem['tax_total']>;
  refund_amount: z.ZodType<ReturnLineItem['refund_amount']>;
  variant_id: z.ZodType<ReturnLineItem['variant_id']>;
  line_item_id: z.ZodType<ReturnLineItem['line_item_id']>;
  fulfillment_item_id: z.ZodType<ReturnLineItem['fulfillment_item_id']>;
  variant: z.ZodOptional<z.ZodType<Exclude<ReturnLineItem['variant'], undefined>>>;
  created_at: z.ZodType<ReturnLineItem['created_at']>;
  updated_at: z.ZodType<ReturnLineItem['updated_at']>;
  line_item: z.ZodOptional<z.ZodType<Exclude<ReturnLineItem['line_item'], undefined>>>;
  tax_lines: z.ZodOptional<z.ZodType<Exclude<ReturnLineItem['tax_lines'], undefined>>>;
}>;

export type { ReturnLineItem };
