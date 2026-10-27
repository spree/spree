// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import type Variant from '../../types/generated/Variant';
import { CustomFieldSchema } from './CustomField';
import { MediaSchema } from './Media';
import { OptionValueSchema } from './OptionValue';
import { PriceSchema } from './Price';
import { PriceHistorySchema } from './PriceHistory';
import { SellerSchema } from './Seller';
import { StockLevelSchema } from './StockLevel';

export const VariantSchema = z.object({
  id: z.string(),
  product_id: z.string(),
  pricing_access: z.string().nullable(),
  sku: z.string().nullable(),
  options_text: z.string(),
  track_inventory: z.boolean(),
  media_count: z.number(),
  preorder_ships_at: z.string().nullable(),
  thumbnail_url: z.string().nullable(),
  purchasable: z.boolean(),
  in_stock: z.boolean(),
  backorderable: z.boolean(),
  preorder: z.boolean(),
  weight: z.number().nullable(),
  height: z.number().nullable(),
  width: z.number().nullable(),
  depth: z.number().nullable(),
  weight_unit: z.string(),
  dimensions_unit: z.string(),
  minimum_order_quantity: z.number().nullable(),
  order_multiple: z.number().nullable(),
  purchase_unit: z.string().nullable(),
  units_per_carton: z.number().nullable(),
  get price() { return PriceSchema; },
  get original_price() { return PriceSchema.nullable(); },
  seller_id: z.string().nullable(),
  seller: SellerSchema.optional(),
  primary_media: MediaSchema.optional(),
  media: z.array(MediaSchema).optional(),
  get option_values() { return z.array(OptionValueSchema); },
  custom_fields: z.array(CustomFieldSchema).optional(),
  prior_price: PriceHistorySchema.nullable().optional(),
  external_references: z.record(z.string(), z.string()),
  metadata: z.record(z.string(), z.unknown()),
  position: z.number(),
  cost_currency: z.string().nullable(),
  barcode: z.string().nullable(),
  backorder_limit: z.number().nullable(),
  hs_code: z.string().nullable(),
  country_of_origin: z.string().nullable(),
  customs_description: z.string().nullable(),
  carton_weight: z.string().nullable(),
  cartons_per_pallet: z.number().nullable(),
  deleted_at: z.string().nullable(),
  created_at: z.string(),
  updated_at: z.string(),
  cost_price: z.string().nullable(),
  preorderable: z.boolean(),
  tax_category_id: z.string().nullable(),
  carton_package_type_id: z.string().nullable(),
  units_per_pallet: z.number().nullable(),
  available_stock: z.number().nullable(),
  reserved_quantity: z.number(),
  total_on_hand: z.number().nullable(),
  product_name: z.string(),
  delivery_profile_id: z.string().nullable(),
  get prices() { return z.array(PriceSchema).optional(); },
  get stock_levels() { return z.array(StockLevelSchema).optional(); },
}) as unknown as z.ZodObject<{
  id: z.ZodType<Variant['id']>;
  product_id: z.ZodType<Variant['product_id']>;
  pricing_access: z.ZodType<Variant['pricing_access']>;
  sku: z.ZodType<Variant['sku']>;
  options_text: z.ZodType<Variant['options_text']>;
  track_inventory: z.ZodType<Variant['track_inventory']>;
  media_count: z.ZodType<Variant['media_count']>;
  preorder_ships_at: z.ZodType<Variant['preorder_ships_at']>;
  thumbnail_url: z.ZodType<Variant['thumbnail_url']>;
  purchasable: z.ZodType<Variant['purchasable']>;
  in_stock: z.ZodType<Variant['in_stock']>;
  backorderable: z.ZodType<Variant['backorderable']>;
  preorder: z.ZodType<Variant['preorder']>;
  weight: z.ZodType<Variant['weight']>;
  height: z.ZodType<Variant['height']>;
  width: z.ZodType<Variant['width']>;
  depth: z.ZodType<Variant['depth']>;
  weight_unit: z.ZodType<Variant['weight_unit']>;
  dimensions_unit: z.ZodType<Variant['dimensions_unit']>;
  minimum_order_quantity: z.ZodType<Variant['minimum_order_quantity']>;
  order_multiple: z.ZodType<Variant['order_multiple']>;
  purchase_unit: z.ZodType<Variant['purchase_unit']>;
  units_per_carton: z.ZodType<Variant['units_per_carton']>;
  price: z.ZodType<Variant['price']>;
  original_price: z.ZodType<Variant['original_price']>;
  seller_id: z.ZodType<Variant['seller_id']>;
  seller: z.ZodOptional<z.ZodType<Exclude<Variant['seller'], undefined>>>;
  primary_media: z.ZodOptional<z.ZodType<Exclude<Variant['primary_media'], undefined>>>;
  media: z.ZodOptional<z.ZodType<Exclude<Variant['media'], undefined>>>;
  option_values: z.ZodType<Variant['option_values']>;
  custom_fields: z.ZodOptional<z.ZodType<Exclude<Variant['custom_fields'], undefined>>>;
  prior_price: z.ZodOptional<z.ZodType<Exclude<Variant['prior_price'], undefined>>>;
  external_references: z.ZodType<Variant['external_references']>;
  metadata: z.ZodType<Variant['metadata']>;
  position: z.ZodType<Variant['position']>;
  cost_currency: z.ZodType<Variant['cost_currency']>;
  barcode: z.ZodType<Variant['barcode']>;
  backorder_limit: z.ZodType<Variant['backorder_limit']>;
  hs_code: z.ZodType<Variant['hs_code']>;
  country_of_origin: z.ZodType<Variant['country_of_origin']>;
  customs_description: z.ZodType<Variant['customs_description']>;
  carton_weight: z.ZodType<Variant['carton_weight']>;
  cartons_per_pallet: z.ZodType<Variant['cartons_per_pallet']>;
  deleted_at: z.ZodType<Variant['deleted_at']>;
  created_at: z.ZodType<Variant['created_at']>;
  updated_at: z.ZodType<Variant['updated_at']>;
  cost_price: z.ZodType<Variant['cost_price']>;
  preorderable: z.ZodType<Variant['preorderable']>;
  tax_category_id: z.ZodType<Variant['tax_category_id']>;
  carton_package_type_id: z.ZodType<Variant['carton_package_type_id']>;
  units_per_pallet: z.ZodType<Variant['units_per_pallet']>;
  available_stock: z.ZodType<Variant['available_stock']>;
  reserved_quantity: z.ZodType<Variant['reserved_quantity']>;
  total_on_hand: z.ZodType<Variant['total_on_hand']>;
  product_name: z.ZodType<Variant['product_name']>;
  delivery_profile_id: z.ZodType<Variant['delivery_profile_id']>;
  prices: z.ZodOptional<z.ZodType<Exclude<Variant['prices'], undefined>>>;
  stock_levels: z.ZodOptional<z.ZodType<Exclude<Variant['stock_levels'], undefined>>>;
}>;

export type { Variant };
