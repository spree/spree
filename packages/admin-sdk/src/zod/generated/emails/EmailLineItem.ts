// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { EmailOptionValueSchema } from './EmailOptionValue';

export const EmailLineItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
  seller_id: z.string().nullable(),
  preorder: z.boolean(),
  preorder_ships_at: z.string().nullable(),
  quantity: z.number(),
  currency: z.string(),
  name: z.string(),
  slug: z.string(),
  options_text: z.string(),
  price: z.string().nullable(),
  display_price: z.string().nullable(),
  total: z.string().nullable(),
  display_total: z.string().nullable(),
  adjustment_total: z.string().nullable(),
  display_adjustment_total: z.string().nullable(),
  additional_tax_total: z.string().nullable(),
  display_additional_tax_total: z.string().nullable(),
  included_tax_total: z.string().nullable(),
  display_included_tax_total: z.string().nullable(),
  discount_total: z.string().nullable(),
  display_discount_total: z.string().nullable(),
  pre_tax_amount: z.string().nullable(),
  display_pre_tax_amount: z.string().nullable(),
  discounted_amount: z.string().nullable(),
  display_discounted_amount: z.string().nullable(),
  display_compare_at_amount: z.string().nullable(),
  compare_at_amount: z.string().nullable(),
  option_values: z.array(EmailOptionValueSchema),
  url: z.string().nullable(),
  image_url: z.string().nullable(),
  sku: z.string().nullable(),
  display_amount: z.string(),
});

export type EmailLineItem = z.infer<typeof EmailLineItemSchema>;
