// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DigitalLinkSchema } from './DigitalLink';
import { OptionValueSchema } from './OptionValue';
import { SellerSchema } from './Seller';
import { TaxCategorySchema } from './TaxCategory';
import { TaxLineSchema } from './TaxLine';
import { VariantSchema } from './Variant';

export const LineItemSchema = z.object({
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
  price: z.string(),
  total: z.string(),
  adjustment_total: z.string(),
  additional_tax_total: z.string(),
  included_tax_total: z.string(),
  discount_total: z.string(),
  pre_tax_amount: z.string(),
  discounted_amount: z.string(),
  compare_at_amount: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  seller: SellerSchema.optional(),
  get option_values() { return z.array(OptionValueSchema); },
  digital_links: z.array(DigitalLinkSchema),
  tax_lines: z.array(TaxLineSchema).optional(),
  metadata: z.record(z.string(), z.unknown()),
  price_source: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  catalog_price: z.string().nullable(),
  price_list_id: z.string().nullable(),
  price_list_name: z.string().nullable(),
  catalog_id: z.string().nullable(),
  catalog_name: z.string().nullable(),
  cost_price: z.string().nullable(),
  tax_category_id: z.string().nullable(),
  get variant() { return VariantSchema.optional(); },
  tax_category: TaxCategorySchema.optional(),
});

export type LineItem = z.infer<typeof LineItemSchema>;
