// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DigitalLinkSchema } from './DigitalLink';
import { OptionValueSchema } from './OptionValue';

export const LineItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
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
  thumbnail_url: z.string().nullable(),
  option_values: z.array(OptionValueSchema),
  digital_links: z.array(DigitalLinkSchema),
});

export type LineItem = z.infer<typeof LineItemSchema>;
