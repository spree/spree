// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type LineItem from '../../types/generated/LineItem';
import { CustomFieldSchema } from './CustomField';
import { DigitalLinkSchema } from './DigitalLink';
import { GiftCardSchema } from './GiftCard';
import { GiftCardRecipientSchema } from './GiftCardRecipient';
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
  gift_card: z.boolean(),
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
  recipient: GiftCardRecipientSchema.nullable(),
  get gift_cards() { return z.array(GiftCardSchema).optional(); },
  custom_fields: z.array(CustomFieldSchema).optional(),
  external_references: z.record(z.string(), z.string()),
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
  product_id: z.string().nullable(),
  get variant() { return VariantSchema.optional(); },
  tax_category: TaxCategorySchema.optional(),
}) as unknown as z.ZodObject<{
  id: z.ZodType<LineItem['id']>;
  variant_id: z.ZodType<LineItem['variant_id']>;
  seller_id: z.ZodType<LineItem['seller_id']>;
  preorder: z.ZodType<LineItem['preorder']>;
  preorder_ships_at: z.ZodType<LineItem['preorder_ships_at']>;
  quantity: z.ZodType<LineItem['quantity']>;
  currency: z.ZodType<LineItem['currency']>;
  name: z.ZodType<LineItem['name']>;
  slug: z.ZodType<LineItem['slug']>;
  options_text: z.ZodType<LineItem['options_text']>;
  gift_card: z.ZodType<LineItem['gift_card']>;
  price: z.ZodType<LineItem['price']>;
  total: z.ZodType<LineItem['total']>;
  adjustment_total: z.ZodType<LineItem['adjustment_total']>;
  additional_tax_total: z.ZodType<LineItem['additional_tax_total']>;
  included_tax_total: z.ZodType<LineItem['included_tax_total']>;
  discount_total: z.ZodType<LineItem['discount_total']>;
  pre_tax_amount: z.ZodType<LineItem['pre_tax_amount']>;
  discounted_amount: z.ZodType<LineItem['discounted_amount']>;
  compare_at_amount: z.ZodType<LineItem['compare_at_amount']>;
  thumbnail_url: z.ZodType<LineItem['thumbnail_url']>;
  seller: z.ZodOptional<z.ZodType<Exclude<LineItem['seller'], undefined>>>;
  option_values: z.ZodType<LineItem['option_values']>;
  digital_links: z.ZodType<LineItem['digital_links']>;
  tax_lines: z.ZodOptional<z.ZodType<Exclude<LineItem['tax_lines'], undefined>>>;
  recipient: z.ZodType<LineItem['recipient']>;
  gift_cards: z.ZodOptional<z.ZodType<Exclude<LineItem['gift_cards'], undefined>>>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<LineItem['custom_fields'], undefined>>>;
  external_references: z.ZodType<LineItem['external_references']>;
  metadata: z.ZodType<LineItem['metadata']>;
  price_source: z.ZodType<LineItem['price_source']>;
  created_at: z.ZodType<LineItem['created_at']>;
  updated_at: z.ZodType<LineItem['updated_at']>;
  catalog_price: z.ZodType<LineItem['catalog_price']>;
  price_list_id: z.ZodType<LineItem['price_list_id']>;
  price_list_name: z.ZodType<LineItem['price_list_name']>;
  catalog_id: z.ZodType<LineItem['catalog_id']>;
  catalog_name: z.ZodType<LineItem['catalog_name']>;
  cost_price: z.ZodType<LineItem['cost_price']>;
  tax_category_id: z.ZodType<LineItem['tax_category_id']>;
  product_id: z.ZodType<LineItem['product_id']>;
  variant: z.ZodOptional<z.ZodType<Exclude<LineItem['variant'], undefined>>>;
  tax_category: z.ZodOptional<z.ZodType<Exclude<LineItem['tax_category'], undefined>>>;
}>;

export type { LineItem };
