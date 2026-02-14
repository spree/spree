// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { StoreOptionValueSchema } from './StoreOptionValue';
import { StoreDigitalLinkSchema } from './StoreDigitalLink';

export const StoreLineItemSchema = z.object({
  id: z.string(),
  variant_id: z.string(),
  quantity: z.number(),
  name: z.string(),
  slug: z.string(),
  options_text: z.string(),
  price: z.string(),
  display_price: z.string(),
  total: z.string(),
  display_total: z.string(),
  adjustment_total: z.string(),
  display_adjustment_total: z.string(),
  additional_tax_total: z.string(),
  display_additional_tax_total: z.string(),
  included_tax_total: z.string(),
  display_included_tax_total: z.string(),
  promo_total: z.string(),
  display_promo_total: z.string(),
  pre_tax_amount: z.string(),
  display_pre_tax_amount: z.string(),
  discounted_amount: z.string(),
  display_discounted_amount: z.string(),
  display_compare_at_amount: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  compare_at_amount: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  option_values: z.array(StoreOptionValueSchema),
  digital_links: z.array(StoreDigitalLinkSchema),
});

export type StoreLineItem = z.infer<typeof StoreLineItemSchema>;
